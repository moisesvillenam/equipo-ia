#!/usr/bin/env bash
# Demo sin claves ni red: agentes simulados sobre un repo de juguete.
# Copyright 2026 The Equipo IA Authors. SPDX-License-Identifier: Apache-2.0
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/equipo-ia-demo.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

PROYECTO="$TMP/proyecto"
ESTADO="$TMP/estado"
mkdir -p "$PROYECTO"
cp -R "$ROOT_DIR/examples/toy-repo/." "$PROYECTO/"
git -C "$PROYECTO" init -q
git -C "$PROYECTO" add -A
git -C "$PROYECTO" -c user.name='Demo' -c user.email='demo@example.com' commit -qm 'estado inicial'

export PATH="$ROOT_DIR/examples/fake-agents:$PATH"
export EQUIPO_FAKE_FIX="$ROOT_DIR/examples/fixtures/index.fixed.js"
export EQUIPO_STATE_DIR="$ESTADO"
export EQUIPO_CONFIG="$TMP/sin-config"
export EQUIPO_NPM_CI=no

printf 'Demo de Equipo IA 4.3\n'
printf 'Proyecto: %s\n\n' "$PROYECTO"

set +e
( cd "$PROYECTO" && bash "$ROOT_DIR/equipo-ia.sh" --si --modo maximo --intentos 0 \
    "Corrige el saludo para que la prueba pase" )
CODE=$?
set -e

RUN_DIR="$(ls -1dt "$ESTADO"/ejecucion_* 2>/dev/null | head -1 || true)"
if [[ -z "$RUN_DIR" ]]; then
  printf '\nLa demo no creó una ejecución.\n' >&2
  exit 1
fi

printf '\n===== ACTA =====\n'
cat "$RUN_DIR/acta.md"
printf '\n===== PARCHE =====\n'
cat "$RUN_DIR/cambios.patch"
printf '\n'
if ((CODE == 0)); then
  printf 'Demo completada: VALIDADO.\n'
else
  printf 'Demo terminó con código %s; revisa %s.\n' "$CODE" "$RUN_DIR" >&2
fi
exit "$CODE"
