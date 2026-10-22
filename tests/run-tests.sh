#!/usr/bin/env bash
# Pruebas de extremo a extremo con agentes simulados (sin red ni claves).
# Copyright 2026 The Equipo IA Authors. SPDX-License-Identifier: Apache-2.0
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/equipo-ia-tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
LAST_OUT="$TMP/salida.log"

ok() { PASS=$((PASS + 1)); printf 'ok %s - %s\n' "$PASS" "$1"; }
not_ok() { FAIL=$((FAIL + 1)); printf 'not ok - %s\n' "$1"; }
assert_eq() {
  local esperado="$1" actual="$2" nombre="$3"
  if [[ "$esperado" == "$actual" ]]; then ok "$nombre"; else not_ok "$nombre (esperado: '$esperado', actual: '$actual')"; fi
}
assert_file() {
  if [[ -s "$1" ]]; then ok "$2"; else not_ok "$2 (falta o está vacío: $1)"; fi
}
assert_contains() {
  local archivo="$1" texto="$2" nombre="$3"
  if grep -Fq -- "$texto" "$archivo" 2>/dev/null; then ok "$nombre"; else not_ok "$nombre (no contiene '$texto')"; fi
}
assert_empty() {
  if [[ ! -s "$1" ]]; then ok "$2"; else not_ok "$2 (no está vacío: $1)"; fi
}

setup_repo() {
  local destino="$1"
  mkdir -p "$destino"
  cp -R "$ROOT/examples/toy-repo/." "$destino/"
  git -C "$destino" init -q
  git -C "$destino" add -A
  git -C "$destino" -c user.name='Test' -c user.email='test@example.com' commit -qm 'base'
}

run_equipo() {
  local repo="$1" estado="$2"
  shift 2
  (
    cd "$repo"
    PATH="$ROOT/examples/fake-agents:$PATH" \
    EQUIPO_CONFIG="$TMP/sin-config" \
    EQUIPO_STATE_DIR="$estado" \
    EQUIPO_FAKE_FIX="$ROOT/examples/fixtures/index.fixed.js" \
    EQUIPO_FAKE_MODE="${EQUIPO_FAKE_MODE:-fix}" \
    EQUIPO_FAKE_VERDICT="${EQUIPO_FAKE_VERDICT:-APROBADO}" \
    EQUIPO_NPM_CI=no \
    EQUIPO_TIMEOUT=60 \
    EQUIPO_TEST_TIMEOUT=60 \
    bash "$ROOT/equipo-ia.sh" "$@"
  ) > "$LAST_OUT" 2>&1
}

latest_run() {
  ls -1dt "$1"/ejecucion_* 2>/dev/null | head -1 || true
}

# 1. Camino feliz.
setup_repo "$TMP/feliz/repo"
set +e
run_equipo "$TMP/feliz/repo" "$TMP/feliz/estado" --si --modo maximo --intentos 0 "Corrige el saludo"
CODE=$?
set -e
RUN="$(latest_run "$TMP/feliz/estado")"
assert_eq "0" "$CODE" "camino feliz: código de salida"
assert_eq "VALIDADO" "$(cat "$RUN/estado-final.txt" 2>/dev/null || true)" "camino feliz: estado"
assert_eq "APROBADO" "$(cat "$RUN/veredicto.txt" 2>/dev/null || true)" "camino feliz: veredicto"
assert_file "$RUN/cambios.patch" "camino feliz: parche"
assert_contains "$RUN/cambios.patch" 'Hola, ' "camino feliz: contenido del parche"
assert_contains "$RUN/actual-pruebas-resultado.txt" "ESTADO=APROBADO" "camino feliz: pruebas actuales"
assert_contains "$RUN/base-pruebas-resultado.txt" "ESTADO=APROBADO" "camino feliz: pruebas base"
assert_empty "$RUN/rutas-protegidas.txt" "camino feliz: rutas protegidas intactas"
assert_file "$RUN/acta.md" "camino feliz: acta"
if command -v python3 >/dev/null 2>&1; then
  if python3 -m json.tool "$RUN/acta.json" >/dev/null 2>&1; then ok "camino feliz: acta.json válido"; else not_ok "camino feliz: acta.json inválido"; fi
fi

# 1b. /aplicar de la consola.
set +e
printf '/aplicar\nAPLICAR\n/salir\n' | (
  cd "$TMP/feliz/repo"
  EQUIPO_CONFIG="$TMP/sin-config" EQUIPO_STATE_DIR="$TMP/feliz/estado" bash "$ROOT/bin/equipo"
) > "$TMP/aplicar.out" 2>&1
CODE=$?
set -e
assert_eq "0" "$CODE" "aplicar: código de salida"
assert_contains "$TMP/aplicar.out" "Parche aplicado" "aplicar: confirmación"
assert_contains "$TMP/feliz/repo/index.js" 'Hola, ' "aplicar: parche en el repositorio"

# 2. Sin cambios.
setup_repo "$TMP/sin-cambios/repo"
set +e
EQUIPO_FAKE_MODE=noop run_equipo "$TMP/sin-cambios/repo" "$TMP/sin-cambios/estado" --si --modo maximo --intentos 0 "No cambies nada"
CODE=$?
set -e
RUN="$(latest_run "$TMP/sin-cambios/estado")"
assert_eq "10" "$CODE" "sin cambios: código de salida"
assert_eq "SIN_CAMBIOS" "$(cat "$RUN/estado-final.txt" 2>/dev/null || true)" "sin cambios: estado"

