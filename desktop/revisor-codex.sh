#!/usr/bin/env bash
# Adaptador del contrato de revisión existente. Una sesión distinta del programador.
set -Eeuo pipefail
: "${EQUIPO_PROMPT_FILE:?Falta el archivo del prompt}"
: "${EQUIPO_CWD:?Falta el directorio de revisión}"
: "${EQUIPO_NONCE:?Falta el identificador de revisión}"
exec codex exec --sandbox read-only -C "$EQUIPO_CWD" - < "$EQUIPO_PROMPT_FILE"
