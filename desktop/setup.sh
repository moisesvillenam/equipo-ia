#!/usr/bin/env bash
# Acciones fijas del asistente; se ejecutan solo tras pulsar su botón.
set -Eeuo pipefail
case "${1:-}" in
  base)
    [[ "$(id -u)" == 0 ]] || { echo 'La preparación de Ubuntu necesita permisos de administrador.'; exit 1; }
    command -v apt-get >/dev/null || { echo 'El asistente automático requiere Ubuntu o Debian.'; exit 1; }
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y git python3 nodejs npm curl ca-certificates coreutils
    echo 'Herramientas instaladas. Vuelve a Equipo IA y pulsa Comprobar.'
    ;;
  codex)
    [[ "$(id -u)" != 0 ]] || { echo 'Abre Ubuntu y crea tu usuario antes de instalar Codex.'; exit 1; }
    command -v curl >/dev/null || { echo 'Primero prepara las herramientas de Ubuntu.'; exit 1; }
    installer="$(mktemp)"
    trap 'rm -f "$installer"' EXIT
    curl --proto '=https' --tlsv1.2 -fsSL https://chatgpt.com/codex/install.sh -o "$installer"
    sh "$installer"
    echo 'Instalación terminada. Vuelve a Equipo IA y pulsa Comprobar.'
    ;;
  login)
    export PATH="$HOME/.local/bin:$PATH"
    codex login
    ;;
  login-device)
    export PATH="$HOME/.local/bin:$PATH"
    codex login --device-auth
    ;;
  *) echo 'Acción de preparación desconocida.' >&2; exit 2 ;;
esac