# 3. Ruta protegida modificada.
setup_repo "$TMP/protegida/repo"
set +e
EQUIPO_FAKE_MODE=modify-test run_equipo "$TMP/protegida/repo" "$TMP/protegida/estado" --si --modo maximo --intentos 0 "Corrige el saludo"
CODE=$?
set -e
RUN="$(latest_run "$TMP/protegida/estado")"
assert_eq "20" "$CODE" "ruta protegida: código de salida"
assert_eq "REVISION_MANUAL" "$(cat "$RUN/estado-final.txt" 2>/dev/null || true)" "ruta protegida: estado"
assert_contains "$RUN/rutas-protegidas.txt" "test.js" "ruta protegida: detectada"

# 3b. Parche demasiado grande -> revisión manual, no rechazo.
setup_repo "$TMP/grande/repo"
set +e
EQUIPO_DIFF_MAX=100 run_equipo "$TMP/grande/repo" "$TMP/grande/estado" --si --modo maximo --intentos 0 "Corrige el saludo"
CODE=$?
set -e
RUN="$(latest_run "$TMP/grande/estado")"
assert_eq "20" "$CODE" "parche grande: código de salida"
assert_eq "REVISION_MANUAL" "$(cat "$RUN/estado-final.txt" 2>/dev/null || true)" "parche grande: estado"

# 3c. El agente debilita la prueba: las pruebas base deben detectarlo.
setup_repo "$TMP/cheat/repo"
set +e
EQUIPO_FAKE_MODE=cheat run_equipo "$TMP/cheat/repo" "$TMP/cheat/estado" --si --modo maximo --intentos 0 "Corrige el saludo"
CODE=$?
set -e
RUN="$(latest_run "$TMP/cheat/estado")"
assert_eq "20" "$CODE" "prueba debilitada: código de salida"
assert_eq "REVISION_MANUAL" "$(cat "$RUN/estado-final.txt" 2>/dev/null || true)" "prueba debilitada: estado"
assert_contains "$RUN/actual-pruebas-resultado.txt" "ESTADO=APROBADO" "prueba debilitada: actual pasa"
assert_contains "$RUN/base-pruebas-resultado.txt" "ESTADO=FALLIDO" "prueba debilitada: base falla"

# 4. Pruebas fallidas y correcciones agotadas.
setup_repo "$TMP/fallo/repo"
set +e
EQUIPO_FAKE_MODE=break EQUIPO_FAKE_VERDICT=CORRECCIONES run_equipo "$TMP/fallo/repo" "$TMP/fallo/estado" --si --modo maximo --intentos 1 "Corrige el saludo"
CODE=$?
set -e
RUN="$(latest_run "$TMP/fallo/estado")"
assert_eq "30" "$CODE" "pruebas fallidas: código de salida"
assert_eq "RECHAZADO" "$(cat "$RUN/estado-final.txt" 2>/dev/null || true)" "pruebas fallidas: estado"

# 5. Modo inválido.
setup_repo "$TMP/invalido/repo"
set +e
run_equipo "$TMP/invalido/repo" "$TMP/invalido/estado" --si --modo inventado "x"
CODE=$?
set -e
assert_eq "2" "$CODE" "modo inválido: código de salida"
assert_contains "$LAST_OUT" "modo inválido" "modo inválido: mensaje"

# 6. Versión y ayuda.
set +e
bash "$ROOT/equipo-ia.sh" --version > "$TMP/version.txt" 2>&1
CODE=$?
set -e
assert_eq "0" "$CODE" "versión: código de salida"
assert_contains "$TMP/version.txt" "4.3.0" "versión: contenido"
set +e
bash "$ROOT/equipo-ia.sh" --help > "$TMP/ayuda.txt" 2>&1
CODE=$?
set -e
assert_eq "0" "$CODE" "ayuda: código de salida"
assert_contains "$TMP/ayuda.txt" "Uso:" "ayuda: contenido"

# 7. Repositorio sin comando de pruebas -> revisión manual.
mkdir -p "$TMP/sin-pruebas/repo"
printf '# Sin pruebas\n' > "$TMP/sin-pruebas/repo/README.md"
git -C "$TMP/sin-pruebas/repo" init -q
git -C "$TMP/sin-pruebas/repo" add -A
git -C "$TMP/sin-pruebas/repo" -c user.name='Test' -c user.email='test@example.com' commit -qm 'base'
set +e
run_equipo "$TMP/sin-pruebas/repo" "$TMP/sin-pruebas/estado" --si --modo maximo --intentos 0 "Añade una función"
CODE=$?
set -e
RUN="$(latest_run "$TMP/sin-pruebas/estado")"
assert_eq "20" "$CODE" "sin pruebas: código de salida"
assert_eq "REVISION_MANUAL" "$(cat "$RUN/estado-final.txt" 2>/dev/null || true)" "sin pruebas: estado"
assert_contains "$RUN/actual-pruebas-resultado.txt" "REVISION_MANUAL" "sin pruebas: resultado manual"

# 8. Modo continuo con OpenCode simulado.
setup_repo "$TMP/continuo/repo"
set +e
run_equipo "$TMP/continuo/repo" "$TMP/continuo/estado" --si --modo continuo --intentos 0 "Corrige el saludo"
CODE=$?
set -e
RUN="$(latest_run "$TMP/continuo/estado")"
assert_eq "0" "$CODE" "modo continuo: código de salida"
assert_eq "VALIDADO" "$(cat "$RUN/estado-final.txt" 2>/dev/null || true)" "modo continuo: estado"

printf '\n%d pruebas aprobadas, %d fallidas.\n' "$PASS" "$FAIL"
((FAIL == 0))
