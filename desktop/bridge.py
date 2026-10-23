#!/usr/bin/env python3
"""Puente local JSON para la interfaz Windows. Sin servidor ni dependencias pip.

Las peticiones llegan como JSON UTF-8 en base64, nunca como comandos de shell.
Los trabajos conservan una carpeta de estado propia; aplicar reutiliza la consola.
"""
from __future__ import annotations

import base64
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parent.parent
MAX_TEXT = 1_000_000
ACTIVE = {"PREPARANDO", "EN_CURSO"}
STARTED_WORKERS = []


class UserError(Exception):
    pass


def state_dir() -> Path:
    base = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
    target = Path(os.environ.get("EQUIPO_DESKTOP_STATE", str(base / "equipo-ia-desktop")))
    target.mkdir(parents=True, exist_ok=True, mode=0o700)
    (target / "jobs").mkdir(exist_ok=True, mode=0o700)
    return target.resolve()


def save_json(path: Path, value: dict) -> None:
    temporary = path.with_suffix(".tmp-" + uuid.uuid4().hex)
    temporary.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")
    temporary.chmod(0o600)
    temporary.replace(path)


def read_text(path: Path, limit: int = MAX_TEXT, tail: bool = False) -> str:
    if not path.is_file() or path.is_symlink():
        return ""
    with path.open("rb") as stream:
        if tail:
            stream.seek(max(0, path.stat().st_size - limit))
        data = stream.read(limit + 1)
    text = data[:limit].decode("utf-8", errors="replace")
    text = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)
    if len(data) > limit:
        text += "\n[Vista limitada; el archivo completo está en la carpeta de resultados.]"
    return text


