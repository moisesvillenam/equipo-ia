"""Pruebas de extremo a extremo del puente, sin cuentas ni red."""
import base64
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

MODULE = Path(__file__).with_name("bridge.py")
spec = importlib.util.spec_from_file_location("bridge", MODULE)
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="equipo-gui-tests-")
        self.root = Path(self.temporary.name)
        self.env = patch.dict(os.environ, {"EQUIPO_DESKTOP_STATE": str(self.root / "state")})
        self.env.start()
        self.jobs = []

    def tearDown(self):
        for identity in self.jobs:
            self.wait(identity)
        self.env.stop()
        self.temporary.cleanup()

    def example(self):
        return bridge.example()["project"]

    def wait(self, identity, timeout=35):
        until = time.monotonic() + timeout
        while time.monotonic() < until:
            result = bridge.status(identity)
            if result["status"] not in bridge.ACTIVE:
                return result
            time.sleep(0.1)
        self.fail("El trabajo no terminó a tiempo: " + str(bridge.status(identity)))

    def run_task(self, project=None, demo=True, task="Corrige el saludo", **options):
        response = bridge.start({"project": project or self.example(), "task": task, "demo": demo, **options})
        self.jobs.append(response["id"])
        return self.wait(response["id"])

    def apply(self, result):
        return bridge.apply({"id": result["id"], "patch_hash": result["patch_hash"], "confirmation": "APLICAR"})

    def fake_codex(self, behavior="fix"):
        """Un CLI falso que también verifica stdin del adaptador revisor Codex."""
        directory = self.root / "bin"
        directory.mkdir(exist_ok=True)
        script = directory / "codex"
        source = '''#!/usr/bin/env python3
import os, pathlib, re, sys, time
prompt = sys.stdin.read()
if os.environ.get('EQUIPO_ROLE') == 'revisor':
    assert '--sandbox' in sys.argv and 'read-only' in sys.argv
    assert os.environ['EQUIPO_NONCE'] in prompt
    print('VEREDICTO[' + os.environ['EQUIPO_NONCE'] + ']: APROBADO')
else:
    cwd = pathlib.Path(sys.argv[sys.argv.index('-C') + 1])
    BEHAVIOR
'''
        behavior_source = {
            "fix": "(cwd / 'index.js').write_text(\"function greet(name) { return 'Hola, ' + name; }\\nmodule.exports = { greet };\\n\")",
            "noop": "print('Sin cambios')",
            "protected": "(cwd / 'test.js').write_text('// prueba reemplazada\\n')",
            "regression": "(cwd / 'index.js').write_text(\"module.exports = { greet: () => 'roto' };\\n\")",
            "wait": "time.sleep(2); (cwd / 'index.js').write_text(\"module.exports = { greet: name => 'Hola, ' + name };\\n\")",
            "unicode": "(cwd / 'index.js').write_text(\"module.exports = { greet: name => 'Hola, ' + name };\\n\"); (cwd / 'explicación nueva.txt').write_text('Cambios del saludo')",
            "fail": "sys.exit(1)",
        }[behavior]
        script.write_text(source.replace("BEHAVIOR", behavior_source))
        script.chmod(0o700)
        return patch.dict(os.environ, {"PATH": str(directory) + os.pathsep + os.environ["PATH"]})

    def test_demo_preserves_original_and_applies_then_saves(self):
        project = self.example()
        before = Path(project, "index.js").read_bytes()
        result = self.run_task(project)
        self.assertEqual(result["status"], "VALIDADO", result)
        self.assertTrue(result["demo"])
        self.assertEqual(before, Path(project, "index.js").read_bytes())
        self.assertIn('Hola, ', result["patch"])
        self.assertTrue(self.apply(result)["applied"])
        self.assertFalse(bridge.status(result["id"])["can_apply"])
        saved = bridge.checkpoint({"id": result["id"], "confirmation": "GUARDAR"})
        self.assertTrue(saved["commit"])
        self.assertTrue(bridge.project_info(project)["clean"])
        with self.assertRaises(bridge.UserError):
            bridge.checkpoint({"id": result["id"], "confirmation": "GUARDAR"})

    def test_dirty_project_and_non_repo_are_rejected(self):
        project = self.example()
        Path(project, "personal.txt").write_text("no incluir")
        with self.assertRaisesRegex(bridge.UserError, "pendientes"):
            bridge.start({"project": project, "task": "Una tarea", "demo": True})
        with self.assertRaisesRegex(bridge.UserError, "Git"):
            bridge.project_info(str(self.root))

    def test_no_commit_is_actionable(self):
        project = self.root / "empty"
        project.mkdir()
        bridge.git(project, "init", "-q")
        with self.assertRaisesRegex(bridge.UserError, "commit"):
            bridge.project_info(str(project))

    def test_confirmation_and_hash_required(self):
        result = self.run_task()
        with self.assertRaises(bridge.UserError):
            bridge.apply({"id": result["id"]})
        with self.assertRaisesRegex(bridge.UserError, "cambió"):
            bridge.apply({"id": result["id"], "confirmation": "APLICAR", "patch_hash": "bad"})

    def test_modified_patch_cannot_apply(self):
        result = self.run_task()
        directory, job = bridge.load_job(result["id"])
        run = bridge.get_run(directory, job)
        with (run / "cambios.patch").open("a") as stream:
            stream.write("\nmodificado")
        self.assertFalse(bridge.status(result["id"])["can_apply"])
        with self.assertRaises(bridge.UserError):
            self.apply(result)

    def test_changed_commit_cannot_apply(self):
        result = self.run_task()
        project = Path(result["project"])
        bridge.git(project, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "--allow-empty", "-qm", "Cambio de base")
        with self.assertRaisesRegex(bridge.UserError, "versión"):
            self.apply(result)

    def test_console_validation_is_not_bypassed(self):
        result = self.run_task()
        directory, job = bridge.load_job(result["id"])
        run = bridge.get_run(directory, job)
        (run / "rutas-protegidas.txt").write_text("test.js\n")
        with self.assertRaisesRegex(bridge.UserError, "motor no permitió"):
            self.apply(result)
        self.assertTrue(bridge.project_info(result["project"])["clean"])

    def test_extra_run_cannot_replace_reviewed_proposal(self):
        result = self.run_task()
        directory, job = bridge.load_job(result["id"])
        (directory / "engine/ejecucion_extra").mkdir()
        with self.assertRaisesRegex(bridge.UserError, "adicionales"):
            self.apply(result)

    def test_checkpoint_refuses_additional_edits(self):
        result = self.run_task()
        self.apply(result)
        Path(result["project"], "privado.txt").write_text("No incluir en Git")
        with self.assertRaisesRegex(bridge.UserError, "adicionales"):
            bridge.checkpoint({"id": result["id"], "confirmation": "GUARDAR"})
        self.assertEqual(bridge.git(Path(result["project"]), "diff", "--cached").stdout, "")

    def test_checkpoint_handles_new_unicode_filename(self):
        with self.fake_codex("unicode"):
            result = self.run_task(demo=False)
        self.assertEqual(result["status"], "VALIDADO", result)
        self.apply(result)
        bridge.checkpoint({"id": result["id"], "confirmation": "GUARDAR"})
        self.assertTrue(bridge.project_info(result["project"])["clean"])
        self.assertEqual(Path(result["project"], "explicación nueva.txt").read_text(), "Cambios del saludo")

    def test_demo_cannot_run_on_arbitrary_project(self):
        project = Path(self.example())
        other = self.root / "user-project"
        shutil.copytree(project, other)
        with self.assertRaisesRegex(bridge.UserError, "práctica"):
            bridge.start({"project": str(other), "task": "Una tarea", "demo": True})

    def test_arguments_are_not_shell_code_and_unicode_survives(self):
        project = Path(self.example())
        other = self.root / "Proyecto español ' $(echo no)"
        shutil.copytree(project, other)
        marker = self.root / "INJECTED"
        task = f"Corrige el saludo; $(touch {marker}) `touch {marker}`\nñá 漢字"
        with self.fake_codex():
            result = self.run_task(str(other), demo=False, task=task)
        self.assertEqual(result["status"], "VALIDADO", result)
        self.assertEqual(result["task"], task)
        self.assertFalse(marker.exists())
        self.assertIn("APROBADO", result["review"])

    def test_no_changes_is_a_result_not_an_error(self):
        with self.fake_codex("noop"):
            result = self.run_task(demo=False)
        self.assertEqual(result["status"], "SIN_CAMBIOS", result)
        self.assertFalse(result["can_apply"])

    def test_protected_changes_require_manual_review(self):
        with self.fake_codex("protected"):
            result = self.run_task(demo=False)
        self.assertEqual(result["status"], "REVISION_MANUAL", result)
        self.assertFalse(result["can_apply"])

    def test_programmer_failure_is_rejected(self):
        with self.fake_codex("fail"):
            result = self.run_task(demo=False)
        self.assertEqual(result["status"], "RECHAZADO", result)
        self.assertFalse(result["can_apply"])

    def test_regression_is_rejected(self):
        project = Path(self.example())
        shutil.copyfile(bridge.ROOT / "examples/fixtures/index.fixed.js", project / "index.js")
        bridge.git(project, "add", "index.js")
        bridge.git(project, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "Base verde")
        with self.fake_codex("regression"):
            result = self.run_task(str(project), demo=False)
        self.assertEqual(result["status"], "RECHAZADO", result)
        self.assertFalse(result["can_apply"])

    def test_lock_survives_start_process(self):
        with self.fake_codex("wait"):
            project = self.example()
            result = bridge.start({"project": project, "task": "Corrige", "demo": False})
            self.jobs.append(result["id"])
            with self.assertRaisesRegex(bridge.UserError, "curso"):
                bridge.start({"project": project, "task": "Otra tarea", "demo": False})
            self.assertEqual(self.wait(result["id"])["status"], "VALIDADO")

    def test_protocol_rejects_invalid_json_and_traversal(self):
        result = subprocess.run(["python3", str(MODULE), "not-base64"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertFalse(json.loads(result.stdout)["ok"])
        with self.assertRaises(bridge.UserError):
            bridge.status("../../etc/passwd")
        payload = base64.b64encode(json.dumps({"action": "history"}).encode()).decode()
        valid = subprocess.run(["python3", str(MODULE), payload], capture_output=True, text=True)
        self.assertTrue(json.loads(valid.stdout)["ok"])

    def test_no_auth_secrets_in_diagnosis(self):
        def check(*args, **kwargs):
            return subprocess.CompletedProcess(args, 0, "private token must not be returned")
        with patch.object(bridge, "call", side_effect=check), patch.object(bridge.shutil, "which", return_value="/fake"):
            data = bridge.diagnose()
        self.assertEqual(data["codex_auth"], "conectado")
        self.assertNotIn("private token", json.dumps(data))

    def test_history_retains_project_and_demo_label(self):
        result = self.run_task()
        item = bridge.history()["jobs"][0]
        self.assertEqual(item["id"], result["id"])
        self.assertTrue(item["demo"])
        self.assertEqual(item["project"], result["project"])


if __name__ == "__main__":
    unittest.main()
