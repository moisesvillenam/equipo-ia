# ADR 0002: parche contra el commit base, no contra el árbol del agente

## Contexto

Si el agente hace commits, resets o deja cambios mezclados, un `git diff` contra
su estado puede no representar el cambio que se quiere aplicar. El usuario
necesita un artefacto que se pueda comprobar y aplicar sobre su commit real.

## Decisión

El agente trabaja en una copia creada con `git archive <BASE_SHA>`. El parche se
genera con `git diff --cached --binary <WORK_BASE>` después de `git add -A`. El
parche se valida con `git apply --check` sobre el repositorio original.

## Consecuencias

- El parche es independiente de los commits internos del agente.
- El repositorio original permanece intacto hasta `/aplicar`.
- El parche puede incluir archivos nuevos, borrados y binarios.
- Si el agente daña `.git` en la copia, no se puede generar el parche y el estado
  es `RECHAZADO`.
- Los archivos ignorados por `.gitignore` no forman parte del parche; se
  documenta como limitación.
