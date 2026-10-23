# Equipo IA para Windows · vista previa

Esta interfaz permite abrir Equipo IA con doble clic, preparar Ubuntu, seleccionar
un proyecto, pedir un cambio, revisar el resultado, aplicarlo y guardar una versión
local. El motor sigue siendo el orquestador 4.5.0. La ventana usa Windows Forms y
Windows PowerShell 5.1; los agentes y las pruebas se ejecutan dentro de WSL.

## Estado de esta entrega

El mantenedor informó el 23 de octubre de 2026 que probó la aplicación en su
computadora Windows. No se ha documentado todavía el alcance exacto de esa prueba
ni toda la lista de aceptación. Se publica como vista previa.

Las pruebas automáticas del puente se ejecutan
en Linux con agentes simulados. El repositorio incluye un trabajo de CI para
comprobar sintaxis, transporte de argumentos y construcción de la ventana en
Windows. La instalación de WSL, el inicio de sesión real y la experiencia completa
en un PC Windows deben comprobarse con la lista de aceptación al final de esta guía.

No es un `.exe` firmado ni un producto de OpenAI. La instalación de la aplicación
no incluye cuentas de IA. Cada persona conecta sus propias cuentas.

## Requisitos

- Windows 11 o una versión de Windows 10 compatible con WSL; conexión a Internet
  para instalar Ubuntu, herramientas y agentes.
- Windows PowerShell 5.1 y Windows Forms, incluidos en las instalaciones habituales
  de Windows de escritorio.
- Permiso de administrador para habilitar WSL si todavía no está instalado. La
  aplicación y Codex se ejecutan con el usuario habitual, no como administrador.
- Ubuntu en WSL. El asistente de paquetes también admite Debian; la instalación
  guiada inicial utiliza Ubuntu.
- Una cuenta y acceso válido al agente para tareas reales. La demo no necesita
  cuenta ni claves.

## Instalar y abrir

1. Extrae **toda** la carpeta del ZIP en una carpeta local de Windows.
2. Abre `windows/Instalar Equipo IA.cmd` con doble clic.
3. Acepta copiar la aplicación a `%LOCALAPPDATA%\Programs\EquipoIA` y crear el
   acceso directo del escritorio. Esta copia no instala WSL ni los agentes.
4. Abre **Equipo IA** desde el escritorio.

También puedes ejecutar `windows/Abrir Equipo IA.cmd` desde la carpeta extraída.
No abras el lanzador dentro del visor del ZIP. La aplicación necesita los archivos
que lo acompañan. Los lanzadores usan una política de ejecución limitada a ese
proceso; no cambian permanentemente la política de PowerShell. Las políticas de
una organización pueden impedir ejecutar scripts; en ese caso consulta a su
administrador, sin desactivar sus controles.

## Preparación, paso a paso

### A. Ubuntu y herramientas

1. **Instalar Ubuntu**: solicita a Windows instalar WSL y Ubuntu. Aparecerá el
   permiso de administrador de Windows; puede requerirse un reinicio.
2. **Abrir Ubuntu**: completa la creación de tu usuario y contraseña si es el
   primer inicio. Esa contraseña es de Ubuntu y no se entrega a Equipo IA.
3. **Buscar Ubuntu instalado**: selecciona la distribución donde trabajarás.
4. **Preparar herramientas**: instala Git, Python, Node, npm, curl, certificados
   y utilidades mediante los paquetes de la distribución. Se abre una ventana
   visible para seguir el proceso; el botón pide confirmación antes de instalar.
5. **Comprobar**: muestra qué está listo y qué falta.

Si ya tienes varias distribuciones, usa siempre la misma para el proyecto y los
agentes. Puedes escribir su nombre en el selector. La aplicación no cambia tu
distribución predeterminada de WSL.

### B. Tu cuenta de IA

1. **Instalar Codex**: descarga y ejecuta el instalador oficial de Codex para Linux
   desde `https://chatgpt.com/codex/install.sh`, dentro de Ubuntu, tras confirmar.
2. **Conectar mi cuenta**: ejecuta `codex login`; completa el flujo oficial en el
   navegador. La ventana de conexión permanece abierta hasta que pulses Enter.
