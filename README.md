# Equipo IA 4.3

[![CI](https://github.com/moisesvillenam/equipo-ia/actions/workflows/ci.yml/badge.svg)](https://github.com/moisesvillenam/equipo-ia/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

**Un equipo de agentes que no toca tu repositorio: produce un parche, lo revisa y tú decides.**

Equipo IA es un orquestador en Bash para trabajar con agentes de código de forma
auditable. El agente implementa sobre una copia temporal; las pruebas se ejecutan
en tres copias (línea base, actual y control), las rutas de pruebas están
protegidas y el revisor emite un veredicto ligado a un nonce. Al final obtienes un
parche aplicable, un acta y un estado explícito: `VALIDADO`, `SIN_CAMBIOS`,
`REVISION_MANUAL` o `RECHAZADO`.

No es otro wrapper de agentes. Es una **política de validación** alrededor de
ellos.

---

## Demo en 30 segundos

No necesitas claves, red ni agentes instalados: la demo usa agentes simulados.

```bash
git clone https://github.com/moisesvillenam/equipo-ia.git
cd equipo-ia
./demo.sh
```

La demo crea un repositorio de juguete, simula un programador y un revisor,
ejecuta las pruebas de la línea base, las actuales y las del control, y muestra el
acta y el parche. Debería terminar en `VALIDADO`.

## El problema

Un agente puede:

- “arreglar” una prueba en lugar del código;
- cambiar el comando de pruebas;
- afirmar que todo pasa sin ejecutar nada;
- producir un parche que no se aplica sobre el commit real;
- leer secretos o tocar archivos que no debería.

Un `git diff` y un “he terminado” no son evidencia suficiente.

## La propuesta

1. **Solo parche.** El agente trabaja en una copia temporal. Tu árbol de trabajo
   no se modifica hasta que tú ejecutas `/aplicar`.
2. **Pruebas congeladas y línea base.** Las pruebas se ejecutan en tres copias
   desechables: la línea base (commit original sin parche), la actual (parche con
   las pruebas del agente) y el control (parche con las pruebas originales
   restauradas). Así se distingue un fallo preexistente de una regresión, y se
   detecta una prueba debilitada que el agente haya ocultado.
3. **Rutas protegidas.** Por defecto, cambios en `test.js`, `tests/*`, `*.test.js`,
   `package.json`, locks, `.github/*`, `Dockerfile`, `auth/*` o `migrations/*`
   bloquean la validación automática y pasan a revisión humana.
4. **Veredicto con nonce.** El revisor debe terminar con
   `VEREDICTO[<nonce>]: APROBADO` o `VEREDICTO[<nonce>]: CORRECCIONES`.
   El nonce se genera después del parche, así que un diff no puede falsificarlo.
5. **Acta y evidencia.** Cada ejecución guarda el parche, su SHA-256, los
   resultados de las tres tandas de pruebas, el veredicto, el nonce y un acta
   legible y otra en JSON.
6. **Estados honestos.** Si no hay pruebas, si el revisor no concluye o si se
   tocaron rutas protegidas, el resultado es `REVISION_MANUAL`; no se finge un
   `VALIDADO`.

## Cómo funciona

```text
repo limpio
   │
   ├─ git archive <commit base> ──► copia temporal
   │
   ├─ agente programador ──► cambios en la copia
   │
   ├─ parche (git diff contra la base)
   │
   ├─ pruebas de la línea base (commit original, sin parche)
   ├─ pruebas actuales (copia base + parche)
   ├─ pruebas del control (base + parche, rutas protegidas restauradas)
   ├─ rutas protegidas
   ├─ comparación de fallos contra la línea base
   ├─ revisor + nonce
   │
   └─ estado + acta + parche
          │
          └─ /aplicar (solo si VALIDADO)
```

## Requisitos

- Linux, WSL o macOS con Bash 4+ y `timeout` (en macOS: `brew install coreutils`
  y usa `gtimeout`, o define `EQUIPO_TIMEOUT_BIN`).
- Git, `tar`, `mktemp`, `sha256sum` o `shasum`.
- Para ejecuciones reales, al menos uno de:
  - [Codex CLI](https://github.com/openai/codex) (`codex`) para el modo `maximo`;
  - [OpenCode](https://opencode.ai) (`opencode`) para el modo `continuo`;
  - AGY (`agy`) como revisor. En `--print` no puede pedir permisos, así que
    recibe `--dangerously-skip-permissions` por defecto (sigue en modo plan y
    sandbox). Puedes desactivarlo con `EQUIPO_REVIEWER_SKIP_PERMISSIONS=no`.
- Node/npm, Python/pytest o R/testthat si tu proyecto usa esas pilas. También
  puedes definir `EQUIPO_TEST_CMD`.

La demo y las pruebas del repositorio **no** necesitan ninguno de esos agentes.

## Instalación

```bash
./install.sh                 # instala en ~/.local
# o:
PREFIX=/opt/equipo ./install.sh
```

Asegúrate de que `~/.local/bin` esté en `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Copia la configuración de ejemplo si quieres cambiar valores:

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/equipo-ia"
cp "${PREFIX:-$HOME/.local}/share/equipo-ia/config/equipo.conf.example" \
   "${XDG_CONFIG_HOME:-$HOME/.config}/equipo-ia/config.env"
```

## Uso

Dentro de un repositorio limpio:

```bash
cd /ruta/a/tu/repo
equipo
```

Escribe la tarea y pulsa Enter:

```text
Tú › Añade validación al formulario de registro y pruebas para el caso vacío
```

El equipo trabaja en una copia temporal. Al terminar verás el estado y la ruta
del acta. Si el estado es `VALIDADO`, puedes revisar el parche y aplicar:

```text
Tú › /diff
Tú › /aplicar
```

También puedes usar el orquestador directamente:

```bash
equipo-ia.sh "Añade validación al formulario"

equipo-ia.sh --modo continuo --intentos 2 "Corrige el bug de fechas"

equipo-ia.sh --si --npm-ci no "Tarea para automatización"
```

`--si` evita las confirmaciones interactivas. No implica autorizar `npm ci`:
si no se indica `--npm-ci si`, se omite.

### Comandos de la consola

| Comando | Qué hace |
|---|---|
| `/ayuda` | Ayuda. |
| `/chat` | Modo conversación (requiere `codex`). |
| `/desarrollar` | Vuelve al modo Equipo IA. |
| `/modo maximo\|continuo\|auto` | Cambia el modo. |
| `/estado` | Estado del repositorio. |
| `/ultimo` | Última ejecución y su acta. |
| `/revision` | Salida del revisor. |
| `/diff` | Parche propuesto. |
| `/aplicar` | Aplica el parche si está `VALIDADO` y pide `APLICAR`. |
| `/salir` | Sale. |

## Modos

| Modo | Programador | Revisor | Cuándo usarlo |
|---|---|---|---|
| `maximo` | Codex | AGY (o el configurado) | Tareas que merecen más capacidad. |
| `continuo` | OpenCode | AGY (o el configurado) | Iteración rápida. |
| `auto` | Codex si está; si no, OpenCode | AGY si está; si no, manual | Valor por defecto. No depende de la fecha. |

La segunda opinión es opcional: `--segunda-opinion` o
`EQUIPO_SECOND_OPINION=si`. Es informativa y no cambia el estado por sí sola.

## Estados y códigos de salida

| Estado | Significado | Código |
|---|---|---|
| `VALIDADO` | Parche aplicable, sin fallos nuevos respecto a la línea base (actual y control), rutas protegidas intactas y revisor aprobó. | `0` |
| `SIN_CAMBIOS` | El agente no produjo un parche. | `10` |
| `REVISION_MANUAL` | Falta información, hay rutas protegidas modificadas, pruebas no disponibles, posible prueba debilitada o veredicto no concluyente. | `20` |
| `RECHAZADO` | El programador falló, el parche no aplica o introduce fallos nuevos respecto a la línea base. | `30` |
| Error de uso/configuración | Argumentos, modo o dependencia inválidos. | `2` |

La validación es **relativa a la línea base**: si el commit original ya tenía
pruebas rojas, el parche no está obligado a arreglarlas; solo se rechazan los
fallos nuevos. La comparación se hace por nombre de prueba (TAP de Node o
`FAILED` de pytest). Si no se pueden identificar los fallos, el estado es
`REVISION_MANUAL`.

Desde 4.3.2, los errores de proceso, informes TAP incompletos y recuentos de
fallos ambiguos tampoco sirven para demostrar que no hay regresiones. Si las
pruebas siguen fallando, `/aplicar` exige esa evidencia de comparabilidad; una
ejecución anterior sin ella debe repetirse.

`REVISION_MANUAL` no significa que el parche esté mal: significa que la
herramienta no tiene evidencia suficiente para validarlo sola.

## Artefactos

Cada ejecución vive en
`${XDG_STATE_HOME:-$HOME/.local/state}/equipo-ia/ejecucion_*` con permisos `700`:

| Archivo | Contenido |
|---|---|
| `cambios.patch` | Parche binario aplicable con `git apply`. |
| `acta.md` | Acta legible: qué se verificó y qué no. |
| `acta.json` | La misma información para máquinas. |
| `estado-final.txt` | `VALIDADO`, `SIN_CAMBIOS`, `REVISION_MANUAL` o `RECHAZADO`. |
| `motivo.txt` | Explicación del estado. |
| `actual-pruebas-resultado.txt` | Resultado estructurado de las pruebas actuales. |
| `base-pruebas-resultado.txt` | Resultado del control: parche con las pruebas originales restauradas. |
| `linea-base-pruebas-resultado.txt` | Resultado de la línea base: commit original sin parche. |
| `actual-pruebas.log` | Salida completa de las pruebas actuales. |
| `base-pruebas.log` | Salida de las pruebas del control. |
| `linea-base-pruebas.log` | Salida de las pruebas de la línea base. |
| `fallos-nuevos.txt` | Fallos actuales que no estaban en la línea base (regresiones). |
| `fallos-control-nuevos.txt` | Fallos del control que no estaban en la línea base. |
| `validacion.txt` | Resumen máquina-legible que `/aplicar` vuelve a comprobar. |
| `rutas-protegidas.txt` | Rutas protegidas modificadas (vacío si no hay). |
| `revision-agy.txt` | Salida del revisor. |
| `nonce.txt`, `veredicto.txt` | Nonce y veredicto extraído. |
| `programador-ronda-*.txt` | Salida del programador por ronda. |

## Configuración

Archivo: `${XDG_CONFIG_HOME:-$HOME/.config}/equipo-ia/config.env`.
Las variables de entorno tienen prioridad sobre el archivo.

| Variable | Por defecto | Descripción |
|---|---|---|
| `EQUIPO_MODE` | `auto` | `maximo`, `continuo` o `auto`. |
| `EQUIPO_MAX_RETRIES` | `2` | Correcciones máximas (0-5). |
| `EQUIPO_TIMEOUT` | `900` | Segundos por agente. |
| `EQUIPO_TEST_TIMEOUT` | `180` | Segundos por tanda de pruebas. |
| `EQUIPO_DIFF_MAX` | `100000` | Bytes máximos del parche. |
| `EQUIPO_PROMPT_MAX` | `120000` | Bytes máximos del prompt de revisión. |
| `EQUIPO_TEST_CMD` | vacío | Comando de pruebas; si está vacío se detecta. |
| `EQUIPO_NPM_CI` | `preguntar` | `si`, `no` o `preguntar`. |
| `EQUIPO_BASE_TESTS` | `si` | Ejecutar la línea base y el control. Si es `no`, se exige que las pruebas actuales pasen. |
| `EQUIPO_PROTECTED_PATHS` | lista anterior | Glob de Bash separado por espacios. |
| `EQUIPO_PROGRAMMER` | según modo | `codex`, `opencode` o `command`. |
| `EQUIPO_REVIEWER` | `auto` | `auto`, `agy`, `command` o `none`. |
| `EQUIPO_REVIEWER_SKIP_PERMISSIONS` | `si` | Añade `--dangerously-skip-permissions` a `agy --print` (headless). |
| `EQUIPO_MODEL` | vacío | Modelo para OpenCode. |
| `EQUIPO_CODEX_MODEL` | vacío | Modelo para Codex. |
| `EQUIPO_REVIEW_MODEL` | vacío | Modelo para AGY. |

### Pruebas por pila

En proyectos Node con dependencias, usa `EQUIPO_NPM_CI=si` para que ambas
verificaciones instalen dependencias limpias. No se reutiliza el `node_modules`
del agente.

```bash
# Node
EQUIPO_TEST_CMD="npm test"

# Python
EQUIPO_TEST_CMD="python3 -m pytest -q"

# R
EQUIPO_TEST_CMD="Rscript -e 'testthat::test_dir(\"tests/testthat\")'"

# Cualquier otra cosa
EQUIPO_TEST_CMD="./scripts/verificar.sh"
```

El comando se ejecuta con `bash -c` dentro de la copia temporal. Es código
confiable: no lo construyas con entrada no confiable.

## Seguridad

- Los agentes se ejecutan con **tus permisos**. `codex --sandbox workspace-write`
  y `agy --sandbox` limitan parte del acceso, pero **no son un sandbox de
  seguridad**. Para tareas no confiables, ejecuta todo dentro de un contenedor
  o máquina virtual sin secretos.
- No hay claves en este repositorio. Los agentes usan la autenticación que ya
  tengas configurada.
- El parche es datos no confiables. El prompt del revisor se lo indica
  explícitamente, y el nonce impide que un diff falsifique el veredicto.
- Las rutas protegidas reducen el riesgo de que el agente debilite las pruebas,
  pero no sustituyen una revisión humana.
- El acta incluye lo que **no** se verificó. Léela antes de aplicar.

Más detalle: [docs/seguridad.md](docs/seguridad.md).

## Limitaciones

- No garantiza que el código sea correcto, seguro o eficiente.
- Las pruebas solo valen lo que valga tu suite.
- La copia base usa `git archive`; submodules, Git LFS y archivos generados
  pueden requerir configuración adicional.
- La detección automática de pruebas cubre npm, pytest y testthat; para otras
  pilas define `EQUIPO_TEST_CMD`.
- Un agente con acceso a la red puede consultar servicios externos. La
  herramienta no lo impide.
- No hay integración con GitHub Actions incluida; el flujo está pensado para
  ejecutarse localmente y revisar el parche antes de abrir un PR.

## Desarrollo

```bash
./demo.sh
./tests/run-tests.sh
./tests/check-secrets.sh
bash -n equipo-ia.sh equipo-pruebas.sh bin/equipo install.sh demo.sh
```

Las pruebas usan agentes simulados en `examples/fake-agents/`; no requieren red
ni claves. La CI ejecuta sintaxis, ShellCheck y las pruebas.

Estructura:

```text
equipo-ia.sh              Orquestador
equipo-pruebas.sh         Detección y ejecución de pruebas
bin/equipo                Consola interactiva
config/                   Configuración de ejemplo
examples/                 Toy repo, fixtures y agentes simulados
tests/                    Pruebas de extremo a extremo
docs/                     Arquitectura, seguridad, artefactos, adaptadores, ADRs
```

## Comparación breve

| Enfoque | Qué aporta | Qué le falta |
|---|---|---|
| Un agente + `git diff` | Velocidad. | No verifica pruebas ni evidencia. |
| CI tradicional | Verificación reproducible. | No orquesta agentes ni revisa parches. |
| Frameworks multiagente | Roles y conversación. | No suelen congelar pruebas ni producir actas aplicables. |
| **Equipo IA** | Parche + línea base + control + rutas protegidas + nonce + acta. | No es un sandbox; no sustituye la revisión humana. |

## Roadmap

- v4.4: aislamiento opcional con contenedor, más adaptadores y verificación de
  procedencia de pruebas.
- v4.5: integración con GitHub Actions y firma de actas.

## Contribuir

Lee [CONTRIBUTING.md](CONTRIBUTING.md). Para vulnerabilidades, consulta
[SECURITY.md](SECURITY.md).

## Licencia

Apache-2.0. Consulta [LICENSE](LICENSE) y [NOTICE](NOTICE).

---

English summary: [README.en.md](README.en.md).
