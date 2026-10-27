import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, call, patch
import urllib.error

import yaml


spec = importlib.util.spec_from_file_location(
    "updater", Path(__file__).with_name("mihomo.py")
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
        self.source = self.state / "source.yaml"
        for name, value in (("STATE", self.state), ("CONFIG", self.config)):
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
        self.api = {
            "proxies": {
                "GOOGLE": {"type": "Selector", "now": "HK", "all": ["HK", "US"]},
                "OPENAI": {"type": "Selector", "now": "MY", "all": ["MY", "US"]},
            }
        }

    def write_source(self):
        self.source.write_bytes(yaml.safe_dump(self.data).encode())
        return self.source

    def test_invalid_local_config_never_restarts_or_replaces(self):
        self.data["tun"]["enable"] = False
        with (
            patch.object(updater, "api", return_value=self.api),
            patch.object(updater, "restart") as restart,
        ):
            with self.assertRaisesRegex(RuntimeError, "desktop networking"):
                updater.update(self.write_source())
        restart.assert_not_called()
        self.assertEqual(self.config.read_bytes(), self.original)

    def test_core_validation_failure_keeps_config(self):
        with (
            patch.object(updater, "api", return_value=self.api),
            patch.object(updater.subprocess, "run", return_value=Mock(returncode=1)),
            patch.object(updater, "restart") as restart,
        ):
            with self.assertRaisesRegex(RuntimeError, "rejected"):
                updater.update(self.write_source())
        restart.assert_not_called()
        self.assertEqual(self.config.read_bytes(), self.original)

    def test_failed_start_rolls_back(self):
        with (
            patch.object(updater, "api", return_value=self.api),
            patch.object(updater.subprocess, "run", return_value=Mock(returncode=0)),
            patch.object(
                updater, "restart", side_effect=[RuntimeError("failed"), None]
            ) as restart,
        ):
            with self.assertRaisesRegex(
                RuntimeError, "previous configuration restored"
            ):
                updater.update(self.write_source())
        self.assertEqual(restart.call_count, 2)
        self.assertEqual(self.config.read_bytes(), self.original)

    def test_success_installs_private_config(self):
        content = yaml.safe_dump(self.data).encode()
        with (
            patch.object(updater, "api", return_value=self.api),
            patch.object(updater.subprocess, "run", return_value=Mock(returncode=0)),
            patch.object(updater, "restart"),
        ):
            updater.update(self.write_source())
        self.assertEqual(self.config.read_bytes(), content)
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)

    def test_unchanged_config_skips_restart_only_when_ready(self):
        source = self.write_source()
        self.config.write_bytes(source.read_bytes())
        with (
            patch.object(
                updater,
                "api",
                side_effect=[{"tun": {"enable": True}}, self.api],
            ),
            patch.object(updater.subprocess, "run") as run,
            patch.object(updater, "restart") as restart,
        ):
            updater.update(source)
        run.assert_not_called()
        restart.assert_not_called()

    def test_unchanged_config_recovers_unready_service(self):
        source = self.write_source()
        content = source.read_bytes()
        self.config.write_bytes(content)
        for responses in (
            [urllib.error.URLError("stopped")],
            [{"tun": {"enable": False}}],
            [{"tun": {"enable": True}}, {"proxies": {}}],
        ):
            with (
                self.subTest(responses=responses),
                patch.object(updater, "api", side_effect=responses),
                patch.object(
                    updater.subprocess, "run", return_value=Mock(returncode=0)
                ),
                patch.object(updater, "restart") as restart,
            ):
                updater.update(source)
                restart.assert_called_once_with()
                self.assertEqual(self.config.read_bytes(), content)


class StartupTests(unittest.TestCase):
    def test_waits_for_controller_and_loaded_proxies(self):
        with (
            patch.object(
                updater,
                "api",
                side_effect=[
                    urllib.error.URLError("starting"),
                    {"tun": {"enable": True}},
                    {"proxies": {"node": {"type": "Direct"}}},
                ],
            ) as api,
            patch.object(updater.time, "sleep") as sleep,
        ):
            updater.wait_for_startup()
        self.assertEqual(
            api.call_args_list, [call("/configs"), call("/configs"), call("/proxies")]
        )
        sleep.assert_called_once_with(0.5)

    def test_controller_can_respond_before_tun_and_proxies_are_ready(self):
        with (
            patch.object(
                updater,
                "api",
                side_effect=[
                    {"tun": {"enable": False}},
                    {"tun": {"enable": True}},
                    {"proxies": {}},
                    {"tun": {"enable": True}},
                    {"proxies": {"node": {"type": "Direct"}}},
                ],
            ) as api,
            patch.object(updater.time, "sleep") as sleep,
        ):
            updater.wait_for_startup()
        self.assertEqual(
            api.call_args_list,
            [
                call("/configs"),
                call("/configs"),
                call("/proxies"),
                call("/configs"),
                call("/proxies"),
            ],
        )
        self.assertEqual(sleep.call_args_list, [call(0.5), call(0.5)])

    def test_disabled_tun_fails_at_deadline(self):
        with (
            patch.object(updater, "api", return_value={"tun": {"enable": False}}),
            patch.object(updater.time, "monotonic", side_effect=[0, 30]),
            patch.object(updater.time, "sleep") as sleep,
        ):
            with self.assertRaisesRegex(RuntimeError, "TUN is disabled"):
                updater.wait_for_startup()
        sleep.assert_not_called()

    def test_empty_proxies_fail_at_deadline(self):
        with (
            patch.object(
                updater,
                "api",
                side_effect=[{"tun": {"enable": True}}, {"proxies": {}}],
            ),
            patch.object(updater.time, "monotonic", side_effect=[0, 30]),
            patch.object(updater.time, "sleep") as sleep,
        ):
            with self.assertRaisesRegex(RuntimeError, "no loaded proxies"):
                updater.wait_for_startup()
        sleep.assert_not_called()

    def test_rejected_controller_request_fails_without_retry(self):
        error = urllib.error.HTTPError(updater.API, 403, "Forbidden", {}, None)
        self.addCleanup(error.close)
        with (
            patch.object(
                updater,
                "api",
                side_effect=error,
            ),
            patch.object(updater.time, "sleep") as sleep,
        ):
            with self.assertRaisesRegex(RuntimeError, "rejected startup check"):
                updater.wait_for_startup()
        sleep.assert_not_called()

    def test_controller_startup_has_a_deadline(self):
        with (
            patch.object(updater, "api", side_effect=urllib.error.URLError("starting")),
            patch.object(updater.time, "monotonic", side_effect=[0, 30]),
            patch.object(updater.time, "sleep") as sleep,
        ):
            with self.assertRaisesRegex(RuntimeError, "did not become ready"):
                updater.wait_for_startup()
        sleep.assert_not_called()


if __name__ == "__main__":
    unittest.main()
