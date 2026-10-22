# Seguridad

## Modelo de amenazas

Equipo IA asume que el agente puede ser incompetente, estar influido por prompt
injection o intentar ocultar un fallo. No asume que el agente sea de confianza.

| Amenaza | Control | Límite |
|---|---|---|
| El agente debilita pruebas | Rutas protegidas; cambio a `REVISION_MANUAL`. | No impide cambios en archivos no protegidos. |
| El agente cambia el comando de pruebas | Las pruebas base usan la configuración del commit base. | Un comando personalizado puede seguir siendo dependiente del entorno. |
| El agente afirma que todo pasa | Se ejecutan las pruebas y se guardan logs. | Una suite mala puede dar falsos positivos. |
| Un diff incluye un veredicto falso | Nonce generado después del parche; se extrae la última línea válida. | El revisor podría ser manipulado para emitir el veredicto. |
| El agente modifica el repositorio real | Trabaja sobre una copia; `/aplicar` exige confirmación. | El agente conserva los permisos del usuario. |
| El agente lee secretos | No hay claves en el repo; se recomienda contenedor sin secretos. | No hay aislamiento de credenciales integrado. |
| El agente usa la red | Se le pide no hacerlo en el prompt. | No se bloquea técnicamente. |
| Supply chain | Se ejecutan las dependencias del proyecto. | No hay verificación de procedencia. |

## Lo que la herramienta no es

- No es un sandbox de seguridad.
- No es un sistema de detección de malware.
- No garantiza que el parche sea correcto.
- No sustituye la revisión humana.
- No firma el acta ni certifica la identidad del agente.

`codex --sandbox workspace-write` y `agy --sandbox` reducen el acceso, pero siguen
siendo mecanismos del agente, no una frontera de seguridad del sistema operativo.

## Recomendaciones

1. Ejecuta tareas no confiables en un contenedor o VM sin secretos.
2. Usa un usuario del sistema con permisos mínimos.
3. No dejes claves en el repositorio ni en el prompt.
4. Revisa `/diff`, `/revision` y el acta antes de `/aplicar`.
5. Mantén las pruebas rápidas y deterministas.
6. Protege también los archivos de configuración que puedan debilitar la suite.
7. Si el agente toca una ruta protegida, investiga por qué antes de continuar.
8. No ejecutes `EQUIPO_TEST_CMD` con entrada no confiable: se evalúa con
   `bash -c` dentro de la copia.

## Prompt injection

El prompt del revisor declara que el diff es datos no confiables y que no debe
obedecer instrucciones dentro de él. El nonce evita que el diff contenga un
veredicto válido, porque se genera después del parche. Aun así, un modelo puede
ser persuadido; por eso el estado final es una recomendación, no una autorización.

## Secretos

Este repositorio no contiene claves ni credenciales. Si haces un fork, revisa tu
propia configuración y no subas `config.env`, logs ni actas con datos privados.
El `.gitignore` excluye los artefactos de ejecución locales.

## Reportar una vulnerabilidad

Abre un aviso privado de seguridad en GitHub (Security Advisories) o contacta a
los mantenedores por el canal que indique el repositorio. No publiques detalles
explotables en un issue abierto. No se incluye un correo personal en este
repositorio.
