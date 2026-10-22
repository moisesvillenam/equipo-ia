# Preguntas frecuentes

## ¿Por qué no aplica el parche automáticamente?

Porque el estado `VALIDADO` significa “se cumplieron las comprobaciones”, no
“el cambio es deseable”. `/aplicar` exige confirmación y vuelve a comprobar
estado, pruebas, nonce, commit y limpieza.

## ¿Qué diferencia hay entre `REVISION_MANUAL` y `RECHAZADO`?

`RECHAZADO` indica un fallo objetivo: el programador falló, el parche no aplica o
introduce fallos nuevos respecto a la línea base. `REVISION_MANUAL` indica falta
de evidencia o un riesgo que requiere una persona: pruebas no disponibles, rutas
protegidas modificadas, posible prueba debilitada o revisor sin veredicto.

## ¿Puedo usarlo en un repositorio con cambios sin commitear?

No. El orquestador exige un árbol limpio para que el parche tenga una base
inequívoca. Haz commit o stash antes.

## ¿Puedo usarlo en un monorepo?

Sí, pero define `EQUIPO_TEST_CMD` para que apunte al paquete correcto y ajusta
`EQUIPO_PROTECTED_PATHS`. La copia base incluye todo el repositorio.

## ¿Cómo funcionan las pruebas congeladas si el agente añade pruebas nuevas?

Se ejecutan tres tandas: la línea base (commit original), la actual (parche con
las pruebas del agente) y el control (parche con las pruebas originales). Las
pruebas nuevas del agente cuentan en la tanda actual. Un `VALIDADO` exige que no
haya fallos nuevos respecto a la línea base en la actual ni en el control. Si el
agente cambia archivos de pruebas, se marca `REVISION_MANUAL`.

## ¿Qué pasa si la suite ya estaba roja antes del parche?

La validación es relativa: se comparan los nombres de las pruebas fallidas contra
la línea base. Los fallos preexistentes no bloquean; los nuevos sí. Si no se
pueden identificar los nombres (salida no TAP ni pytest), el estado es
`REVISION_MANUAL`.

## ¿Por qué se ejecutan tres veces las pruebas?

Porque una regresión puede aparecer solo al aplicar el parche, el agente puede
haber debilitado la suite, y la base puede haber estado roja antes. La línea base
da el punto de partida; la actual mide el resultado; el control verifica las
pruebas originales.

## ¿Por qué una nueva funcionalidad puede quedar rechazada?

Si las pruebas originales pasan y el parche las rompe, son fallos nuevos aunque
la tarea cambie intencionadamente el comportamiento. Por ejemplo, una prueba
que exige conservar todo el HTML ya no encaja al añadir botones. Revisa y
actualiza ese contrato en un cambio separado, con pruebas de la funcionalidad
nueva. La validación relativa no convierte esos fallos en preexistentes.

Si Node solo informa que falló el archivo o el proceso (`ERR_TEST_FAILURE`),
no se conocen los resultados individuales: con línea base roja se requiere
`REVISION_MANUAL`. Revisa el log, las dependencias y los permisos del entorno.

## ¿Necesito `npm ci`?

Sí, si tu proyecto Node tiene dependencias. Las pruebas se ejecutan en copias
limpias del árbol, no en el `node_modules` del agente. Con
`EQUIPO_NPM_CI=si` se instalan dependencias en cada copia; sin autorización, las
pruebas pueden fallar y el estado será `RECHAZADO` o `REVISION_MANUAL`. También
puedes fijar un comando que use un entorno ya preparado con
`EQUIPO_TEST_CMD`.

## ¿Puedo desactivar las pruebas de referencia?

Sí:

```bash
EQUIPO_BASE_TESTS=no
```

Entonces se omiten la línea base y el control, y las pruebas actuales deben pasar
para obtener `VALIDADO`. Es más rápido, pero no distingue fallos preexistentes ni
detecta pruebas debilitadas. La opción existe para depurar o para proyectos donde
la comparación no es fiable.

## ¿Cómo añado soporte para otra pila?

Define el comando:

```bash
EQUIPO_TEST_CMD="cargo test"
```

La detección automática solo cubre npm, pytest y testthat. Añadir un detector
nuevo requiere modificar `equipo-pruebas.sh` y las pruebas.

## ¿Funciona en macOS?

Sí, con Bash 4+ y `timeout` de GNU coreutils (`gtimeout`). El script detecta
`timeout` o `gtimeout`; si no, define `EQUIPO_TIMEOUT_BIN`. `sha256sum` se
sustituye por `shasum`.

## ¿Funciona en Windows?

Se recomienda WSL. Git Bash puede funcionar, pero `timeout`, permisos y rutas
pueden dar problemas.

## ¿Dónde están las claves de API?

No hay claves en el repositorio. Los agentes usan la autenticación que ya tengas
configurada. La demo no necesita claves.

## ¿Puedo usar solo un agente?

Sí. `EQUIPO_REVIEWER=none` genera el parche y deja el estado en
`REVISION_MANUAL`; después revisas el diff a mano. También puedes usar
`EQUIPO_SECOND_OPINION=no` (por defecto).

## ¿El nonce es secreto?

No es un secreto criptográfico; es un valor aleatorio generado después del
parche. Su función es evitar que un diff contenga un veredicto válido. El revisor
lo recibe en el prompt.

## ¿Por qué Bash?

Porque el flujo es transparente, fácil de auditar y funciona con las CLIs que ya
tienes. No requiere un runtime adicional. La contrapartida es que no es un
lenguaje ideal para proyectos muy grandes; por eso el núcleo es pequeño y las
pruebas cubren el flujo completo.

## ¿Hay integración con GitHub Actions?

No incluida. El flujo está pensado para ejecutarse localmente y revisar el
parche. La CI del repositorio valida el propio Equipo IA. Una integración futura
podría publicar el acta como artefacto y abrir un PR.

## ¿Cómo reporto un bug?

Abre un issue con la plantilla del repositorio. Incluye sistema operativo,
versión de Bash, modo, estado y el acta **sin datos privados**. Para
vulnerabilidades, usa Security Advisories.
