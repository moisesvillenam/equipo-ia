# ADR 0001: ejecutar pruebas sobre el commit base

## Contexto

Un agente puede modificar las pruebas o el comando de pruebas para que el parche
parezca correcto. Ejecutar solo las pruebas del árbol modificado no detecta ese
riesgo ni las regresiones que aparecen al aplicar el parche sobre el estado real
del repositorio.

## Decisión

Después de generar el parche, crear una copia del commit base, aplicar el parche
y ejecutar el mismo comando de pruebas. El comando se detecta desde la copia
base, no desde el árbol del agente.

## Consecuencias

- Más tiempo de ejecución y, en Node, posible segunda instalación de
  dependencias. Se mitiga copiando `node_modules` cuando no hay `npm ci`, o
  autorizando `npm ci`.
- Un `VALIDADO` requiere que ambas tandas pasen.
- Si no se puede ejecutar la tanda base, el estado es `REVISION_MANUAL`.
- Submodules, LFS y archivos generados pueden requerir ajustes; se documenta como
  limitación.
