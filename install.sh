#!/usr/bin/env bash
# Instala el kit OpenCode en el directorio actual (la raíz del proyecto).
#
# Local:
#   cd /ruta/al/proyecto
#   ~/opencode-kit/install.sh
#   ~/opencode-kit/install.sh --force
#
# Remoto (el repo tiene que ser público):
#   curl -fsSL https://raw.githubusercontent.com/alexberrios/opencode-kit/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/alexberrios/opencode-kit/main/install.sh | bash -s -- --force
#
# OPENCODE_KIT_RAW_BASE reemplaza la URL base (forks y pruebas).

if [ -z "${BASH_VERSION:-}" ]; then
  printf '%s\n' "Este script necesita bash." >&2
  exit 1
fi

set -euo pipefail
unset CDPATH

RAW_BASE="${OPENCODE_KIT_RAW_BASE:-https://raw.githubusercontent.com/alexberrios/opencode-kit/main}"
RAW_BASE="${RAW_BASE%/}"

FILES=(
  "opencode.json"
  "AGENTS.md"
  ".opencode/agents/code-searcher.md"
  ".opencode/agents/implementer.md"
  ".opencode/agents/reviewer.md"
  ".opencode/agents/test-runner.md"
)

FORCE=0
installed=0
updated=0
unchanged=0
skipped=0
tmpdir=""

usage() {
  cat <<'EOF'
Uso: install.sh [--force]

Copia opencode.json, AGENTS.md y .opencode/agents/ a la carpeta actual.

  --force, -f   Si un archivo ya existe y es distinto, guarda una copia .bak
                y lo reemplaza. Sin esta opción, se deja como está y se avisa.
  -h, --help    Muestra esta ayuda.

Local:  ~/opencode-kit/install.sh
Remoto: curl -fsSL https://raw.githubusercontent.com/alexberrios/opencode-kit/main/install.sh | bash

El one-liner remoto solo funciona si el repositorio es público.
EOF
}

fail() {
  local code="$1"
  shift
  printf 'error: %s\n' "$*" >&2
  exit "$code"
}

warn() {
  printf 'aviso: %s\n' "$*" >&2
}

cleanup() {
  case "$tmpdir" in
    *opencode-kit.*) rm -rf "$tmpdir" ;;
  esac
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force|-f) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail 2 "Opción desconocida: $1" ;;
  esac
done

backup_path() {
  local f="$1"
  local bak="${f}.bak"
  local i=1
  if [[ ! -e "$bak" && ! -L "$bak" ]]; then
    printf '%s\n' "$bak"
    return 0
  fi
  while [[ -e "${f}.bak.${i}" || -L "${f}.bak.${i}" ]]; do
    i=$((i + 1))
  done
  printf '%s\n' "${f}.bak.${i}"
}

same_file() {
  if command -v cmp >/dev/null 2>&1; then
    cmp -s "$1" "$2"
    return $?
  fi
  diff -q "$1" "$2" >/dev/null 2>&1
}