def call(args: list[str], cwd: Path | None = None, timeout: int = 30,
         env: dict | None = None, input_text: str | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(args, cwd=cwd, env=env, input=input_text,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, encoding="utf-8", errors="replace", timeout=timeout,
                          check=False)


def git(project: Path, *args: str) -> subprocess.CompletedProcess:
    return call(["git", "-C", str(project), *args])


def project_info(value: str, require_clean: bool = False) -> dict:
    if not isinstance(value, str) or not value.strip() or "\x00" in value:
        raise UserError("Selecciona una carpeta de proyecto.")
    if re.match(r"^[A-Za-z]:[\\/]", value):
        converted = call(["wslpath", "-u", value])
        if converted.returncode:
            raise UserError("No se pudo abrir esa carpeta de Windows desde Ubuntu.")
        value = converted.stdout.strip()
    if value.startswith("\\\\"):
        parts = value.replace("\\", "/").split("/")
        if len(parts) < 5 or parts[2].lower() not in {"wsl$", "wsl.localhost"}:
            raise UserError("Copia el proyecto a una carpeta local o selecciona una carpeta de Ubuntu.")
        if parts[3].lower() != os.environ.get("WSL_DISTRO_NAME", "").lower():
            raise UserError("La carpeta pertenece a otra distribución. Selecciona esa distribución en Preparación.")
        value = "/" + "/".join(parts[4:])
    project = Path(value).expanduser().resolve()
    if not project.is_dir():
        raise UserError("La carpeta no existe dentro de la distribución seleccionada.")
    top = git(project, "rev-parse", "--show-toplevel")
    if top.returncode:
        raise UserError("Esta carpeta aún no es un proyecto Git. Puedes crear un proyecto de práctica con el botón de ejemplo; para un proyecto existente pide ayuda para preparar su historial.")
    project = Path(top.stdout.strip()).resolve()
    if "\n" in str(project) or "\r" in str(project):
        raise UserError("El nombre de la carpeta no puede contener saltos de línea.")
    head = git(project, "rev-parse", "--verify", "HEAD")
    if head.returncode:
        raise UserError("El proyecto todavía no tiene una versión guardada (commit).")
    status = git(project, "status", "--porcelain", "--untracked-files=all")
    if status.returncode:
        raise UserError("No se pudo comprobar el estado del proyecto: " + status.stdout)
    branch = git(project, "branch", "--show-current").stdout.strip() or "versión fija"
    info = {"project": str(project), "commit": head.stdout.strip(), "branch": branch,
            "clean": not status.stdout.strip(), "changes": status.stdout.strip()}
    if require_clean and not info["clean"]:
        raise UserError("Hay cambios pendientes. Revísalos y guarda una versión antes de pedir otra tarea. Equipo IA no los guarda ni los borra automáticamente.")
    return info


def diagnose() -> dict:
    names = ["bash", "git", "tar", "mktemp", "timeout", "sha256sum", "python3", "node", "npm", "curl", "codex", "opencode", "agy"]
    found = {name: bool(shutil.which(name)) for name in names}
    auth = "no_instalado"
    if found["codex"]:
        try:
            auth = "conectado" if call(["codex", "login", "status"], timeout=15).returncode == 0 else "sin_sesion"
        except subprocess.TimeoutExpired:
            auth = "no_comprobado"
    missing = [name for name in names[:7] if not found[name]]
    return {"tools": found, "missing": missing, "ready": not missing,
            "codex_auth": auth, "home": str(Path.home()), "state_dir": str(state_dir()),
            "user_is_root": os.geteuid() == 0, "engine_version": "4.5.0"}


def example() -> dict:
    project = state_dir() / "projects" / ("saludo-" + uuid.uuid4().hex[:10])
    project.parent.mkdir(exist_ok=True, mode=0o700)
    shutil.copytree(ROOT / "examples/toy-repo", project)
    for args in [("init", "-q"), ("add", "--", "index.js", "test.js", "package.json", "README.md"),
                 ("-c", "user.name=Equipo IA", "-c", "user.email=equipo-ia@localhost",
                  "commit", "-qm", "Ejemplo inicial")]:
        result = git(project, *args)
        if result.returncode:
            raise UserError("No se pudo preparar el ejemplo: " + result.stdout)
    info = project_info(str(project))
    info["suggested_task"] = "Corrige el saludo para que greet('Mundo') devuelva exactamente 'Hola, Mundo'. Conserva las pruebas existentes."
    return info


def job_dir(job_id: str) -> Path:
    if not isinstance(job_id, str) or not re.fullmatch(r"[0-9a-f]{32}", job_id):
        raise UserError("Identificador de tarea no válido.")
    target = state_dir() / "jobs" / job_id
    if target.is_symlink() or not target.is_dir():
        raise UserError("No se encontró esta tarea.")
    return target


def load_job(job_id: str) -> tuple[Path, dict]:
    directory = job_dir(job_id)
    return directory, json.loads((directory / "job.json").read_text(encoding="utf-8"))


@contextlib.contextmanager
def exclusive():
    with (state_dir() / "operation.lock").open("a+") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise UserError("Hay una tarea en curso. Espera su resultado antes de iniciar o aplicar otra.") from exc
        yield lock


def process_identity(pid: int) -> str:
    try:
        # El campo comm puede contener espacios y paréntesis.
        fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
        if fields[0] == "Z":
            return ""
        return fields[19]
    except (OSError, IndexError):
        return ""


def start(request: dict) -> dict:
    task = request.get("task", "")
    if not isinstance(task, str) or not 3 <= len(task.strip()) <= 12000 or "\x00" in task:
        raise UserError("Describe la tarea con entre 3 y 12000 caracteres.")
    programmer = request.get("programmer", "codex")
    reviewer = request.get("reviewer", "codex")
    demo = request.get("demo", False)
    if type(demo) is not bool or type(request.get("npm_ci", False)) is not bool:
        raise UserError("Las opciones de la tarea no son válidas.")
    if programmer not in {"codex", "opencode"} or reviewer not in {"codex", "agy"}:
        raise UserError("Selecciona uno de los agentes disponibles.")
    with exclusive() as lock:
        info = project_info(request.get("project", ""), require_clean=True)
        if demo:
            projects = (state_dir() / "projects").resolve()
            if Path(info["project"]).parent != projects:
                raise UserError("La simulación solo se ejecuta en proyectos de práctica creados por la aplicación.")
        elif any(not shutil.which(name) for name in {programmer, reviewer}):
            raise UserError("Falta instalar uno de los agentes seleccionados dentro de Ubuntu. Revisa Preparación.")
        identity = uuid.uuid4().hex
        directory = state_dir() / "jobs" / identity
        directory.mkdir(mode=0o700)
        job = {"id": identity, "status": "PREPARANDO", "created": time.time(),
               "project": info["project"], "commit": info["commit"], "task": task.strip(),
               "programmer": programmer, "reviewer": reviewer, "demo": demo,
               "npm_ci": request.get("npm_ci", False), "applied": False}
        save_json(directory / "job.json", job)
        with (directory / "worker.log").open("w", encoding="utf-8") as log:
            process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--worker", identity,
                                        str(lock.fileno())], stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                                        start_new_session=True, pass_fds=(lock.fileno(),), close_fds=True)
            STARTED_WORKERS.append(process)
        # El hijo conserva el descriptor; el bloqueo dura hasta que termina.
    return {"id": identity, "status": "PREPARANDO", "project": info["project"]}


