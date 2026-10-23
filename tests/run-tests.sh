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

setup_repo_red() {
  local destino="$1"
  mkdir -p "$destino"
  cp -R "$ROOT/examples/toy-repo-red/." "$destino/"
  git -C "$destino" init -q
  git -C "$destino" add -A
  git -C "$destino" -c user.name='Test' -c user.email='test@example.com' commit -qm 'base roja'
}

setup_repo_verde() {
  local destino="$1"
  setup_repo "$destino"
  cp "$ROOT/examples/fixtures/index.fixed.js" "$destino/index.js"
  git -C "$destino" add -A
  git -C "$destino" -c user.name='Test' -c user.email='test@example.com' commit -qm 'base verde'
}

run_equipo() {
  local repo="$1" estado="$2"
  shift 2
  (
    cd "$repo"
    PATH="$ROOT/examples/fake-agents:$PATH" \
    EQUIPO_CONFIG="$TMP/sin-config" \
    EQUIPO_STATE_DIR="$estado" \
    EQUIPO_FAKE_FIX="${EQUIPO_FAKE_FIX:-$ROOT/examples/fixtures/index.fixed.js}" \
    EQUIPO_FAKE_MODE="${EQUIPO_FAKE_MODE:-fix}" \
    EQUIPO_FAKE_VERDICT="${EQUIPO_FAKE_VERDICT:-APROBADO}" \
    EQUIPO_FAKE_AGY_ARGS="$TMP/agy-args.txt" \
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
assert_contains "$TMP/agy-args.txt" "--dangerously-skip-permissions" "revisor agy: permisos automáticos en modo headless"
assert_contains "$RUN/validacion.txt" "REGRESIONES=0" "camino feliz: validación sin regresiones"
assert_contains "$RUN/validacion.txt" "PRUEBA_DEBILITADA=0" "camino feliz: sin prueba debilitada"

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

# 4. Línea base verde, pruebas rotas y correcciones agotadas.
setup_repo_verde "$TMP/fallo/repo"
set +e
EQUIPO_FAKE_MODE=break EQUIPO_FAKE_VERDICT=CORRECCIONES run_equipo "$TMP/fallo/repo" "$TMP/fallo/estado" --si --modo maximo --intentos 1 "Corrige el saludo"
CODE=$?
set -e
RUN="$(latest_run "$TMP/fallo/estado")"
assert_eq "30" "$CODE" "pruebas fallidas: código de salida"
assert_eq "RECHAZADO" "$(cat "$RUN/estado-final.txt" 2>/dev/null || true)" "pruebas fallidas: estado"
assert_contains "$RUN/linea-base-pruebas-resultado.txt" "ESTADO=APROBADO" "pruebas fallidas: línea base pasa"
assert_contains "$RUN/motivo.txt" "fallos nuevos" "pruebas fallidas: regresión detectada"

# 4b. Base roja sin regresiones: el parche se valida igualmente.
setup_repo_red "$TMP/roja-ok/repo"
set +e
EQUIPO_FAKE_FIX="$ROOT/examples/fixtures/index.hardened.js" run_equipo "$TMP/roja-ok/repo" "$TMP/roja-ok/estado" --si --modo maximo --intentos 0 "Añade una despedida"
CODE=$?
set -e
RUN="$(latest_run "$TMP/roja-ok/estado")"
assert_eq "0" "$CODE" "base roja sin regresiones: código de salida"
assert_eq "VALIDADO" "$(cat "$RUN/estado-final.txt" 2>/dev/null || true)" "base roja sin regresiones: estado"
assert_contains "$RUN/base-pruebas-resultado.txt" "ESTADO=FALLIDO" "base roja sin regresiones: base falla"
assert_contains "$RUN/actual-pruebas-resultado.txt" "ESTADO=FALLIDO" "base roja sin regresiones: actual falla"
assert_empty "$RUN/fallos-nuevos.txt" "base roja sin regresiones: sin fallos nuevos"
assert_contains "$RUN/motivo.txt" "la línea base ya fallaba" "base roja sin regresiones: motivo"
assert_contains "$RUN/acta.md" "Fallos nuevos en las pruebas actuales: \`0\`" "base roja sin regresiones: acta"
assert_contains "$RUN/prompt-revisor-r0.txt" "Estado de la línea base: roja (comparable)" "base roja sin regresiones: prompt del revisor"
assert_contains "$RUN/linea-base-pruebas-resultado.txt" "ESTADO=FALLIDO" "base roja sin regresiones: línea base falla"
if command -v python3 >/dev/null 2>&1; then
  if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d["new_failures"]==[] and d["baseline"].startswith("roja") else 1)' "$RUN/acta.json" >/dev/null 2>&1; then
    ok "base roja sin regresiones: acta.json coherente"
  else
    not_ok "base roja sin regresiones: acta.json incoherente"
  fi
fi

# 4c. Base roja con regresión nueva: se rechaza y se nombra el fallo.
# Antes, comprobar que /aplicar exige evidencia nueva para una base roja.
cp "$RUN/validacion.txt" "$TMP/validacion-roja.txt"
sed '/^COMPARABLE_/d' "$TMP/validacion-roja.txt" > "$RUN/validacion.txt"
printf '/aplicar\n/salir\n' | (
  cd "$TMP/roja-ok/repo"
  EQUIPO_CONFIG="$TMP/sin-config" EQUIPO_STATE_DIR="$TMP/roja-ok/estado" bash "$ROOT/bin/equipo"
) > "$TMP/aplicar-legado.out" 2>&1
assert_contains "$TMP/aplicar-legado.out" "Repite la validación" "aplicar base roja antigua: exige evidencia comparable"
assert_eq "" "$(git -C "$TMP/roja-ok/repo" status --porcelain)" "aplicar base roja antigua: no modifica el proyecto"
cp "$TMP/validacion-roja.txt" "$RUN/validacion.txt"
printf '/aplicar\nAPLICAR\n/salir\n' | (
  cd "$TMP/roja-ok/repo"
  EQUIPO_CONFIG="$TMP/sin-config" EQUIPO_STATE_DIR="$TMP/roja-ok/estado" bash "$ROOT/bin/equipo"
) > "$TMP/aplicar-roja.out" 2>&1
assert_contains "$TMP/aplicar-roja.out" "Parche aplicado" "aplicar base roja comparable: permitido"

setup_repo_red "$TMP/roja-regresion/repo"
set +e
EQUIPO_FAKE_MODE=break run_equipo "$TMP/roja-regresion/repo" "$TMP/roja-regresion/estado" --si --modo maximo --intentos 0 "Añade una despedida"
CODE=$?
set -e
RUN="$(latest_run "$TMP/roja-regresion/estado")"
assert_eq "30" "$CODE" "base roja con regresión: código de salida"
assert_eq "RECHAZADO" "$(cat "$RUN/estado-final.txt" 2>/dev/null || true)" "base roja con regresión: estado"
assert_contains "$RUN/fallos-nuevos.txt" "greet devuelve el saludo con coma" "base roja con regresión: fallo nuevo identificado"
assert_contains "$RUN/motivo.txt" "fallos nuevos respecto a la línea base" "base roja con regresión: motivo"

# 4d. Línea base roja sin salida TAP y parche que la deja verde: se valida.
setup_repo "$TMP/roja-sin-tap/repo"
set +e
run_equipo "$TMP/roja-sin-tap/repo" "$TMP/roja-sin-tap/estado" --si --modo maximo --intentos 0 "Corrige el saludo"
CODE=$?
set -e
RUN="$(latest_run "$TMP/roja-sin-tap/estado")"
assert_eq "0" "$CODE" "base roja reparada: código de salida"
assert_eq "VALIDADO" "$(cat "$RUN/estado-final.txt" 2>/dev/null || true)" "base roja reparada: estado"
assert_contains "$RUN/linea-base-pruebas-resultado.txt" "ESTADO=FALLIDO" "base roja reparada: línea base falla"
assert_contains "$RUN/actual-pruebas-resultado.txt" "ESTADO=APROBADO" "base roja reparada: actual pasa"

# 4e. Pruebas de referencia desactivadas: basta con que pasen las actuales.
setup_repo_verde "$TMP/sin-referencia/repo"
set +e
EQUIPO_BASE_TESTS=no EQUIPO_FAKE_FIX="$ROOT/examples/fixtures/index.hardened.js" \
  run_equipo "$TMP/sin-referencia/repo" "$TMP/sin-referencia/estado" --si --modo maximo --intentos 0 "Añade una despedida"
CODE=$?
set -e
RUN="$(latest_run "$TMP/sin-referencia/estado")"
assert_eq "0" "$CODE" "sin referencia: código de salida"
assert_eq "VALIDADO" "$(cat "$RUN/estado-final.txt" 2>/dev/null || true)" "sin referencia: estado"
assert_contains "$RUN/linea-base-pruebas-resultado.txt" "ESTADO=OMITIDO" "sin referencia: línea base omitida"
assert_contains "$RUN/motivo.txt" "desactivados" "sin referencia: motivo"

# 4f. Los fallos de proceso no demuestran que no hay regresiones.
# La salida es determinista: cubre también máquinas donde Node sí puede crear
# procesos hijos. Se prueba cada tanda para que ninguna omita la comprobación.
cat > "$TMP/fallo-proceso.tap" <<'EOF'
TAP version 13
not ok 1 - legacy: el saludo no lleva coma
  ---
  failureType: 'testCodeFailure'
  exitCode: 1
  code: 'ERR_TEST_FAILURE'
  ...
1..1
# tests 1
# fail 1
EOF
for tanda in todas linea-base actual verificacion; do
  setup_repo_red "$TMP/proceso-$tanda/repo"
  # El comando es el mismo en todas las copias; solo varía la salida simulada.
  patron="$tanda-*"
  [[ "$tanda" != todas ]] || patron='*'
  CMD="case \"\${PWD##*/}\" in $patron) cat '$TMP/fallo-proceso.tap'; exit 1 ;; *) node test.js ;; esac"
  set +e
  EQUIPO_FAKE_FIX="$ROOT/examples/fixtures/index.hardened.js" \
    run_equipo "$TMP/proceso-$tanda/repo" "$TMP/proceso-$tanda/estado" \
    --si --modo maximo --intentos 0 --test-cmd "$CMD" "Añade una despedida"
  CODE=$?
  set -e
  RUN="$(latest_run "$TMP/proceso-$tanda/estado")"
  assert_eq "20" "$CODE" "fallo de proceso ($tanda): código manual"
  assert_eq "REVISION_MANUAL" "$(cat "$RUN/estado-final.txt")" "fallo de proceso ($tanda): nunca validado"
  assert_contains "$RUN/motivo.txt" "no se pueden comparar" "fallo de proceso ($tanda): motivo"
done

# 4g. TAP incompleto o con nombres duplicados tampoco es comparable.
for caso in truncado duplicado; do
  setup_repo_red "$TMP/tap-$caso/repo"
  printf 'TAP version 13\nnot ok 1 - repetido\n' > "$TMP/$caso.tap"
  if [[ "$caso" == duplicado ]]; then
    printf 'not ok 2 - repetido\n1..2\n# fail 2\n' >> "$TMP/$caso.tap"
  fi
  set +e
  EQUIPO_FAKE_MODE=break run_equipo "$TMP/tap-$caso/repo" "$TMP/tap-$caso/estado" \
    --si --modo maximo --intentos 0 --test-cmd "cat '$TMP/$caso.tap'; exit 1" "Corrige el saludo"
  CODE=$?
  set -e
  assert_eq "20" "$CODE" "TAP $caso: revisión manual"
done

# 4h. Pytest: conservar la comparación completa y bloquear informes parciales.
for caso in completo truncado error; do
  setup_repo_red "$TMP/pytest-$caso/repo"
  printf 'FAILED tests/test_example.py::test_legacy - AssertionError\n' > "$TMP/pytest-$caso.log"
  esperado=20
  if [[ "$caso" != truncado ]]; then
    printf '1 failed in 0.02s\n' >> "$TMP/pytest-$caso.log"
    esperado=0
  fi
  if [[ "$caso" == error ]]; then
    printf 'ERROR tests/test_other.py - ImportError\n' >> "$TMP/pytest-$caso.log"
    esperado=20
  fi
  set +e
  EQUIPO_FAKE_FIX="$ROOT/examples/fixtures/index.hardened.js" \
    run_equipo "$TMP/pytest-$caso/repo" "$TMP/pytest-$caso/estado" \
    --si --modo maximo --intentos 0 --test-cmd "cat '$TMP/pytest-$caso.log'; exit 1" "Añade una despedida"
  CODE=$?
  set -e
  assert_eq "$esperado" "$CODE" "pytest $caso: comparabilidad del informe"
done

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
assert_contains "$TMP/version.txt" "4.4.0" "versión: contenido"
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
