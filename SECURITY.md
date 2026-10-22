# Seguridad

## Versiones soportadas

La rama `main` y la última versión publicada reciben correcciones de seguridad.

## Reportar una vulnerabilidad

Usa **GitHub Security Advisories** del repositorio. Si no está disponible, abre
un issue mínimo pidiendo un canal privado; no publiques detalles explotables,
credenciales ni datos de terceros.

Incluye, si puedes:

- versión de Equipo IA y sistema operativo;
- modo y adaptadores;
- pasos para reproducir;
- impacto esperado;
- un acta o log **saneado**.

No se incluye un correo personal en este repositorio.

## Alcance

Entran en alcance:

- ejecución de comandos no intencionada desde un diff o un prompt;
- falsificación del veredicto sin conocer el nonce;
- escritura fuera de la copia temporal;
- aplicación de un parche sin cumplir las comprobaciones de `/aplicar`;
- exposición de secretos por parte de la propia herramienta.

Quedan fuera de alcance:

- vulnerabilidades del proyecto sobre el que se ejecuta;
- comportamiento malicioso de un agente que ya tiene los permisos del usuario;
- falta de aislamiento de red o de credenciales (documentada como limitación);
- calidad o corrección del código generado.

## Modelo de seguridad

Consulta [docs/seguridad.md](docs/seguridad.md). En resumen: los agentes se
ejecutan con tus permisos, el sandbox de los agentes no es una frontera de
seguridad y la decisión final es humana.