def engine_environment(directory: Path, job: dict) -> dict:
    # Evitar que una configuración previa relaje controles de esta interfaz.
    env = {k: v for k, v in os.environ.items() if not k.startswith("EQUIPO_")}
    env.update(EQUIPO_CONFIG=str(directory / "config-vacia"),
               EQUIPO_STATE_DIR=str(directory / "engine"), EQUIPO_BASE_TESTS="si",
               EQUIPO_SECOND_OPINION="no", EQUIPO_MAX_RETRIES="2", EQUIPO_ASSUME_YES="si",
               EQUIPO_NPM_CI="si" if job["npm_ci"] else "no",
               EQUIPO_PROGRAMMER=job["programmer"], EQUIPO_REVIEWER=job["reviewer"])
    if job["demo"]:
        fake = directory / "fake-bin"
        shutil.copytree(ROOT / "examples/fake-agents", fake)
        for executable in fake.iterdir():
            executable.chmod(0o700)
        env.update(PATH=str(fake) + os.pathsep + env.get("PATH", ""),
                   EQUIPO_PROGRAMMER="codex", EQUIPO_REVIEWER="agy",
                   EQUIPO_FAKE_FIX=str(ROOT / "examples/fixtures/index.fixed.js"))
    elif job["reviewer"] == "codex":
        env["EQUIPO_REVIEWER"] = "command"
        env["EQUIPO_REVIEWER_CMD"] = "bash " + shlex.quote(str(ROOT / "desktop/revisor-codex.sh"))
    return env


def worker(job_id: str, lock_fd: int) -> None:
    # El descriptor abierto mantiene la exclusión incluso si se cierra la ventana.
    os.fstat(lock_fd)
    directory, job = load_job(job_id)
    job.update(status="EN_CURSO", pid=os.getpid(), process_identity=process_identity(os.getpid()))
    save_json(directory / "job.json", job)
    try:
        info = project_info(job["project"], require_clean=True)
        if info["commit"] != job["commit"]:
            raise UserError("La versión del proyecto cambió antes de iniciar. Vuelve a solicitar la tarea.")
        env = engine_environment(directory, job)
        mode = "maximo" if job["programmer"] == "codex" or job["demo"] else "continuo"
        args = ["bash", str(ROOT / "equipo-ia.sh"), "--si", "--modo", mode,
                "--npm-ci", env["EQUIPO_NPM_CI"], "--intentos", "0" if job["demo"] else "2",
                "--", job["task"]]
        with (directory / "execution.log").open("w", encoding="utf-8") as stream:
            result = subprocess.run(args, cwd=job["project"], env=env, stdin=subprocess.DEVNULL,
                                    stdout=stream, stderr=subprocess.STDOUT, check=False)
        runs = list((directory / "engine").glob("ejecucion_*"))
        if len(runs) != 1 or runs[0].is_symlink():
            raise UserError("La tarea terminó antes de crear un resultado. Consulta el registro para revisar dependencias, pruebas o autenticación.")
        run = runs[0]
        acta = json.loads((run / "acta.json").read_text(encoding="utf-8"))
        if acta.get("state") not in {"VALIDADO", "SIN_CAMBIOS", "REVISION_MANUAL", "RECHAZADO"}:
            raise UserError("El motor devolvió un estado desconocido.")
        expected = {"VALIDADO": 0, "SIN_CAMBIOS": 10, "REVISION_MANUAL": 20, "RECHAZADO": 30}
        if result.returncode != expected[acta["state"]]:
            raise UserError("El proceso terminó de forma inesperada. Este resultado no se puede aplicar.")
        patch = run / "cambios.patch"
        digest = hashlib.sha256(patch.read_bytes()).hexdigest()
        if patch.stat().st_size and acta.get("patch_sha256") != digest:
            raise UserError("El parche no coincide con la huella del acta.")
        job.update(status=acta["state"], reason=acta["reason"], run=run.name,
                   patch_hash=digest, exit_code=result.returncode, finished=time.time())
    except Exception as exc:
        job.update(status="ERROR", reason=str(exc), finished=time.time())
    os.close(lock_fd)
    save_json(directory / "job.json", job)


