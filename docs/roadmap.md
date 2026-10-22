# Roadmap

## v4.4

- Aislamiento opcional con contenedor (Podman/Docker) y red desactivada.
- Adaptadores declarativos para más agentes.
- Detección de procedencia de pruebas: hash del comando y de los archivos de
  pruebas en el acta.
- Soporte para `uv`, Poetry y Cargo en la detección automática.
- Pruebas de integración con repositorios reales, sin agentes reales.

## v4.5

- Acción de GitHub que ejecute el equipo en un PR y publique el acta.
- Firma del acta y verificación de la cadena de ejecución.
- Comparación de parches entre modelos.
- Interfaz web mínima para revisar actas.

## Ideas

- Presupuesto de tokens y coste por ejecución.
- Política de rutas protegidas por lenguaje.
- Revisión de accesibilidad y rendimiento como etapas opcionales.
- Exportación a SARIF.
- Modo “solo revisión” para auditar un parche existente.

Las propuestas deben mantener la idea central: evidencia verificable, estados
honestos y decisión humana.