3. Si el navegador no logra completar la conexión, **Conectar con código** utiliza
   `codex login --device-auth`. La cuenta o el administrador deben permitir ese
   tipo de acceso.
4. Regresa a **Comprobar**. La aplicación consulta `codex login status` y muestra
   el estado, sin leer ni devolver los archivos de credenciales.

La opción predeterminada utiliza Codex en dos sesiones distintas: programador y
revisor. El revisor recibe el contrato del motor y trabaja con sandbox de solo
lectura. Esto no implica diversidad de modelos ni una garantía de independencia.
También puedes seleccionar OpenCode para programar y AGY para revisar si ya están
instalados y autenticados en la misma distribución. No se automatizan sus
instalaciones en esta entrega.

## Probar sin cuenta

En **Proyecto y tarea**, pulsa **Probar ejemplo sin cuenta**. La aplicación crea un
proyecto de saludo con Git y pruebas, y usa agentes simulados. Verás el parche y
el acta en **Resultados**. La etiqueta **EJEMPLO SIMULADO** distingue ese flujo de
una ejecución con IA real.

Puedes practicar **Aplicar esta propuesta** y **Guardar versión local** sobre ese
proyecto de ejemplo. El historial y el proyecto de práctica se conservan dentro
de Ubuntu. No son los temporales de `demo.sh`, que se eliminan al terminar.

## Usar IA real

1. Elige una carpeta con un repositorio Git existente o pulsa **Crear proyecto de
   práctica**. También puedes escribir una ruta Linux como `~/proyecto`.
2. Pulsa **Revisar proyecto**. Debe tener un commit y no tener cambios pendientes.
3. Describe el comportamiento actual y el deseado. Para la práctica se completa
   automáticamente una petición de corregir el saludo.
4. Elige programador y revisor. Marca la instalación de dependencias npm solo si
   la necesitas y confías en el proyecto. Para otras pilas, prepara sus herramientas
   y pruebas dentro de Ubuntu antes de comenzar.
5. Pulsa **Preparar mejora con IA** y acepta la ejecución con tu cuenta. Espera
   el resultado; puedes consultar el registro sin bloquear la ventana.
6. Lee **Cambios**, **Revisión** e **Informe completo**. Solo una propuesta
   `VALIDADO` y sin alteraciones permite **Aplicar esta propuesta**.
7. Confirma la aplicación. El motor vuelve a comprobar el estado, las pruebas
   registradas, el nonce, las rutas protegidas, el commit, la limpieza y la
   aplicabilidad. No se omiten sus comprobaciones.
8. Si aceptas los cambios aplicados, **Guardar versión local** crea un commit con
   los archivos de esa propuesta. No hace push ni publica nada. Si no hay identidad
   Git configurada, usa `Equipo IA <equipo-ia@localhost>` solo en ese commit, sin
   modificar la configuración global. Si hubo ediciones adicionales, se detiene
   para evitar incluirlas automáticamente.

La aplicación no inicializa Git sobre una carpeta arbitraria ni guarda todo su
contenido automáticamente. Para un proyecto real sin historial o con cambios
previos, primero hay que revisar qué archivos deberían incluirse. El proyecto de
práctica permite empezar sin ese trabajo previo.

## Resultados y tareas en curso

- **Propuesta lista para revisar**: estado `VALIDADO`; todavía requiere tu decisión.
- **Hace falta una revisión humana**: se tocó una ruta protegida o falta evidencia.
- **La propuesta no superó los controles**: el motor rechazó el cambio.
- **No se propusieron cambios**: no hay parche que aplicar.
- **No se pudo completar la tarea**: revisa el registro, herramientas o conexión.

Solo se ejecuta o aplica una tarea a la vez por usuario/distribución desde esta
interfaz. Un bloqueo mantenido por el proceso de trabajo evita ejecuciones
simultáneas desde varias ventanas. Puedes cerrar la ventana mientras trabaja: el
proceso sigue en Ubuntu y se recupera desde **Historial**. No hay un botón de
cancelación en esta entrega; si se reinicia Windows/WSL, una tarea interrumpida se
muestra como error y requiere una nueva ejecución.