def get_run(directory: Path, job: dict) -> Path | None:
    name = job.get("run", "")
    if not re.fullmatch(r"ejecucion_[A-Za-z0-9_]+", name):
        return None
    run = directory / "engine" / name
    return run if run.is_dir() and not run.is_symlink() else None


def status(job_id: str) -> dict:
    STARTED_WORKERS[:] = [process for process in STARTED_WORKERS if process.poll() is None]
    directory, job = load_job(job_id)
    if job["status"] in ACTIVE:
        if job.get("pid") and process_identity(job["pid"]) != job.get("process_identity"):
            job.update(status="ERROR", reason="La ejecución se interrumpió. Conservamos el registro; solicita otra tarea para volver a validar.")
        elif not job.get("pid") and time.time() - job["created"] > 60:
            job.update(status="ERROR", reason="No se pudo iniciar el trabajo. Consulta el registro y vuelve a intentarlo.")
    output = dict(job)
    output["log"] = read_text(directory / "execution.log", 80000, tail=True) or read_text(directory / "worker.log", 80000, tail=True)
    output["patch"] = ""
    output["review"] = ""
    output["acta"] = ""
    output["files"] = []
    output["tests"] = {}
    output["can_apply"] = False
    run = get_run(directory, job)
    if run:
        output["patch"] = read_text(run / "cambios.patch")
        output["review"] = read_text(run / "revision-agy.txt")
        output["acta"] = read_text(run / "acta.md")
        try:
            acta = json.loads(read_text(run / "acta.json"))
            output["files"] = acta.get("changed_files", [])
            output["tests"] = {name: acta.get(name, "") for name in ["baseline_tests", "current_tests", "control_tests"]}
        except (ValueError, TypeError):
            pass
        output["can_apply"] = (job["status"] == "VALIDADO" and not job.get("applied") and
                               hashlib.sha256((run / "cambios.patch").read_bytes()).hexdigest() == job.get("patch_hash"))
    return output


def history() -> dict:
    items = []
    for path in (state_dir() / "jobs").glob("*/job.json"):
        try:
            job = json.loads(path.read_text(encoding="utf-8"))
            items.append({k: job.get(k) for k in ["id", "status", "created", "task", "project", "demo", "applied"]})
        except (ValueError, OSError):
            continue
    return {"jobs": sorted(items, key=lambda item: item["created"], reverse=True)[:50]}


def worktree_digest(project: Path) -> str:
    digest = hashlib.sha256()
    for args in [("status", "--porcelain", "-z", "--untracked-files=all"),
                 ("diff", "--binary", "HEAD")]:
        result = git(project, *args)
        if result.returncode:
            raise UserError("No se pudo inspeccionar el cambio aplicado.")
        digest.update(result.stdout.encode("utf-8"))
    untracked = git(project, "ls-files", "--others", "--exclude-standard", "-z")
    for name in untracked.stdout.split("\0"):
        if not name:
            continue
        path = project / name
        digest.update(name.encode("utf-8"))
        if path.is_symlink():
            digest.update(os.readlink(path).encode("utf-8"))
        elif path.is_file():
            with path.open("rb") as stream:
                for chunk in iter(lambda: stream.read(65536), b""):
                    digest.update(chunk)
    return digest.hexdigest()


def changed_paths(project: Path) -> list[str]:
    names = set()
    for args in [("diff", "--name-only", "-z", "HEAD"),
                 ("ls-files", "--others", "--exclude-standard", "-z")]:
        result = git(project, *args)
        if result.returncode:
            raise UserError("No se pudo identificar los archivos del cambio aplicado.")
        names.update(name for name in result.stdout.split("\0") if name)
    return sorted(names)


