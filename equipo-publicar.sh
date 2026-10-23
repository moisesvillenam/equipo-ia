#!/usr/bin/env bash
# Publica un commit existente tras comprobar las pruebas y confirmar el destino.
# Copyright 2026 The Equipo IA Authors. SPDX-License-Identifier: Apache-2.0
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fallar() { printf '%s\n' "$*" >&2; exit 1; }

case "${1:-}" in
  --help|-h)
    printf 'Uso: equipo-publicar.sh [--comprobar]\n'
    printf 'Publica la rama actual en su upstream, o en origin con el mismo nombre.\n'
    printf 'Exige un commit, árbol limpio, pruebas aprobadas y escribir PUBLICAR.\n'
    printf 'Con --comprobar muestra el destino y ejecuta pruebas sin subir cambios.\n'
    exit 0 ;;
  ''|--comprobar) ;;
  *) fallar 'Opción desconocida. Usa --help.' ;;
esac
COMPROBAR="${1:-}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || fallar 'Entra primero en el repositorio del proyecto.'
cd "$ROOT"
HEAD_ID="$(git rev-parse --verify HEAD 2>/dev/null)" || fallar 'Guarda primero una versión con git commit.'
BRANCH="$(git symbolic-ref --quiet --short HEAD)" || fallar 'Selecciona una rama antes de publicar; HEAD está separado.'

limpio() {
  local estado
  estado="$(git status --porcelain --untracked-files=all)" || fallar 'No se pudo comprobar el estado Git.'
  [[ -z "$estado" ]] || fallar 'Hay cambios pendientes. Revísalos y guárdalos con git add y git commit antes de publicar.'
}

destino() {
  local upstream_remote upstream_ref
  upstream_remote="$(git for-each-ref --format='%(upstream:remotename)' "refs/heads/$BRANCH")"
  upstream_ref="$(git for-each-ref --format='%(upstream:remoteref)' "refs/heads/$BRANCH")"
  REMOTE="${upstream_remote:-origin}"
  REF="${upstream_ref:-refs/heads/$BRANCH}"
  [[ "$REMOTE" != . ]] || fallar 'La rama sigue una rama local. Configura un remoto para publicar.'
  [[ "$REF" == refs/heads/* ]] || fallar 'El destino debe ser una rama remota.'
  git check-ref-format "$REF" >/dev/null || fallar 'La rama de destino no es válida.'
  URL="$(git remote get-url --push --all "$REMOTE" 2>/dev/null)" || fallar 'No hay remoto de publicación. Configura origin con git remote add origin URL.'
  [[ -n "$URL" && "$URL" != *$'\n'* && "$URL" != *$'\r'* ]] || fallar 'Configura un único destino de push para este remoto.'
  # No mostrar ni guardar credenciales incluidas dentro de una URL HTTPS.
  if [[ "$URL" == http://* || "$URL" == https://* ]]; then
    local autoridad="${URL#*://}"
    autoridad="${autoridad%%/*}"
    [[ "$autoridad" != *@* && "$URL" != *'?'* && "$URL" != *'#'* ]] || fallar 'Usa una URL sin credenciales y autentica Git con su gestor de credenciales.'
  fi
}

limpio
destino
EXPECTED_DEST="$REMOTE|$REF|$URL"
printf '\nProyecto: %s\nCommit: %s\nRama: %s\nDestino: %s (%s → %s)\n' "$ROOT" "$HEAD_ID" "$BRANCH" "$URL" "$REMOTE" "$REF"
printf 'Se enviará el historial necesario para este commit.\n'

STATE="${EQUIPO_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/equipo-ia}"
mkdir -p "$STATE"
STATE="$(cd "$STATE" && pwd)"
REPORT="$(mktemp -d "$STATE/publicacion_$(date +%Y%m%d_%H%M%S)_XXXXXX")"
printf '%s\n' "$ROOT" > "$REPORT/origen.txt"
printf '%s\n' "$HEAD_ID" > "$REPORT/commit.txt"
printf '%s\n' "$URL" > "$REPORT/destino.txt"
printf '%s\n' "$REF" > "$REPORT/rama.txt"
printf 'PREPARANDO\n' > "$REPORT/estado.txt"
trap 'code=$?; if ((code != 0)); then printf "ERROR\n" > "$REPORT/estado.txt"; fi' EXIT
printf 'Comprobando pruebas. Informe: %s\n' "$REPORT"
# La consola carga "preguntar" por defecto. Publicar usa las dependencias
# existentes; instalar requiere la autorización explícita EQUIPO_NPM_CI=si.
export EQUIPO_NPM_CI="${EQUIPO_NPM_CI:-no}"
[[ "$EQUIPO_NPM_CI" != preguntar ]] || EQUIPO_NPM_CI=no
if ! bash "$SCRIPT_DIR/equipo-pruebas.sh" "$ROOT" "$REPORT"; then
  fallar "No se publica: las pruebas no aprobaron. Consulta $REPORT/pruebas.log"
fi
[[ "$(sed -n 's/^ESTADO=//p' "$REPORT/pruebas-resultado.txt")" == APROBADO ]] || fallar 'No hay evidencia de pruebas aprobadas.'

sin_cambios() {
  limpio
  [[ "$(git rev-parse HEAD)" == "$HEAD_ID" && "$(git symbolic-ref --quiet --short HEAD)" == "$BRANCH" ]] || fallar 'El commit o la rama cambió durante la comprobación. Repite /publicar.'
  destino
  [[ "$REMOTE|$REF|$URL" == "$EXPECTED_DEST" ]] || fallar 'El destino cambió durante la comprobación. Repite /publicar.'
}
sin_cambios
if [[ "$COMPROBAR" == --comprobar ]]; then
  printf 'COMPROBADO\n' > "$REPORT/estado.txt"
  printf 'Pruebas aprobadas y destino comprobado localmente. No se enviaron cambios.\n'
  exit 0
fi
printf '\nEscribe PUBLICAR para enviar este commit a %s (%s): ' "$URL" "$REF"
read -r CONFIRMACION || CONFIRMACION=''
if [[ "$CONFIRMACION" != PUBLICAR ]]; then
  printf 'CANCELADO\n' > "$REPORT/estado.txt"
  printf 'Publicación cancelada.\n'
  exit 0
fi
sin_cambios
# URL y refspec explícitos evitan push.default, mirror y refspecs configurados.
# El hash fija exactamente el commit revisado aunque HEAD cambie después.
if ! git -c push.followTags=false push --porcelain --no-force --no-follow-tags \
    --recurse-submodules=no -- "$URL" "$HEAD_ID:$REF" 2>&1 | tee "$REPORT/push.log"; then
  fallar "Git no pudo publicar. Revisa autenticación, conexión o cambios remotos en $REPORT/push.log"
fi
printf 'PUBLICADO\n' > "$REPORT/estado.txt"
printf '\nCommit publicado en %s (%s).\nInforme: %s\n' "$URL" "$REF" "$REPORT"
printf 'Esto sube el código al repositorio. El despliegue web depende del hosting configurado.\n'
