# Instala el kit OpenCode en el directorio actual (la raíz del proyecto).
#
# Local:
#   cd C:\ruta\al\proyecto
#   ~\opencode-kit\install.ps1
#   ~\opencode-kit\install.ps1 -Force
#
# Remoto (el repo tiene que ser público):
#   irm https://raw.githubusercontent.com/alexberrios/opencode-kit/main/install.ps1 | iex
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/alexberrios/opencode-kit/main/install.ps1))) -Force
#   $env:OPENCODE_KIT_FORCE = '1'; irm https://raw.githubusercontent.com/alexberrios/opencode-kit/main/install.ps1 | iex
#
# OPENCODE_KIT_RAW_BASE reemplaza la URL base (forks y pruebas).
# No hay param() de script a propósito: así `irm | iex` funciona en Windows PowerShell 5.1 y en PowerShell 7.
# El cuerpo va dentro de un scriptblock para no dejar funciones ni preferencias en la sesión de quien hace iex.

# $args se guarda afuera: un scriptblock no hereda $args, y envolver un array vacío
# en otro array hace que PowerShell lo desenrolle y parezca un argumento en blanco.
$OpenCodeKitArgs = @($args)
try {
& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

    function Write-Err([string]$Message) {
        [Console]::Error.WriteLine($Message)
    }

    function Stop-Install {
        param([int]$Code, [string]$Message)
        if ($Message) { Write-Err "error: $Message" }
        if ($PSCommandPath) { exit $Code }
        throw "opencode-kit: $Message"
    }

    $files = @(
        'opencode.json',
        'AGENTS.md',
        '.opencode/agents/code-searcher.md',
        '.opencode/agents/implementer.md',
        '.opencode/agents/reviewer.md',
        '.opencode/agents/test-runner.md'
    )

    $Force = $false
    $showHelp = $false
    foreach ($a in @($OpenCodeKitArgs)) {
        if ($a -eq '-Force' -or $a -eq '--Force' -or $a -eq '--force' -or $a -eq '-f') {
            $Force = $true
            continue
        }
        if ($a -eq '-h' -or $a -eq '--help' -or $a -eq '-?' -or $a -eq '-Help') {
            $showHelp = $true
            continue
        }
        Stop-Install 2 "No entendí el argumento '$a'. El script instala en la carpeta actual. Uso: install.ps1 [-Force]"
    }
    if ($env:OPENCODE_KIT_FORCE -match '^(1|true|yes)$') { $Force = $true }

    if ($showHelp) {
        Write-Host @'
Uso: install.ps1 [-Force]

Copia opencode.json, AGENTS.md y .opencode/agents/ a la carpeta actual.

  -Force        Si un archivo ya existe y es distinto, guarda una copia .bak
                y lo reemplaza. Sin esta opción, se deja como está y se avisa.
  -Help         Muestra esta ayuda.

Local:  ~\opencode-kit\install.ps1
Remoto: irm https://raw.githubusercontent.com/alexberrios/opencode-kit/main/install.ps1 | iex

-Force no viaja en "irm | iex". Para forzar en remoto:
  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/alexberrios/opencode-kit/main/install.ps1))) -Force