def apply(request: dict) -> dict:
    if request.get("confirmation") != "APLICAR":
        raise UserError("Confirma expresamente que quieres aplicar este cambio.")
    with exclusive():
        directory, job = load_job(request.get("id", ""))
        snapshot = status(job["id"])
        if not snapshot["can_apply"]:
            raise UserError("Esta tarea no tiene un parche validado pendiente de aplicar.")
        runs = list((directory / "engine").glob("ejecucion_*"))
        if len(runs) != 1 or runs[0] != get_run(directory, job):
            raise UserError("La carpeta contiene resultados adicionales. No se aplicará una propuesta distinta de la que revisaste.")
        if request.get("patch_hash") != job.get("patch_hash"):
            raise UserError("La propuesta cambió. Vuelve a abrir y revisar el resultado.")
        info = project_info(job["project"], require_clean=True)
        if info["commit"] != job["commit"]:
            raise UserError("El proyecto cambió de versión. Ejecuta otra tarea sobre su versión actual.")
        env = {k: v for k, v in os.environ.items() if not k.startswith("EQUIPO_")}
        env.update(EQUIPO_STATE_DIR=str(directory / "engine"),
                   EQUIPO_CONFIG=str(directory / "config-vacia"), EQUIPO_INTERACTION="desarrollo")
        response = call(["bash", str(ROOT / "bin/equipo")], cwd=Path(job["project"]), env=env,
                        input_text="/aplicar\nAPLICAR\n/salir\n")
        (directory / "apply.log").write_text(response.stdout, encoding="utf-8")
        # La consola puede salir con cero después de rechazar /aplicar.
        if response.returncode or "Parche aplicado. Revisa los cambios y haz commit cuando quieras." not in response.stdout:
            raise UserError("El motor no permitió aplicar el cambio:\n" + response.stdout)
        job.update(applied=True, applied_at=time.time(),
                   applied_files=changed_paths(Path(job["project"])),
                   checkpoint_digest=worktree_digest(Path(job["project"])))
        save_json(directory / "job.json", job)
        return {"applied": True, "message": "Cambios aplicados a tu carpeta. Revísalos y guarda una versión con Git; todavía no se han publicado.", "project": job["project"]}


def checkpoint(request: dict) -> dict:
    if request.get("confirmation") != "GUARDAR":
        raise UserError("Confirma que quieres guardar la versión local.")
    with exclusive():
        directory, job = load_job(request.get("id", ""))
        if not job.get("applied") or job.get("saved_commit"):
            raise UserError("Esta tarea no tiene cambios aplicados pendientes de guardar.")
        info = project_info(job["project"])
        project = Path(info["project"])
        if info["commit"] != job["commit"] or worktree_digest(project) != job.get("checkpoint_digest"):
            raise UserError("Hubo cambios adicionales después de aplicar. Revísalos con Git antes de guardar; la aplicación no los incluirá automáticamente.")
        # Nombres NUL-delimited de Git: el acta de texto puede escapar Unicode.
        files = job.get("applied_files", [])
        if not files or any(not isinstance(name, str) or name.startswith("/") or ".." in Path(name).parts for name in files):
            raise UserError("No hay una lista válida de archivos que guardar.")
        staged = git(project, "add", "-A", "--", *files)
        if staged.returncode:
            raise UserError("No se pudo preparar la versión: " + staged.stdout)
        identity = []
        for key, fallback in [("user.name", "Equipo IA"), ("user.email", "equipo-ia@localhost")]:
            if not git(project, "config", "--get", key).stdout.strip():
                identity.extend(["-c", f"{key}={fallback}"])
        result = git(project, *identity, "commit", "-m", "Equipo IA: " + job["task"].splitlines()[0][:100])
        if result.returncode:
            raise UserError("Git no pudo guardar la versión. Los cambios quedan preparados para revisarlos; no se publicó nada.\n" + result.stdout)
        job["saved_commit"] = git(project, "rev-parse", "HEAD").stdout.strip()
        save_json(directory / "job.json", job)
        return {"commit": job["saved_commit"], "message": "Versión guardada en tu equipo. Ya puedes pedir otra tarea. No se publicó en Internet."}


def dispatch(request: dict) -> dict:
    if not isinstance(request, dict):
        raise UserError("La petición debe ser un objeto JSON.")
    action = request.get("action")
    if action == "diagnose":
        return diagnose()
    if action == "project":
        return project_info(request.get("project", ""))
    if action == "example":
        return example()
    if action == "start":
        return start(request)
    if action == "status":
        return status(request.get("id", ""))
    if action == "history":
        return history()
    if action == "apply":
        return apply(request)
    if action == "checkpoint":
        return checkpoint(request)
    raise UserError("Acción no disponible.")


def main() -> int:
    os.umask(0o077)
    if len(sys.argv) == 4 and sys.argv[1] == "--worker":
        worker(sys.argv[2], int(sys.argv[3]))
        return 0
    try:
        if len(sys.argv) != 2 or len(sys.argv[1]) > 100000:
            raise UserError("Petición ausente o demasiado grande.")
        request = json.loads(base64.b64decode(sys.argv[1], validate=True).decode("utf-8"))
        result = {"ok": True, "data": dispatch(request)}
    except Exception as exc:
        result = {"ok": False, "error": str(exc)}
    print(json.dumps(result, ensure_ascii=False), flush=True)
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
