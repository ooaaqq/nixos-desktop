import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

import yaml


spec = importlib.util.spec_from_file_location(
    "updater", Path(__file__).resolve().parents[1] / "pkgs/mihomo-update.py"
)
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state = Path(self.temp.name)
        self.config = self.state / "config.yaml"
        self.original = b"original protected configuration"
        self.config.write_bytes(self.original)
        self.url = self.state / "url"
        self.url.write_text("https://example.com/private/desktop.yaml")
        for name, value in (("STATE", self.state), ("CONFIG", self.config),
                            ("URL_FILE", self.url)):
            context = patch.object(updater, name, value)
            context.start()
            self.addCleanup(context.stop)
        self.data = {
            "proxies": [{"name": "node", "type": "ss"}],
            "external-controller": "127.0.0.1:9090",
            "dns": {"listen": "127.0.0.1:53"},
            "tun": {"enable": True},
            "allow-lan": False,
        }
        self.api = {"proxies": {
            "GOOGLE": {"type": "Selector", "now": "HK", "all": ["HK", "US"]},
            "OPENAI": {"type": "Selector", "now": "MY", "all": ["MY", "US"]},
        }}

    def response(self, content):
        response = io.BytesIO(content)
        response.url = self.url.read_text()
        return response

    def test_invalid_subscription_never_restarts_or_replaces(self):
        self.data["tun"]["enable"] = False
        with patch.object(updater, "api", return_value=self.api), \
                patch.object(updater.HTTP, "open", return_value=self.response(yaml.safe_dump(self.data).encode())), \
                patch.object(updater, "restart") as restart:
            with self.assertRaisesRegex(RuntimeError, "desktop networking"):
                updater.update()
        restart.assert_not_called()
        self.assertEqual(self.config.read_bytes(), self.original)

    def test_core_validation_failure_keeps_config(self):
        with patch.object(updater, "api", return_value=self.api), \
                patch.object(updater.HTTP, "open", return_value=self.response(yaml.safe_dump(self.data).encode())), \
                patch.object(updater.subprocess, "run", return_value=Mock(returncode=1)), \
                patch.object(updater, "restart") as restart:
            with self.assertRaisesRegex(RuntimeError, "rejected"):
                updater.update()
        restart.assert_not_called()
        self.assertEqual(self.config.read_bytes(), self.original)

    def test_failed_start_rolls_back_and_restores_independent_choices(self):
        with patch.object(updater, "api", return_value=self.api), \
                patch.object(updater.HTTP, "open", return_value=self.response(yaml.safe_dump(self.data).encode())), \
                patch.object(updater.subprocess, "run", return_value=Mock(returncode=0)), \
                patch.object(updater, "restart", side_effect=[RuntimeError("failed"), None]) as restart, \
                patch.object(updater, "wait_ready", return_value=self.api["proxies"]), \
                patch.object(updater, "restore_choices") as restore:
            with self.assertRaisesRegex(RuntimeError, "previous configuration restored"):
                updater.update()
        self.assertEqual(restart.call_count, 2)
        self.assertEqual(self.config.read_bytes(), self.original)
        restore.assert_called_once_with({"GOOGLE": "HK", "OPENAI": "MY"}, self.api["proxies"])

    def test_success_keeps_backup_and_choices(self):
        content = yaml.safe_dump(self.data).encode()
        with patch.object(updater, "api", return_value=self.api), \
                patch.object(updater.HTTP, "open", return_value=self.response(content)), \
                patch.object(updater.subprocess, "run", return_value=Mock(returncode=0)), \
                patch.object(updater, "restart"), \
                patch.object(updater, "wait_ready", return_value=self.api["proxies"]), \
                patch.object(updater, "restore_choices") as restore:
            updater.update()
        self.assertEqual(self.config.read_bytes(), content)
        self.assertEqual((self.state / "previous.yaml").read_bytes(), self.original)
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)
        restore.assert_called_once_with({"GOOGLE": "HK", "OPENAI": "MY"}, self.api["proxies"])


if __name__ == "__main__":
    unittest.main()
