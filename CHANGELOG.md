# Changelog

## 4.3.0 — 2026-10-22

Primera versión pública de Equipo IA.

### Añadido

- Flujo de solo parche: el agente trabaja sobre una copia temporal y el
  repositorio original no se modifica.
- Pruebas congeladas: se aplica el parche a una copia del commit base y se
  ejecuta el comando de pruebas original.
- Rutas protegidas: cambios en pruebas, locks, CI, auth o migraciones pasan a
  `REVISION_MANUAL`.
- Veredicto del revisor con nonce generado después del parche.
- Estados `VALIDADO`, `SIN_CAMBIOS`, `REVISION_MANUAL` y `RECHAZADO`, con códigos
  de salida estables.
- Acta `acta.md` y `acta.json` con hashes, pruebas, rutas y límites.
- Modos `maximo` (Codex), `continuo` (OpenCode) y `auto` por disponibilidad.
- Consola `equipo` con `/diff`, `/revision`, `/ultimo` y `/aplicar`.
- Timeouts por agente y por pruebas.
- Segunda opinión opcional.
- Demo y pruebas de extremo a extremo con agentes simulados, sin red ni claves.
- Documentación, ADRs, CI, plantillas de issues y política de seguridad.

### Limitaciones conocidas

- No es un sandbox de seguridad.
- La detección automática cubre npm, pytest y testthat.
- No hay integración de GitHub Actions para ejecutar el flujo.
- La copia base usa `git archive`; submodules y Git LFS pueden requerir ajustes.
