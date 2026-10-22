#!/usr/bin/env bash
# Comprobaciones básicas de datos privados y secretos en archivos versionados.
# No sustituye a un escáner profesional.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PATRONES=(
  '/home/[A-Za-z0-9._-]+/'
  '/Users/[A-Za-z0-9._-]+/'
  'C:\\Users\\'
  'BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY'
  'ghp_[A-Za-z0-9]{20,}'
  'sk-[A-Za-z0-9]{20,}'
  'xox[baprs]-[A-Za-z0-9-]+'
  'AKIA[0-9A-Z]{16}'
  'api[_-]?key[[:space:]]*[:=][[:space:]]*["'\'']?[A-Za-z0-9]{16,}'
)

fallos=0
for patron in "${PATRONES[@]}"; do
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    coincidencias="$(git grep -n -I -E "$patron" -- . ':!LICENSE' ':!NOTICE' ':!tests/check-secrets.sh' 2>/dev/null || true)"
  else
    coincidencias="$(grep -RInE --exclude-dir=.git --exclude-dir=node_modules --exclude=check-secrets.sh -- "$patron" . 2>/dev/null || true)"
  fi
  if [[ -n "$coincidencias" ]]; then
    printf 'Posible dato sensible (%s):\n%s\n\n' "$patron" "$coincidencias"
    fallos=1
  fi
done

if ((fallos)); then
  printf 'Revisa las coincidencias antes de publicar.\n' >&2
  exit 1
fi
printf 'Sin coincidencias de secretos o rutas personales conocidas.\n'