El guardado de versiones evita incluir trabajo adicional, pero no reemplaza una
revisión del contenido. Los hooks de Git del proyecto pueden ejecutar código al
crear un commit, como en el uso habitual de Git.

## Archivos, configuración y límites

- Preferencias de la ventana: `%LOCALAPPDATA%\EquipoIA\preferencias.json`.
- Historial y proyectos de práctica: `~/.local/state/equipo-ia-desktop` dentro de
  Ubuntu, o bajo `XDG_STATE_HOME` si está configurado.
- `EQUIPO_DESKTOP_STATE` permite aislar el directorio de estado para desarrollo y
  pruebas; la ventana normal no necesita configurarlo.
- La interfaz usa una configuración propia: mantiene activas línea base y control,
  las rutas protegidas predeterminadas y dos intentos de corrección. No hereda
  opciones `EQUIPO_*` que puedan relajar esos controles. No ofrece todavía edición
  gráfica de comandos de pruebas personalizados ni de modelos.
- Los agentes, las pruebas, las instalaciones npm y los hooks usan los permisos
  del usuario o los necesarios para preparar paquetes. La copia temporal no es
  un aislamiento completo; usa proyectos de confianza.
- El botón de Git solo crea versiones locales; no hace clone de proyectos reales,
  push, pull, cambios de rama ni resolución de conflictos.
- Al aplicar se compara además la huella del parche con la guardada al finalizar.
  Esta comprobación no es una firma digital ni protege frente a alguien que controle
  todos los archivos del usuario.

## Desinstalar

Cierra Equipo IA, elimina su acceso directo y la carpeta
`%LOCALAPPDATA%\Programs\EquipoIA`. Esto conserva Ubuntu, agentes, credenciales,
proyectos y resultados. Si quieres borrar el historial o las preferencias, revisa
primero las carpetas indicadas arriba: allí pueden estar tus proyectos de práctica.
No hace falta desinstalar WSL para dejar de usar la aplicación.

## Desarrollo y empaquetado

```bash
python3 -m unittest discover -s desktop -p 'test_*.py' -v
python3 desktop/package_windows.py
```

El ZIP se genera en `dist/Equipo-IA-Windows-v4.5.0.zip`. Incluye fuentes explícitas,
la licencia y un archivo de inicio. Excluye `.git`, cachés y archivos de estado.
Convierte los scripts de Windows a CRLF y PowerShell a UTF-8 con BOM para conservar
el español en Windows PowerShell 5.1.

En Windows, con Python disponible para las pruebas:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File windows\Test-Desktop.ps1
```

### Aceptación manual antes de distribuir como estable

1. Extraer e instalar en una ruta con espacios y caracteres españoles; abrir el
   acceso directo como usuario normal.
2. Instalar WSL desde un Windows limpio, reiniciar si se solicita, crear usuario
   Ubuntu y completar herramientas.
3. Conectar una cuenta real de Codex y comprobar su estado. Verificar el flujo
   alternativo de código cuando la cuenta lo permita.
4. Ejecutar el ejemplo simulado, revisar, aplicar y guardar. Reabrir el historial.
5. Ejecutar una tarea real acotada en el proyecto de práctica y revisar su acta.
6. Probar carpeta Windows, carpeta Linux y carpeta UNC de la misma distribución.
7. Confirmar que un árbol sucio, parche alterado, base cambiada o estado manual
   impiden aplicar. Confirmar que una edición adicional impide guardar.
8. Cerrar la ventana durante una tarea y recuperarla desde Historial.
9. Verificar escalado de pantalla al 125 % y 150 %, navegación con teclado y
   lectura de textos largos.

## Fuentes de instalación y conexión

- [Instalar WSL — Microsoft](https://learn.microsoft.com/es-es/windows/wsl/install).
- [Comandos de WSL — Microsoft](https://learn.microsoft.com/es-es/windows/wsl/basic-commands).
- [Codex CLI — documentación oficial](https://learn.chatgpt.com/docs/codex/cli).
- [Autenticación — documentación oficial](https://learn.chatgpt.com/docs/auth).
