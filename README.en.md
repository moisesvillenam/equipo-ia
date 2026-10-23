# Equipo IA 4.5

**A multi-agent workflow that never touches your repository: it produces a patch, reviews it, and lets you decide.**

Equipo IA is a Bash orchestrator for auditable AI coding work. The agent edits a
temporary copy; tests run in three disposable copies (baseline, current, and
control); test paths are protected; the reviewer must emit a nonce-bound verdict. The result is a patch, an evidence record (`acta`), and an
explicit state: `VALIDADO`, `SIN_CAMBIOS`, `REVISION_MANUAL`, or `RECHAZADO`.

## Quick start

No keys, network, or real agents are required for the demo:

```bash
git clone https://github.com/moisesvillenam/equipo-ia.git
cd equipo-ia
./demo.sh
```

Install the `equipo` command:

```bash
./install.sh
export PATH="$HOME/.local/bin:$PATH"
```

Use it inside a clean Git repository:

```bash
cd /path/to/your/repo
equipo
```

Then type a task. Review with `/diff`; apply with `/aplicar` only when the state
is `VALIDADO`.

## Why it is different

1. **Patch-only.** Your working tree is untouched until you apply the patch.
2. **Frozen baseline tests.** Tests run in three disposable copies: the baseline
   (original commit, no patch), the current tree (patch plus the agent's tests),
   and the control (patch with original tests restored). This separates
   pre-existing failures from regressions and detects weakened tests.
3. **Protected test paths.** Changes to tests, locks, CI, auth, and migrations
   force a human review.
4. **Nonce-bound verdict.** The reviewer must end with
   `VEREDICTO[<nonce>]: APROBADO` or `...: CORRECCIONES`; a diff cannot forge it.
5. **Evidence.** Patch SHA-256, all test runs, changed files, verdict, nonce,
   `acta.md`, and `acta.json`.
6. **Honest states.** Missing tests or an inconclusive review means
   `REVISION_MANUAL`, not a fake `VALIDADO`.

Since 4.3.2, process failures, incomplete TAP reports and ambiguous failure
counts cannot establish that a patch has no regressions. Red baseline
comparisons require usable evidence from both runs. `/aplicar` also requires
that evidence when tests still fail; older runs without it must be repeated.

## Modes

| Mode | Programmer | Reviewer |
|---|---|---|
| `maximo` | Codex | AGY or configured reviewer |
| `continuo` | OpenCode | AGY or configured reviewer |
| `auto` | Codex if available, otherwise OpenCode | AGY if available, otherwise manual |

`auto` resolves by tool availability, never by date.

## Requirements

Linux/WSL/macOS with Bash 4+, Git, `tar`, `mktemp`, `timeout` (or `gtimeout`),
and `sha256sum`/`shasum`. For real runs: Codex, OpenCode, and/or AGY. Node, Python,
or R are only needed for projects using those stacks.

## Configuration

Copy `config/equipo.conf.example` to
`${XDG_CONFIG_HOME:-$HOME/.config}/equipo-ia/config.env`. Environment variables
override the file. Key settings:

- `EQUIPO_MODE`, `EQUIPO_MAX_RETRIES`, `EQUIPO_TIMEOUT`
- `EQUIPO_TEST_CMD`, `EQUIPO_TEST_TIMEOUT`, `EQUIPO_NPM_CI`
- `EQUIPO_BASE_TESTS`, `EQUIPO_PROTECTED_PATHS`,
  `EQUIPO_REVIEWER_SKIP_PERMISSIONS`
- `EQUIPO_PROGRAMMER`, `EQUIPO_REVIEWER`, `EQUIPO_MODEL`

See [docs/configuracion.md](docs/configuracion.md).

## Security

Agents run with your permissions. The built-in sandbox flags are not a security
boundary. Use a container or VM without secrets for untrusted code. The patch is
untrusted data; the reviewer prompt says so, and the nonce prevents diff-level
verdict spoofing. Protected paths reduce test tampering but do not replace human
review. See [docs/seguridad.md](docs/seguridad.md).

## Documentation

- [Arquitectura](docs/arquitectura.md)
- [Seguridad](docs/seguridad.md)
- [Artefactos](docs/artefactos.md)
- [Configuración](docs/configuracion.md)
- [Adaptadores](docs/adaptadores.md)
- [Comparación](docs/comparacion.md)
- [FAQ](docs/faq.md)
- [ADRs](docs/adr/)

## Development

```bash
./demo.sh
./tests/run-tests.sh
bash -n equipo-ia.sh equipo-pruebas.sh bin/equipo install.sh demo.sh
```

The tests use fake agents in `examples/fake-agents/`; no network or API keys.

## License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

## Publish project commits (4.4.0)

After reviewing and committing your changes, run `/publicar` inside `equipo`.
It shows the exact commit, remote URL and target branch, runs the current tests,
and asks you to type `PUBLICAR` before pushing. It uses the current branch's
upstream, or `origin` with the same branch name when no upstream exists.
`/publicar comprobar` checks the destination and tests locally without pushing;
it does not check remote access or credentials.

Publishing requires a clean working tree and passing tests. It does not commit
files, force a push, or send additional branches or tags. Reports are stored
in `publicacion_*` under the state directory. Existing dependencies are used
unless `EQUIPO_NPM_CI=si` explicitly authorizes installation.

Run `./install.sh` again and restart `equipo` to update your installation.
This publishes code to Git; a public website requires a separately configured
hosting service or deployment workflow.

## Windows desktop preview (4.5.0)

The Windows ZIP includes a graphical interface, per-user installer and desktop
shortcut. The engine runs in Ubuntu/WSL. You can prepare the environment, choose
a Git project, request a change, review and apply the patch, and save a local
commit. A simulated example is available without an AI account.

Extract the ZIP, then open `windows/Instalar Equipo IA.cmd`. See
[the Windows guide](docs/windows.md) for setup and testing scope. The maintainer
reported testing the application on Windows; the full acceptance checklist has
not been recorded. Windows remains a preview. Publishing remains available from
the console; the window saves local commits.
