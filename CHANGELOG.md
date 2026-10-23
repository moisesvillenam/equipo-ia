# Changelog

## 4.5.0 — 2026-10-23

- Aplicación Windows Forms con preparación guiada de WSL/Ubuntu, instalación y
  conexión oficial de Codex, selector de proyecto, tareas, resultados e historial.
- Puente Python sin dependencias externas ni servidor: trabajos con estado propio,
  exclusión mutua, comprobación de huella y aplicación mediante la consola existente.
- Ejemplo simulado persistente y guardado opcional de una versión local tras aplicar,
  con rechazo si hubo cambios adicionales.
- Adaptador de revisión Codex de solo lectura mediante el contrato `command`.
- Instalación por usuario, paquete ZIP, guía y pruebas Linux/Windows para la interfaz.
- Sin cambios en la política de validación de la consola. El mantenedor informó haberla probado en Windows;
  se mantiene como vista previa mientras se documenta la aceptación completa.

## 4.4.0 — 2026-10-23

- `/publicar` muestra commit y destino, exige pruebas aprobadas y confirmación,
  y envía exclusivamente ese commit a la rama remota, sin forzar ni enviar etiquetas.
- `/publicar comprobar` permite revisar destino y pruebas sin enviar cambios.
- Se rechazan cambios pendientes, HEAD separado, múltiples destinos y cambios del
  commit, rama o destino durante la comprobación. Se guardan informes de publicación.
- El instalador incluye el publicador. Pruebas con remotos Git locales en CI.
- Los comandos desconocidos que empiezan por `/` ya no se envían al programador.

## 4.3.2 — 2026-10-22

### Corregido

- Un fallo genérico del proceso de pruebas (`ERR_TEST_FAILURE`) ya no permite
  validar un parche por coincidir con el fallo genérico de la línea base.
- Las comparaciones con línea base roja requieren informes comparables en
  ambas tandas. TAP truncado, cancelaciones, fallos agregados, errores de
  recolección y recuentos incompatibles pasan a `REVISION_MANUAL`.
- `/aplicar` exige evidencia de comparabilidad cuando las pruebas siguen
  fallando. Las ejecuciones antiguas sin esa evidencia deben repetirse.

### Pruebas y documentación

- Casos de regresión para fallos de proceso en cada tanda, TAP incompleto,
  nombres duplicados y aplicación con línea base roja.
- El ejemplo de base roja ejecuta `node test.js`: conserva las pruebas reales
  de `node:test` y su salida TAP sin necesitar un proceso hijo de `node --test`.
- Se aclara que ampliar funcionalidades puede exigir actualizar el contrato
  de pruebas mediante revisión humana; un fallo nuevo no es preexistente.

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
