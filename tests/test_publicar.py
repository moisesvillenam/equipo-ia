"""Publicación contra repositorios bare locales, sin cuentas ni red."""
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class PublishTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="equipo-publicar-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / "proyecto con espacios"
        self.repo.mkdir()
        self.remote = self.base / "remoto.git"
        self.env = dict(os.environ, EQUIPO_STATE_DIR=str(self.base / "estado"),
                        EQUIPO_TEST_CMD="true", EQUIPO_NPM_CI="no",
                        EQUIPO_CONFIG=str(self.base / "sin-config"),
                        GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1",
                        EQUIPO_IA_SCRIPT=str(ROOT / "equipo-ia.sh"))
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.com")
        (self.repo / "archivo.txt").write_text("primero\n")
        self.git("add", ".")
        self.git("commit", "-qm", "Inicial")
        self.git("init", "--bare", "-q", str(self.remote))
        self.git("remote", "add", "origin", str(self.remote))

    def git(self, *args, cwd=None, check=True):
        return subprocess.run(["git", *args], cwd=cwd or self.repo, env=self.env,
                              text=True, capture_output=True, check=check).stdout.strip()

    def publish(self, answer="PUBLICAR\n", args=(), console=False):
        script = ROOT / ("bin/equipo" if console else "equipo-publicar.sh")
        return subprocess.run(["bash", str(script), *args], cwd=self.repo, env=self.env,
                              input=answer, text=True, capture_output=True, timeout=20)

    def refs(self):
        return self.git("for-each-ref", "--format=%(refname)", cwd=self.remote)

    def test_publishes_exact_commit_and_reports_success(self):
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.git("rev-parse", "HEAD"),
                         self.git("rev-parse", "main", cwd=self.remote))
        self.assertEqual(self.refs(), "refs/heads/main")
        reports = list((self.base / "estado").glob("publicacion_*"))
        self.assertEqual((reports[0] / "estado.txt").read_text(), "PUBLICADO\n")

    def test_cancel_and_check_only_do_not_push(self):
        for answer, args in [("no\n", ()), ("", ()), ("PUBLICAR\n", ("--comprobar",))]:
            result = self.publish(answer, args)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.refs(), "")

    def test_dirty_tree_is_rejected(self):
        (self.repo / "pendiente.txt").write_text("pendiente")
        result = self.publish()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("pendientes", result.stderr)
        self.assertEqual(self.refs(), "")

    def test_failed_or_unavailable_tests_block_push(self):
        for command in ("false", ""):
            self.env["EQUIPO_TEST_CMD"] = command
            result = self.publish()
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(self.refs(), "")

    def test_tests_cannot_change_the_commit_or_tree(self):
        for command in ("touch inesperado.txt", "git commit --allow-empty -qm cambiado"):
            self.env["EQUIPO_TEST_CMD"] = command
            result = self.publish()
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(self.refs(), "")
            (self.repo / "inesperado.txt").unlink(missing_ok=True)

    def test_changed_destination_is_rejected(self):
        self.env["EQUIPO_TEST_CMD"] = "git remote set-url origin otro-remoto"
        result = self.publish()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("destino cambió", result.stderr)
        self.assertEqual(self.refs(), "")

    def test_missing_remote_and_detached_head_are_rejected(self):
        self.git("remote", "remove", "origin")
        self.assertNotEqual(self.publish().returncode, 0)
        self.git("remote", "add", "origin", str(self.remote))
        self.git("checkout", "--detach", "-q")
        self.assertNotEqual(self.publish().returncode, 0)
        self.assertEqual(self.refs(), "")

    def test_respects_upstream_branch(self):
        self.git("push", "-u", "origin", "main:otra-rama")
        self.git("commit", "--allow-empty", "-qm", "Segundo")
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.refs(), "refs/heads/otra-rama")
        self.assertEqual(self.git("rev-parse", "HEAD"),
                         self.git("rev-parse", "otra-rama", cwd=self.remote))

    def test_pushurl_is_used_and_multiple_destinations_rejected(self):
        self.git("remote", "set-url", "origin", str(self.base / "no-existe"))
        self.git("remote", "set-url", "--push", "origin", str(self.remote))
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.git("remote", "set-url", "--add", "--push", "origin", "otro-destino")
        self.assertNotEqual(self.publish().returncode, 0)

    def test_remote_divergence_is_not_overwritten(self):
        self.git("push", "origin", "main")
        self.git("commit", "--allow-empty", "-qm", "Remoto")
        self.git("push", "origin", "main")
        remote_head = self.git("rev-parse", "main", cwd=self.remote)
        self.git("reset", "--hard", "HEAD~1")
        self.git("commit", "--allow-empty", "-qm", "Local divergente")
        result = self.publish()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git("rev-parse", "main", cwd=self.remote), remote_head)

    def test_ignores_configured_extra_refs_mirror_and_tags(self):
        self.git("branch", "privada")
        self.git("tag", "-am", "Etiqueta", "v-test")
        self.git("config", "push.followTags", "true")
        self.git("config", "remote.origin.push", "+refs/heads/*:refs/heads/*")
        self.git("config", "remote.origin.mirror", "true")
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.refs(), "refs/heads/main")

    def test_credentials_in_url_are_not_printed(self):
        self.git("remote", "set-url", "origin", "https://usuario:password@example.com/repo.git")
        result = self.publish()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("password", result.stdout + result.stderr)

    def test_console_routes_publish_and_unknown_commands(self):
        result = self.publish("/publicar comprobar\n/no-existe\n/salir\n", console=True)
        self.assertIn("Pruebas aprobadas", result.stdout)
        self.assertIn("Comando desconocido", result.stdout)
        self.assertEqual(self.refs(), "")
        result = self.publish("/publicar\nPUBLICAR\n/salir\n", console=True)
        self.assertIn("Commit publicado", result.stdout)
        self.assertEqual(self.refs(), "refs/heads/main")

    @unittest.skipUnless(shutil.which("node") and shutil.which("npm"), "requiere Node/npm")
    def test_default_npm_install_policy_uses_existing_dependencies(self):
        (self.repo / "package.json").write_text('{"scripts":{"test":"node -e \'process.exit(0)\'"}}')
        (self.repo / "package-lock.json").write_text('{}')
        self.git("add", ".")
        self.git("commit", "-qm", "Pruebas npm")
        self.env.update(EQUIPO_TEST_CMD="", EQUIPO_NPM_CI="preguntar")
        result = self.publish(args=("--comprobar",))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.refs(), "")

    def test_installed_console_finds_publisher(self):
        prefix = self.base / "instalacion local"
        subprocess.run(["bash", str(ROOT / "install.sh"), "--prefix", str(prefix)],
                       env=self.env, check=True, capture_output=True)
        env = dict(self.env)
        env.pop("EQUIPO_IA_SCRIPT")
        result = subprocess.run([str(prefix / "bin/equipo")], cwd=self.repo, env=env,
                                input="/publicar\nPUBLICAR\n/salir\n", text=True,
                                capture_output=True, timeout=20)
        self.assertIn("Commit publicado", result.stdout)
        self.assertEqual(self.refs(), "refs/heads/main")


if __name__ == "__main__":
    unittest.main()
