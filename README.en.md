# Equipo IA 4.3

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