install_one() {
  local rel="$1"
  local src="$2"
  local dst="$PWD/$rel"
  local parent bak stage

  if [[ ! -f "$src" ]]; then
    fail 1 "Falta $rel en el kit ($src)."
  fi

  parent="$(dirname "$dst")"
  mkdir -p "$parent"

  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ -d "$dst" && ! -L "$dst" ]]; then
      warn "$rel es una carpeta; no la toqué."
      skipped=$((skipped + 1))
      return 0
    fi
    if [[ ! -L "$dst" ]] && same_file "$src" "$dst"; then
      printf '%s\n' "sin cambios: $rel"
      unchanged=$((unchanged + 1))
      return 0
    fi
    if [[ "$FORCE" -ne 1 ]]; then
      warn "ya existe y es distinto: $rel — no lo reemplacé. Usa --force para reemplazarlo (queda un .bak)."
      skipped=$((skipped + 1))
      return 0
    fi
    # Primero el respaldo y una copia aparte. Si algo falla, el archivo original sigue en su sitio.
    bak="$(backup_path "$dst")"
    stage="${dst}.opencode-kit-new"
    rm -f "$stage"
    cp "$src" "$stage" || { rm -f "$stage"; fail 1 "No pude preparar $rel."; }
    if [[ -L "$dst" ]]; then
      mv "$dst" "$bak" || { rm -f "$stage"; fail 1 "No pude respaldar $rel."; }
      mv "$stage" "$dst" || fail 1 "No pude reemplazar $rel. La versión anterior quedó en $bak."
    else
      cp -p "$dst" "$bak" || { rm -f "$stage"; fail 1 "No pude respaldar $rel."; }
      mv "$stage" "$dst" || { rm -f "$stage"; fail 1 "No pude reemplazar $rel."; }
    fi
    printf '%s\n' "actualicé $rel (copia anterior: $bak)"
    updated=$((updated + 1))
    return 0
  fi

  cp "$src" "$dst"
  printf '%s\n' "instalado: $rel"
  installed=$((installed + 1))
}

install_tree() {
  local root="$1"
  local rel
  for rel in "${FILES[@]}"; do
    install_one "$rel" "$root/$rel"
  done
}

looks_like_payload() {
  local rel="$1"
  local path="$2"
  local first
  if [[ ! -s "$path" ]]; then
    fail 1 "La descarga de $rel llegó vacía."
  fi
  first="$(head -c 1 "$path" || true)"
  case "$first" in
    "<") fail 1 "La descarga de $rel no parece el kit (¿el repo es privado?)." ;;
  esac
  if [[ "$rel" == "opencode.json" && "$first" != "{" ]]; then
    fail 1 "La descarga de opencode.json no parece el kit."
  fi
}

fetch_to() {
  local url="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")" || return 1
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 --retry-delay 1 "$url" -o "$dest"
    return $?
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q -O "$dest" "$url"
    return $?
  fi
  printf '%s\n' "error: necesitas curl o wget para instalar desde GitHub." >&2
  return 1
}

download_kit() {
  local rel url dest
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/opencode-kit.XXXXXX")"
  for rel in "${FILES[@]}"; do
    url="$RAW_BASE/$rel"
    dest="$tmpdir/$rel"
    if ! fetch_to "$url" "$dest"; then
      printf '%s\n' "error: no pude descargar $url" >&2
      printf '%s\n' "Si el repo es privado, raw.githubusercontent.com no sirve. Clónalo y corre el script local: gh repo clone alexberrios/opencode-kit" >&2
      exit 1
    fi
    looks_like_payload "$rel" "$dest"
  done
}

find_local_kit() {
  local src cand
  src="${BASH_SOURCE[0]:-}"
  if [[ -z "$src" || ! -f "$src" ]]; then
    return 1
  fi
  cand="$(cd "$(dirname "$src")" && pwd)"
  if [[ -f "$cand/opencode.json" && -f "$cand/AGENTS.md" && -f "$cand/.opencode/agents/code-searcher.md" ]]; then
    printf '%s\n' "$cand"
    return 0
  fi
  return 1
}

main() {
  local kit target
  target="$(pwd -P)"

  if kit="$(find_local_kit)"; then
    kit="$(cd "$kit" && pwd -P)"
    if [[ "$kit" == "$target" ]]; then
      fail 1 "Estás en la carpeta del kit, no en un proyecto. Cámbiate al proyecto y vuelve a correr el script."
    fi
    install_tree "$kit"
  else
    download_kit
    install_tree "$tmpdir"
  fi

  printf '\n%s\n' "Listo."
  printf '  instalados: %s\n' "$installed"
  printf '  actualizados: %s\n' "$updated"
  printf '  sin cambios: %s\n' "$unchanged"
  printf '  omitidos: %s\n' "$skipped"
  if [[ "$skipped" -gt 0 ]]; then
    warn "Quedaron archivos sin tocar. Vuelve a correr con --force para reemplazarlos (se guarda .bak)."
  fi
}

main
