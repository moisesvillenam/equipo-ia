# Configuración

Archivo por defecto:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/equipo-ia/config.env
```

Copia `config/equipo.conf.example`. Las variables de entorno tienen prioridad
sobre el archivo. Los argumentos de línea de comandos tienen prioridad sobre
ambos.

El archivo se lee como `CLAVE=valor`; no se ejecuta como script. Se admiten
comillas simples o dobles alrededor del valor y comentarios con `#` al inicio de
la línea.

## Variables

| Variable | Por defecto | Valores |
|---|---|---|
| `EQUIPO_MODE` | `auto` | `maximo`, `continuo`, `auto` |
| `EQUIPO_MAX_RETRIES` | `2` | `0`–`5` |
| `EQUIPO_TIMEOUT` | `900` | segundos por agente |
| `EQUIPO_TEST_TIMEOUT` | `180` | segundos por tanda |
| `EQUIPO_DIFF_MAX` | `100000` | bytes |
| `EQUIPO_PROMPT_MAX` | `120000` | bytes |
| `EQUIPO_TEST_CMD` | vacío | comando de shell |
| `EQUIPO_NPM_CI` | `preguntar` | `si`, `no`, `preguntar` |
| `EQUIPO_BASE_TESTS` | `si` | `si`, `no` (si es `no`, se exigen pruebas actuales verdes) |
| `EQUIPO_PROTECTED_PATHS` | lista | globs de Bash separados por espacios |
| `EQUIPO_PROGRAMMER` | según modo | `codex`, `opencode`, `command` |
| `EQUIPO_PROGRAMMER_CMD` | vacío | comando para `command` |
| `EQUIPO_REVIEWER` | `auto` | `auto`, `agy`, `command`, `none` |
| `EQUIPO_REVIEWER_CMD` | vacío | comando para `command` |
| `EQUIPO_REVIEWER_SKIP_PERMISSIONS` | `si` | `si`, `no` (solo AGY en `--print`) |
| `EQUIPO_MODEL` | vacío | modelo de OpenCode |
| `EQUIPO_CODEX_MODEL` | vacío | modelo de Codex |
| `EQUIPO_REVIEW_MODEL` | vacío | modelo de AGY |
| `EQUIPO_SECOND_OPINION` | `no` | `si`, `no` |
| `EQUIPO_SECOND_OPINION_CMD` | vacío | comando de segunda opinión |
| `EQUIPO_STATE_DIR` | `~/.local/state/equipo-ia` | directorio de ejecuciones |
| `EQUIPO_CONFIG` | `~/.config/equipo-ia/config.env` | archivo de configuración |
| `EQUIPO_TIMEOUT_BIN` | `timeout` o `gtimeout` | binario de timeout |

## Pruebas

### Node

Si `package.json` tiene un script `test` real, se usa `npm test`. Si hay
`package-lock.json`, `EQUIPO_NPM_CI=si` ejecuta `npm ci` antes de las pruebas.
`preguntar` pide autorización; `no` omite la instalación. En proyectos con
dependencias, se recomienda `si` para las tres copias de pruebas: no se reutiliza
`node_modules` del agente, para no validar con dependencias que él haya podido
modificar.

### Python

Se usa `python3 -m pytest -q` si existe `pyproject.toml`, `pytest.ini` o una
carpeta `tests/` y pytest está instalado. Para proyectos con `uv`, poetry o un
entorno virtual, define el comando:

```bash
EQUIPO_TEST_CMD="uv run pytest -q"
```

### R

Se usa `testthat::test_dir("tests/testthat")` si hay `DESCRIPTION` y testthat.
Para `R CMD check` u otra variante:

```bash
EQUIPO_TEST_CMD="R CMD check --no-manual ."
```

### Otros

```bash
EQUIPO_TEST_CMD="./scripts/verificar.sh"
EQUIPO_TEST_CMD="make test"
EQUIPO_TEST_CMD="cargo test"
EQUIPO_TEST_CMD="go test ./..."
```

El comando se ejecuta con `bash -c` en la copia temporal. Es código confiable;
no lo construyas con entrada no confiable.

## Rutas protegidas

Valor por defecto:

```text
tests/* test/* spec/* __tests__/* test test.js */test.js spec.js */spec.js
*.test.js *.spec.js *.test.ts *.spec.ts *.test.tsx *.spec.tsx pytest.ini tox.ini
jest.config.* vitest.config.* playwright.config.* package.json package-lock.json
pnpm-lock.yaml yarn.lock .github/* Dockerfile docker-compose* auth/* migrations/*
```

En `case` de Bash, `*` también cruza `/`. Puedes añadir rutas:

```bash
EQUIPO_PROTECTED_PATHS="$EQUIPO_PROTECTED_PATHS src/config/*"
```

Un cambio en una ruta protegida no rechaza el parche automáticamente: lo pasa a
`REVISION_MANUAL` para que una persona decida.

## Pruebas de referencia

Con `EQUIPO_BASE_TESTS=si` (por defecto) se ejecutan tres tandas: línea base
(commit original sin parche), actual (parche) y control (parche con las pruebas
originales). La comparación se hace por nombre de prueba y solo bloquean los
fallos nuevos. Si no se pueden identificar los nombres, el estado es
`REVISION_MANUAL`.

Con `EQUIPO_BASE_TESTS=no` se omiten la línea base y el control: las pruebas
actuales deben pasar para validar. Es más rápido, pero no distingue fallos
preexistentes ni detecta pruebas debilitadas.

## Revisor AGY en modo headless

`agy --print` no puede abrir un diálogo de permisos: cualquier comando requerido
se deniega y el revisor termina sin veredicto. Por eso, con
`EQUIPO_REVIEWER_SKIP_PERMISSIONS=si` (por defecto) se añade
`--dangerously-skip-permissions`. El revisor sigue ejecutándose con
`--mode plan --sandbox` (solo lectura). Si prefieres no usarlo, ponlo en `no` y
configura las reglas de permisos de AGY, o usa un revisor propio.

## Ejemplos de configuración

### Codex + AGY, con npm ci permitido

```bash
EQUIPO_MODE=maximo
EQUIPO_REVIEWER=agy
EQUIPO_NPM_CI=si
EQUIPO_BASE_TESTS=si
```

### OpenCode + AGY, sin instalar dependencias

```bash
EQUIPO_MODE=continuo
EQUIPO_MODEL=opencode/deepseek-v4.1-flash-free
EQUIPO_REVIEWER=agy
EQUIPO_NPM_CI=no
```

### Sin revisor externo

```bash
EQUIPO_REVIEWER=none
```

El resultado será `REVISION_MANUAL` aunque las pruebas pasen. Es útil para
generar un parche y revisarlo a mano.

### Revisor propio

```bash
EQUIPO_REVIEWER=command
EQUIPO_REVIEWER_CMD='./scripts/revisor.sh "$EQUIPO_PROMPT_FILE"'
```

Más detalles en [adaptadores.md](adaptadores.md).
