#!/usr/bin/env bash
# Equipo IA 4.3 — ejecutor de pruebas con resultado estructurado.
# Copyright 2026 The Equipo IA Authors. SPDX-License-Identifier: Apache-2.0
set -Eeuo pipefail

WORK="${1:-}"
REPORT="${2:-}"
[[ -n "$WORK" && -d "$WORK" ]] || { printf 'Uso: equipo-pruebas.sh DIRECTORIO INFORME\n' >&2; exit 2; }
[[ -n "$REPORT" ]] || { printf 'Uso: equipo-pruebas.sh DIRECTORIO INFORME\n' >&2; exit 2; }
mkdir -p "$REPORT"
RESULT="$REPORT/pruebas-resultado.txt"
LOG="$REPORT/pruebas.log"
: > "$LOG"
printf 'ESTADO=REVISION_MANUAL\nMOTIVO=No se pudo determinar el comando de pruebas.\n' > "$RESULT"

TIMEOUT_BIN="${EQUIPO_TIMEOUT_BIN:-$(command -v timeout || command -v gtimeout || true)}"
[[ -n "$TIMEOUT_BIN" ]] || { printf 'Falta timeout (o gtimeout).\n' >&2; exit 2; }
LIMITE="${EQUIPO_TEST_TIMEOUT:-180}"
[[ "$LIMITE" =~ ^[0-9]+$ ]] || LIMITE=180

CMD="${EQUIPO_TEST_CMD:-}"

if [[ -z "$CMD" && -f "$WORK/package.json" ]] && command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  if node -e 'const p=require(process.argv[1]); process.exit(p.scripts && p.scripts.test && p.scripts.test!=="echo \"Error: no test specified\" && exit 1" ? 0 : 1)' "$WORK/package.json" >/dev/null 2>&1; then
    CMD="npm test"
  fi
fi

if [[ -z "$CMD" ]] && { [[ -f "$WORK/pyproject.toml" ]] || [[ -f "$WORK/pytest.ini" ]] || [[ -d "$WORK/tests" ]]; }; then
  if command -v python3 >/dev/null 2>&1 && python3 -m pytest --version >/dev/null 2>&1; then
    CMD="python3 -m pytest -q"
  fi
fi

if [[ -z "$CMD" && -f "$WORK/DESCRIPTION" ]] && command -v Rscript >/dev/null 2>&1; then
  if Rscript -e 'quit(status=!requireNamespace("testthat", quietly=TRUE))' >/dev/null 2>&1; then
    CMD='Rscript -e "testthat::test_dir(\"tests/testthat\")"'
  fi
fi

if [[ -z "$CMD" ]]; then
  printf 'No se detectó un comando de pruebas. Define EQUIPO_TEST_CMD.\n' | tee -a "$LOG" >&2
  printf 'ESTADO=REVISION_MANUAL\nCOMANDO=(no disponible)\nCODIGO=2\nMOTIVO=No hay comando de pruebas configurado.\n' > "$RESULT"
  exit 2
fi

printf 'Comando de pruebas: %s\n' "$CMD" | tee -a "$LOG"

if [[ "$CMD" == npm* && -f "$WORK/package-lock.json" ]]; then
  case "${EQUIPO_NPM_CI:-no}" in
    si)
      printf '\n[equipo-ia] npm ci\n' | tee -a "$LOG"
      set +e
      ( cd "$WORK" && "$TIMEOUT_BIN" --signal=TERM --kill-after=5s "$LIMITE" npm ci ) >> "$LOG" 2>&1
      CODE=$?
      set -e
      if ((CODE != 0)); then
        printf 'ESTADO=REVISION_MANUAL\nCOMANDO=npm ci\nCODIGO=%s\nMOTIVO=npm ci falló; no se ejecutaron las pruebas.\n' "$CODE" > "$RESULT"
        exit 2
      fi ;;
    no) printf 'npm ci: no autorizado; se usa node_modules existente si lo hay.\n' | tee -a "$LOG" ;;
    *)  printf 'ESTADO=REVISION_MANUAL\nCOMANDO=npm ci\nCODIGO=2\nMOTIVO=EQUIPO_NPM_CI inválido.\n' > "$RESULT"; exit 2 ;;
  esac
fi

INICIO="$(date +%s)"
set +e
( cd "$WORK" && "$TIMEOUT_BIN" --signal=TERM --kill-after=5s "$LIMITE" bash -c "$CMD" ) >> "$LOG" 2>&1
CODE=$?
set -e
FIN="$(date +%s)"
DURACION=$((FIN - INICIO))

if ((CODE == 0)); then
  ESTADO="APROBADO"; MOTIVO="Las pruebas pasaron."
  printf 'ESTADO=%s\nCOMANDO=%s\nCODIGO=%s\nDURACION=%ss\nMOTIVO=%s\n' "$ESTADO" "$CMD" "$CODE" "$DURACION" "$MOTIVO" > "$RESULT"
  exit 0
elif ((CODE == 124 || CODE == 137)); then
  ESTADO="REVISION_MANUAL"; MOTIVO="Las pruebas superaron el tiempo límite."
  printf 'ESTADO=%s\nCOMANDO=%s\nCODIGO=%s\nDURACION=%ss\nMOTIVO=%s\n' "$ESTADO" "$CMD" "$CODE" "$DURACION" "$MOTIVO" > "$RESULT"
  exit 2
else
  ESTADO="FALLIDO"; MOTIVO="Las pruebas fallaron con código $CODE."
  printf 'ESTADO=%s\nCOMANDO=%s\nCODIGO=%s\nDURACION=%ss\nMOTIVO=%s\n' "$ESTADO" "$CMD" "$CODE" "$DURACION" "$MOTIVO" > "$RESULT"
  exit 1
fi
