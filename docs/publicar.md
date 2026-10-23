# Publicar en GitHub

Esta guía asume que el repositorio local ya está limpio y con un commit inicial.

## 1. Elegir identidad

No publiques tu correo personal. Configura un correo noreply de GitHub:

```bash
git config user.name "Tu Nombre"
git config user.email "moisesvillenam@users.noreply.github.com"
```

Si ya hiciste el commit con otro correo, cámbialo antes de publicar:

```bash
git commit --amend --reset-author
```

## 2. Crear el repositorio

Con GitHub CLI:

```bash
gh repo create equipo-ia --public --source=. --remote=origin --push
```

Sin `gh`: crea el repositorio vacío en GitHub y luego:

```bash
git remote add origin https://github.com/moisesvillenam/equipo-ia.git
git branch -M main
git push -u origin main
```

## 3. Revisar antes de publicar

```bash
git status
git log --format='%h %an <%ae> %s'
git grep -n -I -E 'api[_-]?key|secret|token|password|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY' || true
git grep -n -I '/home/|/Users/|@.*\.(com|org|net)' || true
```

Comprueba que no aparezcan rutas locales, correos, nombres de repositorios
privados, logs ni actas.

## 4. Completar la ficha del repositorio

- Descripción: “Patch-only multi-agent workflow with frozen baseline tests,
  protected test paths, and nonce-bound review.”
- Temas: `ai-agents`, `code-review`, `git`, `bash`, `developer-tools`,
  `patch`, `testing`.
- Licencia: Apache-2.0.
- Activa Issues y Discussions si quieres.
- Añade el badge de CI con tu usuario real en `README.md`.

## 5. Release

```bash
git tag -a v4.5.0 -m "Equipo IA 4.5.0"
git push origin v4.5.0
```

En GitHub, crea un release a partir del tag y adjunta el `CHANGELOG.md`.

## 6. CI

El workflow `.github/workflows/ci.yml` ejecuta:

- `bash -n`
- ShellCheck
- `tests/run-tests.sh`
- `demo.sh`

No necesita secretos. Si falla ShellCheck, corrige el aviso o ajusta la severidad
de forma justificada.

## 7. Después de publicar

- Verifica que el badge de CI apunte a tu usuario.
- Revisa que la demo funcione en un clon limpio.
- No subas `config.env`, actas ni logs.
- Mantén el correo noreply en los commits.
