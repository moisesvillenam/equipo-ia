# ADR 0005: validación relativa a la línea base

## Contexto

La primera versión comparaba el parche con una copia del commit base a la que
también se aplicaba el parche y se le restauraban las rutas protegidas. Esa copia
es un **control** para detectar pruebas debilitadas, pero no la línea base: si el
commit original ya tenía pruebas rojas, el control también fallaba y el parche
parecía culpable.

En un repositorio real, tres pruebas afirmaban el comportamiento anterior de la
interfaz. Cualquier cambio que añadiera funciones científicas las hacía fallar.
El orquestador pidió correcciones al programador, gastó rondas y terminó en
`RECHAZADO` sin distinguir el fallo preexistente del introducido.

## Decisión

Ejecutar tres tandas y comparar por nombre de prueba:

1. **Línea base:** commit original, sin parche.
2. **Actual:** commit base + parche, con las pruebas del agente.
3. **Control:** commit base + parche, con las rutas protegidas restauradas.

Un parche se valida si no añade fallos que no estuvieran en la línea base, tanto
en la tanda actual como en el control. Si la línea base ya fallaba, no se exige
arreglarla. Si el control falla donde la tanda actual pasa, se marca una posible
prueba debilitada.

La comparación extrae `not ok` de TAP y `FAILED` de pytest. Si no hay nombres de
prueba comparables, el resultado es `REVISION_MANUAL`; no se asume que no hay
regresión.

## Consecuencias

- Un repositorio con la suite roja ya no bloquea todos los parches.
- Se detectan regresiones reales sin castigar fallos heredados.
- El coste es una ejecución adicional de pruebas.
- La comparación es heurística: nombres repetidos o tests renombrados pueden
  confundirla. El acta muestra las listas para revisión humana.
- `EQUIPO_BASE_TESTS=no` vuelve al modo estricto: las pruebas actuales deben pasar.
