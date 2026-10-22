# Preguntas frecuentes

## ¿Por qué no aplica el parche automáticamente?

Porque el estado `VALIDADO` significa “se cumplieron las comprobaciones”, no
“el cambio es deseable”. `/aplicar` exige confirmación y vuelve a comprobar
estado, pruebas, nonce, commit y limpieza.

## ¿Qué diferencia hay entre `REVISION_MANUAL` y `RECHAZADO`?

`RECHAZADO` indica un fallo objetivo: el programador falló, el parche no aplica o
las pruebas fallaron. `REVISION_MANUAL` indica falta de evidencia o un riesgo que
requiere una persona: pruebas no disponibles, rutas protegidas modificadas,
revisor sin veredicto o segunda opinión inconclusa.

## ¿Puedo usarlo en un repositorio con cambios sin commitear?

No. El orquestador exige un árbol limpio para que el parche tenga una base
inequívoca. Haz commit o stash antes.

## ¿Puedo usarlo en un monorepo?

Sí, pero define `EQUIPO_TEST_CMD` para que apunte al paquete correcto y ajusta
`EQUIPO_PROTECTED_PATHS`. La copia base incluye todo el repositorio.

## ¿Cómo funcionan las pruebas congeladas si el agente añade pruebas nuevas?

Las pruebas base ejecutan el comando del commit base. Las pruebas actuales se
ejecutan en una copia del commit base con el parche aplicado y sí incluyen las
pruebas nuevas. Un `VALIDADO` exige que ambas pasen. Si el agente cambia
archivos de pruebas, se marca `REVISION_MANUAL`.

## ¿Por qué se ejecutan dos veces las pruebas?

Porque una regresión puede aparecer solo al aplicar el parche sobre la base, o el
agente puede haber debilitado la suite. La segunda tanda es la verificación
congelada.

## ¿Necesito `npm ci`?

Sí, si tu proyecto Node tiene dependencias. Las pruebas se ejecutan en copias
limpias del árbol, no en el `node_modules` del agente. Con
`EQUIPO_NPM_CI=si` se instalan dependencias en cada copia; sin autorización, las
pruebas pueden fallar y el estado será `RECHAZADO` o `REVISION_MANUAL`. También
puedes fijar un comando que use un entorno ya preparado con
`EQUIPO_TEST_CMD`.

## ¿Puedo desactivar las pruebas base?

Sí:

```bash
EQUIPO_BASE_TESTS=no
```

Pero entonces el estado nunca será `VALIDADO`; será `REVISION_MANUAL`. La opción
existe para depurar, no para saltarse la garantía.

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
