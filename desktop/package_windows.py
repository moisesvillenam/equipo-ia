#!/usr/bin/env python3
"""Crear un ZIP portable desde fuentes explícitas; no incluye .git ni credenciales."""
from pathlib import Path
import argparse
import zipfile

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path, default=ROOT / "dist/Equipo-IA-Windows-v4.5.1.zip")
args = parser.parse_args()
args.output.parent.mkdir(parents=True, exist_ok=True)
directories = ["windows", "desktop", "bin", "examples", "config", "docs"]
files = [ROOT / name for name in ["equipo-ia.sh", "equipo-pruebas.sh", "equipo-publicar.sh", "demo.sh", "install.sh", "README.md", "LICENSE", "NOTICE"]]
for directory in directories:
    files.extend(path for path in (ROOT / directory).rglob("*")
                 if path.is_file() and "__pycache__" not in path.parts and path.suffix not in {".pyc", ".log"})
with zipfile.ZipFile(args.output, "w", zipfile.ZIP_DEFLATED) as package:
    for path in sorted(files):
        relative = path.relative_to(ROOT)
        data = path.read_bytes()
        if path.suffix in {".ps1", ".cmd"}:
            text = data.decode("utf-8-sig").replace("\r\n", "\n").replace("\n", "\r\n")
            data = text.encode("utf-8-sig" if path.suffix == ".ps1" else "utf-8")
        item = zipfile.ZipInfo.from_file(path, arcname="Equipo-IA/" + relative.as_posix())
        item.compress_type = zipfile.ZIP_DEFLATED
        package.writestr(item, data)
    package.writestr("Equipo-IA/EMPIEZA-AQUI.txt", """EQUIPO IA 4.5.1 PARA WINDOWS - VISTA PREVIA

1. Extrae toda la carpeta Equipo-IA del ZIP a una carpeta local.
2. Abre windows y haz doble clic en Instalar Equipo IA.cmd.
3. Abre el acceso directo Equipo IA del escritorio.
4. Sigue Preparacion: Ubuntu, herramientas y tu cuenta de Codex.
5. En Proyecto y tarea puedes probar un ejemplo simulado sin cuenta.

Tambien puedes abrir windows/Abrir Equipo IA.cmd sin instalar la aplicacion.
No ejecutes los archivos desde el visor del ZIP: extrae la carpeta completa.

Consulta docs/windows.md para requisitos, uso real, limites y desinstalacion.
Esta distribucion es una vista previa. No es un instalador .exe firmado.
""")
print(args.output.resolve())
