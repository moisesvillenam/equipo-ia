# Artefactos de una ejecución

Cada ejecución crea un directorio con permisos `700`:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/equipo-ia/ejecucion_YYYYMMDD_HHMMSS_XXXXXX/
```

## Archivos

| Archivo | Descripción |
|---|---|
| `acta.md` | Acta legible para humanos. |
| `acta.json` | Acta para máquinas; esquema `equipo-ia/acta/v1`. |
| `cambios.patch` | Parche binario generado con `git diff --binary`. |
| `estado-final.txt` | Estado final. |
| `motivo.txt` | Explicación del estado. |
| `tarea.txt` | Tarea original. |
| `modo.txt` | Modo usado. |
| `origen.txt` | Ruta del repositorio original. |
| `commit-origen.txt` | SHA del commit base. |
| `commit-workcopy.txt` | SHA del commit inicial de la copia. |
| `programador.txt`, `revisor.txt` | Adaptadores usados. |
| `programador-ronda-N.txt` | Salida del programador en la ronda N. |
| `programador-ronda-N.txt.status` | Código de salida del programador. |
| `prompt-*.txt` | Prompts enviados. |
| `pruebas-resultado.txt` | Resultado de las pruebas actuales (copia de compatibilidad). |
| `actual-pruebas-resultado.txt` | Resultado estructurado de las pruebas actuales. |
| `actual-pruebas.log` | Log de las pruebas actuales. |
| `base-pruebas-resultado.txt` | Resultado del control: parche con las pruebas originales restauradas. |
| `base-pruebas.log` | Log del control. |
| `linea-base-pruebas-resultado.txt` | Resultado de la línea base: commit original sin parche. |
| `linea-base-pruebas.log` | Log de la línea base. |
| `fallos-actual.txt`, `fallos-base.txt`, `fallos-linea-base.txt` | Nombres de pruebas fallidas extraídos de cada log. |
| `fallos-nuevos.txt` | Fallos actuales que no estaban en la línea base. |
| `fallos-control-nuevos.txt` | Fallos del control que no estaban en la línea base. |
| `fallos-corregidos.txt` | Fallos de la línea base que el parche deja de reproducir. |
| `validacion.txt` | Resumen que `/aplicar` recompueba (regresiones, control, prueba debilitada). |
| `actual-ronda-N/` | Copia desechable del commit base + parche usada para las pruebas actuales. |
| `linea-base-ronda-N/` | Copia desechable del commit original, sin parche. |
| `verificacion-ronda-N/` | Copia del commit base + parche con las rutas protegidas restauradas (control). |
| `revisor-dir/` | Directorio aislado donde se ejecuta el revisor. |
| `segunda-opinion-dir/` | Directorio aislado donde se ejecuta la segunda opinión. |
| `archivos-cambiados.txt` | Rutas modificadas por el agente. |
| `rutas-protegidas.txt` | Subconjunto protegido de esas rutas. |
| `nonce.txt` | Nonce del veredicto. |
| `revision-agy.txt` | Salida completa del revisor. |
| `veredicto.txt` | `APROBADO`, `CORRECCIONES` o `INDETERMINADO`. |
| `segunda-opinion.txt` | Salida de la segunda opinión, si se pidió. |

## Formato de resultados de pruebas

`actual-pruebas-resultado.txt`, `base-pruebas-resultado.txt` y
`linea-base-pruebas-resultado.txt` usan líneas `CLAVE=VALOR`:

```text
ESTADO=APROBADO
COMANDO=npm test
CODIGO=0
DURACION=2s
MOTIVO=Las pruebas pasaron.
```

`ESTADO` puede ser `APROBADO`, `FALLIDO`, `REVISION_MANUAL` u `OMITIDO`.

## Acta JSON

Campos principales:

```json
{
  "schema": "equipo-ia/acta/v1",
  "version": "4.3.1",
  "run": "/ruta/ejecucion_...",
  "timestamp": "2026-01-01T00:00:00Z",
  "project": "/ruta/repo",
  "base_commit": "abc123",
  "task": "…",
  "mode": "maximo",
  "programmer": "codex",
  "reviewer": "agy",
  "patch_sha256": "…",
  "patch_bytes": 123,
  "changed_files": ["index.js"],
  "protected_paths": [],
  "baseline_tests": "ESTADO=APROBADO",
  "current_tests": "ESTADO=APROBADO",
  "control_tests": "ESTADO=APROBADO",
  "baseline": "verde",
  "baseline_failures": [],
  "control_failures": [],
  "new_failures": [],
  "control_new_failures": [],
  "fixed_failures": [],
  "weakened_test": 0,
  "verdict": "APROBADO",
  "nonce": "…",
  "state": "VALIDADO",
  "reason": "…"
}
```

## Cómo inspeccionar

```bash
equipo                 # consola
# o directamente:
less "$(ls -1dt ~/.local/state/equipo-ia/ejecucion_* | head -1)/acta.md"
git apply --check /ruta/ejecucion_.../cambios.patch
```

No apliques un parche solo porque el estado sea `VALIDADO`: lee el acta y el
diff. El estado indica que se cumplieron las comprobaciones automáticas, no que
el cambio sea deseable.
