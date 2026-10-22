# Arquitectura

## Componentes

| Componente | Responsabilidad |
|---|---|
| `equipo-ia.sh` | Orquesta la ejecución: copia base, agentes, parche, pruebas, revisión, estado y acta. |
| `equipo-pruebas.sh` | Detecta el comando de pruebas, ejecuta `npm ci` si se autorizó y escribe un resultado estructurado. |
| `bin/equipo` | Consola interactiva: tareas, `/diff`, `/revision`, `/aplicar`. |
| `examples/fake-agents/` | Agentes simulados para demo y pruebas. |
| `tests/run-tests.sh` | Pruebas de extremo a extremo sin red ni claves. |

## Flujo

```text
1. Verificar repositorio limpio y obtener BASE_SHA.
2. Crear WORK con `git archive BASE_SHA`.
3. Ejecutar el programador sobre WORK.
4. Generar `cambios.patch` con `git diff --cached BASE_WORK`.
5. Comprobar rutas protegidas.
6. Crear una copia del commit base, aplicarle el parche y ejecutar las pruebas
   actuales en esa copia (no en WORK).
7. Crear otra copia, aplicar el parche, restaurar desde la base todas las rutas
   protegidas y ejecutar las pruebas congeladas.
8. Generar nonce, pedir veredicto al revisor y extraer la última línea válida.
9. Si falla algo corregible, repetir con el informe del revisor y las pruebas.
10. Clasificar el estado, escribir acta y dejar el parche sin aplicar.
```

## Invariantes

- El repositorio original no se modifica durante la ejecución.
- El parche siempre se calcula contra el commit base, no contra el árbol del
  agente.
- Las pruebas se ejecutan en copias desechables; sus efectos secundarios no
  entran en el parche.
- Un `VALIDADO` exige parche aplicable, pruebas actuales aprobadas, pruebas base
  aprobadas, rutas protegidas intactas y veredicto aprobado.
- El nonce se genera **después** del parche; el diff no puede contenerlo.
- `REVISION_MANUAL` es el estado por defecto cuando falta evidencia.
- `/aplicar` vuelve a comprobar estado, pruebas, nonce, commit y limpieza antes
  de ejecutar `git apply`.

## Por qué una copia temporal

El agente podría borrar archivos, cambiar el historial o dejar el árbol sucio.
Trabajar sobre una copia permite:

- generar un parche reproducible;
- ejecutar pruebas sin miedo a perder trabajo;
- comparar contra la base;
- descartar todo si el resultado no convence.

La copia se crea con `git archive`, que excluye `.git` y respeta los atributos de
exportación. Limitación: submodules, Git LFS y archivos generados pueden no estar
presentes; en esos casos hay que completar la copia o usar un comando de pruebas
que no dependa de ellos.

## Pruebas congeladas

La misma detección se ejecuta en dos copias desechables:

- **Actual:** copia del commit base + parche. Incluye las pruebas nuevas o
  modificadas por el agente.
- **Base:** copia del commit base + parche, pero restaurando desde la base todas
  las rutas protegidas. Usa las pruebas y la configuración originales.

`equipo-pruebas.sh` detecta, en este orden:

1. `EQUIPO_TEST_CMD`, si está definido;
2. `npm test`, si `package.json` tiene un script de test real;
3. `python3 -m pytest -q`, si hay configuración o carpeta `tests/` y pytest;
4. `testthat::test_dir("tests/testthat")`, si hay `DESCRIPTION` y testthat.

En la copia base, `package.json` y los archivos de pruebas se restauran desde el
commit original. Así, si el agente debilita una prueba, la tanda base sigue
ejecutando la prueba original y detecta la diferencia. `EQUIPO_NPM_CI=si` permite
instalar dependencias limpias en ambas copias.

## Clasificación

```text
sin parche                          -> SIN_CAMBIOS
programador falló                   -> RECHAZADO
parche excede el límite             -> REVISION_MANUAL
parche no aplica                    -> RECHAZADO
rutas protegidas modificadas        -> REVISION_MANUAL
pruebas actuales o base fallaron    -> RECHAZADO
pruebas no disponibles              -> REVISION_MANUAL
revisor no concluyente              -> REVISION_MANUAL
todo lo anterior correcto           -> VALIDADO
```

## Configuración

Precedencia: argumentos de línea de comandos > variables de entorno > archivo
`~/.config/equipo-ia/config.env` > valores por defecto. El cargador de configuración
solo asigna claves que no estén ya definidas en el entorno; no ejecuta el archivo.

## Decisiones relacionadas

- [ADR 0001: pruebas congeladas](adr/0001-pruebas-congeladas.md)
- [ADR 0002: parche contra commit base](adr/0002-parche-contra-commit-base.md)
- [ADR 0003: veredicto con nonce](adr/0003-veredicto-con-nonce.md)
- [ADR 0004: estados explícitos](adr/0004-estados-explicitos.md)
