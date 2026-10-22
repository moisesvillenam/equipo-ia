# ADR 0001: ejecutar pruebas sobre el commit base

> **Actualizado por [ADR 0005](0005-validacion-relativa.md).** Desde 4.3.1 se
> ejecutan tres tandas: línea base sin parche, actual y control. La tanda de
> control descrita aquí se conserva; la validación ya no exige que todas las
> pruebas pasen, sino que no haya fallos nuevos respecto a la línea base.

## Contexto

Un agente puede modificar las pruebas o el comando de pruebas para que el parche
parezca correcto. Ejecutar solo las pruebas del árbol modificado no detecta ese
riesgo ni las regresiones que aparecen al aplicar el parche sobre el estado real
del repositorio.

## Decisión

Después de generar el parche, crear dos copias del commit base y aplicarles el
parche: una para las pruebas actuales y otra para las pruebas congeladas. En la
segunda se restauran las rutas protegidas desde la base, de modo que se ejecuten
las pruebas y la configuración originales aunque el agente las haya cambiado.

## Consecuencias

- Más tiempo de ejecución y, en Node, posible instalación de dependencias en
  cada copia. Se mitiga con `EQUIPO_NPM_CI=si`, que ejecuta `npm ci` antes de las
  pruebas. No se reutiliza el `node_modules` del agente.
- Un `VALIDADO` requiere que ambas tandas pasen.
- Si no se puede ejecutar la tanda base, el estado es `REVISION_MANUAL`.
- Submodules, LFS y archivos generados pueden requerir ajustes; se documenta como
  limitación.