El one-liner remoto solo funciona si el repositorio es público.
'@
        if ($PSCommandPath) { exit 0 }
        return
    }

    $stats = @{ installed = 0; updated = 0; unchanged = 0; skipped = 0 }

    function Join-Rel([string]$Root, [string]$Relative) {
        $path = $Root
        foreach ($part in ($Relative -split '/')) {
            $path = Join-Path $path $part
        }
        return $path
    }

    function Get-BackupPath([string]$Path) {
        $bak = "$Path.bak"
        if (-not (Test-Path -LiteralPath $bak)) { return $bak }
        $i = 1
        do {
            $candidate = "$Path.bak.$i"
            $i = $i + 1
        } while (Test-Path -LiteralPath $candidate)
        return $candidate
    }

    function Test-SameBytes([string]$A, [string]$B) {
        $ha = (Get-FileHash -Algorithm SHA256 -LiteralPath $A).Hash
        $hb = (Get-FileHash -Algorithm SHA256 -LiteralPath $B).Hash
        return ($ha -eq $hb)
    }

    function Install-One {
        param(
            [string]$Relative,
            [string]$SourceRoot,
            [string]$TargetRoot,
            [bool]$DoForce
        )
        $src = Join-Rel $SourceRoot $Relative
        $dst = Join-Rel $TargetRoot $Relative
        if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
            Stop-Install 1 "Falta $Relative en el kit ($src)."
        }
        $parent = Split-Path -Parent $dst
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent | Out-Null
        }
        if (Test-Path -LiteralPath $dst) {
            $item = Get-Item -LiteralPath $dst -Force
            $isLink = [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
            if (-not $isLink -and $item.PSObject.Properties['LinkType'] -and $item.LinkType) {
                $isLink = $true
            }
            if ($item.PSIsContainer -and -not $isLink) {
                Write-Err "aviso: $Relative es una carpeta; no la toqué."
                $stats.skipped = $stats.skipped + 1
                return
            }
            if (-not $isLink -and (Test-SameBytes $src $dst)) {
                Write-Host "sin cambios: $Relative"
                $stats.unchanged = $stats.unchanged + 1
                return
            }
            if (-not $DoForce) {
                Write-Err "aviso: ya existe y es distinto: $Relative — no lo reemplacé. Usa -Force para reemplazarlo (queda un .bak)."
                $stats.skipped = $stats.skipped + 1
                return
            }
            $bak = Get-BackupPath $dst
            $stage = "$dst.opencode-kit-new"
            if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Force }
            Copy-Item -LiteralPath $src -Destination $stage
            try {
                if ($isLink) {
                    Move-Item -LiteralPath $dst -Destination $bak
                } else {
                    Copy-Item -LiteralPath $dst -Destination $bak
                }
                if (Test-Path -LiteralPath $dst) {
                    Remove-Item -LiteralPath $dst -Force
                }
                Move-Item -LiteralPath $stage -Destination $dst
            } catch {
                if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Force }
                throw
            }
            Write-Host "actualicé $Relative (copia anterior: $bak)"
            $stats.updated = $stats.updated + 1
            return
        }
        Copy-Item -LiteralPath $src -Destination $dst
        Write-Host "instalado: $Relative"
        $stats.installed = $stats.installed + 1
    }

    function Install-Tree {
        param([string]$SourceRoot, [string]$TargetRoot, [bool]$DoForce)
        foreach ($rel in $files) {
            Install-One -Relative $rel -SourceRoot $SourceRoot -TargetRoot $TargetRoot -DoForce $DoForce
        }
    }

    function Test-Payload([string]$Relative, [string]$Path) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            Stop-Install 1 "La descarga de $Relative no llegó."
        }
        $len = (Get-Item -LiteralPath $Path).Length
        if ($len -lt 1) {
            Stop-Install 1 "La descarga de $Relative llegó vacía."
        }
        $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $b = $fs.ReadByte()
        } finally {
            $fs.Dispose()
        }
        if ($b -eq 0x3C) {
            Stop-Install 1 "La descarga de $Relative no parece el kit (¿el repo es privado?)."
        }
        if ($Relative -eq 'opencode.json' -and $b -ne 0x7B) {
            Stop-Install 1 "La descarga de opencode.json no parece el kit."
        }
    }

    $targetFull = (Resolve-Path -LiteralPath '.').ProviderPath
    $kitRoot = $null
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
    if ($scriptPath -and (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        $cand = Split-Path -Parent $scriptPath
        $hasJson = Test-Path -LiteralPath (Join-Path $cand 'opencode.json') -PathType Leaf
        $hasAgents = Test-Path -LiteralPath (Join-Path $cand 'AGENTS.md') -PathType Leaf
        $hasSearcher = Test-Path -LiteralPath (Join-Rel $cand '.opencode/agents/code-searcher.md') -PathType Leaf
        if ($hasJson -and $hasAgents -and $hasSearcher) {
            $kitRoot = (Resolve-Path -LiteralPath $cand).ProviderPath
        }
    }

    if ($kitRoot) {
        $cmp = [StringComparison]::Ordinal
        if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
            $cmp = [StringComparison]::OrdinalIgnoreCase
        }
        $left = $kitRoot.TrimEnd('\', '/')
        $right = $targetFull.TrimEnd('\', '/')
        if ([string]::Equals($left, $right, $cmp)) {
            Stop-Install 1 "Estás en la carpeta del kit, no en un proyecto. Cámbiate al proyecto y vuelve a correr el script."
        }
        Install-Tree -SourceRoot $kitRoot -TargetRoot $targetFull -DoForce $Force
    } else {
        $rawBase = $env:OPENCODE_KIT_RAW_BASE
        if ([string]::IsNullOrWhiteSpace($rawBase)) {
            $rawBase = 'https://raw.githubusercontent.com/alexberrios/opencode-kit/main'
        }
        $rawBase = $rawBase.TrimEnd('/')
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("opencode-kit-" + [guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            foreach ($rel in $files) {
                $url = "$rawBase/$rel"
                $dest = Join-Rel $tmp $rel
                $parent = Split-Path -Parent $dest
                if (-not (Test-Path -LiteralPath $parent)) {
                    New-Item -ItemType Directory -Path $parent | Out-Null
                }
                try {
                    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing | Out-Null
                } catch {
                    Write-Err "error: no pude descargar $url"
                    Stop-Install 1 "Si el repo es privado, raw.githubusercontent.com no sirve. Clónalo y corre el script local: gh repo clone alexberrios/opencode-kit"
                }
                Test-Payload $rel $dest
            }
            Install-Tree -SourceRoot $tmp -TargetRoot $targetFull -DoForce $Force
        } finally {
            if ($tmp -like '*opencode-kit-*' -and (Test-Path -LiteralPath $tmp)) {
                Remove-Item -LiteralPath $tmp -Recurse -Force
            }
        }
    }

    Write-Host ""
    Write-Host "Listo."
    Write-Host ("  instalados:   {0}" -f $stats.installed)
    Write-Host ("  actualizados: {0}" -f $stats.updated)
    Write-Host ("  sin cambios:  {0}" -f $stats.unchanged)
    Write-Host ("  omitidos:     {0}" -f $stats.skipped)
    if ($stats.skipped -gt 0) {
        Write-Err "aviso: Quedaron archivos sin tocar. Vuelve a correr con -Force para reemplazarlos (se guarda .bak)."
    }
}
} finally {
    Remove-Variable OpenCodeKitArgs -ErrorAction SilentlyContinue
}
