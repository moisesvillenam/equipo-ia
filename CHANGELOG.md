# Changelog

## 4.3.1 — 2026-10-22

Correcciones a partir de una ejecución real sobre un repositorio con la suite
desactualizada.

### Corregido

- El revisor AGY en modo `--print` recibe `--dangerously-skip-permissions` por
  defecto. Sin esa opción, cualquier comando requerido se denegaba y no había
  veredicto. Sigue en `--mode plan` y `--sandbox`; se puede desactivar con
  `EQUIPO_REVIEWER_SKIP_PERMISSIONS=no`.
- La validación distingue fallos preexistentes de regresiones: se añade una
  tercera tanda con el commit original sin parche (línea base). El parche solo se
  rechaza por fallos nuevos.
- Si la línea base ya estaba roja, el programador ya no gasta rondas intentando
  arreglar pruebas que no rompió.
- Un fallo del revisor (`INDETERMINADO`) ya no dispara una corrección del
  programador: pasa directamente a `REVISION_MANUAL`.
- `/aplicar` recompueba las regresiones, el control y la posible prueba
  debilitada mediante `validacion.txt`.

### Añadido

- Artefactos `linea-base-pruebas-*`, `fallos-*.txt` y `validacion.txt`.
- Campos `baseline_tests`, `control_tests`, `baseline`, `new_failures`,
  `control_new_failures`, `fixed_failures` y `weakened_test` en `acta.json`.
- Repositorio de juguete con línea base roja y pruebas específicas de regresión.
- ADR 0005: validación relativa a la línea base.

### Cambiado

- `VALIDADO` significa “sin fallos nuevos respecto a la línea base (actual y
  control)”, no “todas las pruebas pasan”.
- `EQUIPO_BASE_TESTS=no` omite línea base y control, y exige pruebas actuales
  verdes.

## 4.3.0 — 2026-10-22

Primera versión pública de Equipo IA.

### Añadido

- Flujo de solo parche: el agente trabaja sobre una copia temporal y el
  repositorio original no se modifica.
- Pruebas congeladas: las pruebas actuales y las de la base se ejecutan en copias
  desechables; en la copia base se restauran las rutas protegidas desde el
  commit original y se usa su comando de pruebas.
- Rutas protegidas: cambios en pruebas, locks, CI, auth o migraciones pasan a
  `REVISION_MANUAL`.
- Veredicto del revisor con nonce generado después del parche.
- Estados `VALIDADO`, `SIN_CAMBIOS`, `REVISION_MANUAL` y `RECHAZADO`, con códigos
  de salida estables.
- Acta `acta.md` y `acta.json` con hashes, pruebas, rutas y límites.
- Modos `maximo` (Codex), `continuo` (OpenCode) y `auto` por disponibilidad.
- Consola `equipo` con `/diff`, `/revision`, `/ultimo` y `/aplicar`.
- Timeouts por agente y por pruebas.
- Segunda opinión opcional.
- Demo y pruebas de extremo a extremo con agentes simulados, sin red ni claves.
- Documentación, ADRs, CI, plantillas de issues y política de seguridad.

### Limitaciones conocidas

- No es un sandbox de seguridad.
- La detección automática cubre npm, pytest y testthat.
- No hay integración de GitHub Actions para ejecutar el flujo.
- La copia base usa `git archive`; submodules y Git LFS pueden requerir ajustes.
