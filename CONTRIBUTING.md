# Contribuir

Gracias por querer mejorar Equipo IA. El proyecto prioriza claridad, evidencia y
seguridad sobre funciones llamativas.

## Preparación

```bash
git clone https://github.com/<tu-usuario>/equipo-ia.git
cd equipo-ia
./demo.sh
./tests/run-tests.sh
```

No necesitas claves ni agentes reales para las pruebas: se usan los simulados de
`examples/fake-agents/`.

## Comprobaciones antes de un PR

```bash
bash -n equipo-ia.sh equipo-pruebas.sh equipo-publicar.sh bin/equipo install.sh demo.sh tests/run-tests.sh
shellcheck -S error equipo-ia.sh equipo-pruebas.sh equipo-publicar.sh bin/equipo install.sh demo.sh tests/run-tests.sh
./tests/run-tests.sh
python3 -m unittest discover -s tests -p 'test_*.py' -v
./tests/check-secrets.sh
./demo.sh
```

Para cambios en la interfaz Windows, ejecuta además:

```bash
python3 -m unittest discover -s desktop -p 'test_*.py' -v
bash -n desktop/setup.sh desktop/revisor-codex.sh
shellcheck -S error desktop/setup.sh desktop/revisor-codex.sh
python3 desktop/package_windows.py
```

En Windows, `windows/Test-Desktop.ps1` comprueba sintaxis, argumentos y construcción
de la ventana; requiere Python para la prueba de transporte. La aceptación completa
de WSL y cuentas reales está descrita en [docs/windows.md](docs/windows.md).

Si no tienes ShellCheck, instálalo con el gestor de tu sistema. En CI se ejecuta
con severidad `error`.

## Estilo

- Bash compatible con 4.3+; evita dependencias que no estén documentadas.
- Comillas alrededor de variables; `local` en funciones.
- Mensajes de usuario en español; nombres de variables y funciones en español
  cuando sea natural.
- No introduzcas rutas absolutas, correos personales, claves ni nombres de
  repositorios privados.
- Mantén el flujo principal legible: una función por responsabilidad.
- Añade una prueba de extremo a extremo para cada cambio de comportamiento.

## Añadir un adaptador

1. Decide si puede resolverse con `EQUIPO_PROGRAMMER_CMD` o
   `EQUIPO_REVIEWER_CMD`.
2. Si necesita un integrado, añade la rama en `run_agent` y documenta el contrato.
3. Añade un fake en `examples/fake-agents/` y una prueba.
4. Actualiza `docs/adaptadores.md` y `config/equipo.conf.example`.

## Cambios en la política de validación

Los cambios en pruebas congeladas, rutas protegidas, nonce o estados requieren:

- un ADR en `docs/adr/`;
- una prueba que demuestre el nuevo comportamiento;
- una nota en `CHANGELOG.md`.

No relajes una comprobación para que pase una prueba; arregla la causa.

## Commits

Mensajes en imperativo y con alcance, por ejemplo:

```text
orquestador: no validar si el revisor no concluye
docs: explicar el nonce del revisor
tests: cubrir rutas protegidas anidadas
```

No incluyas credenciales, rutas locales ni datos de terceros. Si haces un fork,
configura un correo noreply de GitHub.

## Licencia de las contribuciones

Al enviar un PR aceptas que tu contribución se publique bajo Apache-2.0.
