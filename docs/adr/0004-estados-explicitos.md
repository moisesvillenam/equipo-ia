# ADR 0004: estados explícitos y conservadores

## Contexto

Un booleano “éxito/fallo” oculta casos importantes: no hay pruebas, el revisor no
concluye, el agente tocó rutas protegidas o el parche no se aplica. Convertir
esos casos en “fallo” o “éxito” degrada la confianza.

## Decisión

Usar cuatro estados:

- `VALIDADO`: todas las comprobaciones pasaron.
- `SIN_CAMBIOS`: no hay parche.
- `REVISION_MANUAL`: falta evidencia o hay un riesgo que requiere una persona.
- `RECHAZADO`: fallo objetivo.

Cada estado tiene un código de salida estable y un motivo escrito.

## Consecuencias

- La automatización puede distinguir “no hay pruebas” de “las pruebas fallaron”.
- Un `VALIDADO` es más difícil de obtener, pero significa más.
- `REVISION_MANUAL` puede ser el resultado más común en proyectos sin suite de
  pruebas; es intencional.
- El usuario debe leer el acta; el estado no es una autorización.
