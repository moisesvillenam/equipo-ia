# ADR 0006: interfaz local de Windows sobre el motor existente

## Contexto

La consola exige conocer terminal, Git y la configuración de los agentes. Se
necesita un acceso gráfico para preparar el entorno, ejecutar una tarea y decidir
sobre su resultado, manteniendo el contrato de validación del orquestador.

## Decisión

- Windows Forms y PowerShell 5.1 para una ventana sin runtime descargado adicional.
- WSL/Ubuntu conserva el entorno Bash del motor; se guía su preparación desde
  botones explícitos. El instalador por usuario solo copia la aplicación.
- Un puente Python de biblioteca estándar recibe peticiones JSON codificadas en
  base64 por argumentos. No hay servidor HTTP, puertos ni sesión pública.
- Las peticiones y rutas se transmiten como argumentos separados, no como código
  evaluado. La ventana solo expone acciones conocidas.
- Cada tarea tiene estado, log y carpeta de ejecuciones propios. Un bloqueo del
  sistema se hereda al proceso que trabaja para impedir operaciones simultáneas.
- Aplicar reutiliza `bin/equipo` con la carpeta exacta de esa tarea y su confirmación
  explícita. Antes compara la huella del parche que vio el usuario. La consola
  conserva la decisión final sobre sus invariantes.
- Guardar un commit es una acción posterior y separada. Solo incluye los archivos
  de la propuesta si el árbol coincide con el estado capturado después de aplicar.
- Codex puede ser revisor mediante el adaptador `command` existente, en una sesión
  de solo lectura y con el mismo contrato de nonce. AGY sigue disponible.
- La interfaz usa su propia configuración conservadora y no hereda overrides del
  motor que desactiven sus controles. La consola existente no cambia.

## Consecuencias

La política del motor no se relaja y la consola sigue funcionando como antes.
La interfaz requiere comprobarse en Windows además de los tests Linux del puente.
PowerShell no proporciona un instalador firmado; la entrega inicial es un ZIP de
vista previa. Configurar WSL, acceder a los agentes y preparar pruebas de proyectos
reales sigue siendo necesario, aunque el flujo habitual ya no exige teclear
comandos. Codex en dos roles no implica diversidad ni independencia de modelos.

No se incluye administración de conflictos, inicialización masiva de Git, servicio
de IA compartido, edición gráfica de todas las opciones ni aislamiento adicional.
