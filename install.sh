#!/usr/bin/env bash
# Instala Equipo IA en ~/.local (o PREFIX) sin tocar el repositorio del usuario.
# Copyright 2026 The Equipo IA Authors. SPDX-License-Identifier: Apache-2.0
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"

while (($#)); do
  case "$1" in
    --prefix) [[ $# -ge 2 ]] || { echo "--prefix requiere un directorio" >&2; exit 2; }; PREFIX="$2"; shift 2 ;;
    --help|-h)
      printf 'Uso: ./install.sh [--prefix DIRECTORIO]\n'
      printf 'Por defecto instala en %s.\n' "$HOME/.local"
      exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; exit 2 ;;
  esac
done

[[ -f "$ROOT/equipo-ia.sh" && -f "$ROOT/equipo-pruebas.sh" && -f "$ROOT/bin/equipo" ]] || {
  echo "Ejecuta install.sh desde el repositorio de Equipo IA." >&2; exit 1;
}

install -d "$PREFIX/bin" "$PREFIX/share/equipo-ia/config"
install -m 755 "$ROOT/bin/equipo" "$PREFIX/bin/equipo"
install -m 755 "$ROOT/equipo-ia.sh" "$PREFIX/share/equipo-ia/equipo-ia.sh"
install -m 755 "$ROOT/equipo-pruebas.sh" "$PREFIX/share/equipo-ia/equipo-pruebas.sh"
install -m 644 "$ROOT/config/equipo.conf.example" "$PREFIX/share/equipo-ia/config/equipo.conf.example"
ln -sf ../share/equipo-ia/equipo-ia.sh "$PREFIX/bin/equipo-ia.sh"

printf 'Instalado en %s\n\n' "$PREFIX"
printf '1. Asegúrate de que %s/bin está en PATH:\n' "$PREFIX"
printf '   export PATH="%s/bin:$PATH"\n\n' "$PREFIX"
printf '2. Copia la configuración de ejemplo (opcional):\n'
printf '   mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/equipo-ia"\n'
printf '   cp "%s/share/equipo-ia/config/equipo.conf.example" "${XDG_CONFIG_HOME:-$HOME/.config}/equipo-ia/config.env"\n\n' "$PREFIX"
printf '3. Prueba la demo desde el repositorio:\n   ./demo.sh\n\n'
printf '4. Uso diario:\n   cd /ruta/a/tu/repo\n   equipo\n'
