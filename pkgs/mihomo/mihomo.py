"""Mihomo startup readiness and manual local configuration installation."""

import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

import yaml


STATE = Path("/etc/mihomo")
CONFIG = STATE / "config.yaml"
API = "http://127.0.0.1:9090"
HTTP = urllib.request.build_opener(urllib.request.ProxyHandler({}))
STARTUP_TIMEOUT = 30


def api(path):
    with HTTP.open(API + path, timeout=3) as response:
        return json.load(response)


def startup_problem():
    if not api("/configs").get("tun", {}).get("enable"):
        return "desktop TUN is disabled"
    proxies = api("/proxies")["proxies"]
    if not isinstance(proxies, dict) or not proxies:
        return "Mihomo has no loaded proxies"
    return None


def wait_for_startup():
    deadline = time.monotonic() + STARTUP_TIMEOUT
    while True:
        try:
            pending = startup_problem()
            if pending is None:
                return
        except urllib.error.HTTPError:
            raise RuntimeError("Mihomo controller rejected startup check") from None
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            pending = "Mihomo controller did not become ready"
        # The controller starts before ApplyConfig has enabled TUN and loaded proxies.
        if time.monotonic() >= deadline:
            raise RuntimeError(pending) from None
        time.sleep(0.5)


def restart():
    subprocess.run(
        ["systemctl", "restart", "mihomo.service"],
        check=True,
        capture_output=True,
        timeout=STARTUP_TIMEOUT + 15,
    )


def update(source):
    with tempfile.TemporaryDirectory(prefix=".update-", dir=STATE) as tmp:
        candidate = Path(tmp) / "config.yaml"
        with source.open("rb") as stream:
            content = stream.read(4 * 1024 * 1024 + 1)
        if len(content) > 4 * 1024 * 1024:
            raise RuntimeError("local config is too large")
        data = yaml.safe_load(content)
        if not isinstance(data, dict) or not data.get("proxies"):
            raise RuntimeError("local config has no nodes")
        if (
            data.get("external-controller") != "127.0.0.1:9090"
            or data.get("dns", {}).get("listen") != "127.0.0.1:53"
            or data.get("tun", {}).get("enable") is not True
            or data.get("allow-lan") is not False
        ):
            raise RuntimeError("local config is missing desktop networking settings")
        previous = CONFIG.read_bytes() if CONFIG.exists() else None
        if previous == content:
            try:
                ready = startup_problem() is None
            except (OSError, ValueError):
                ready = False
            if ready:
                print("Mihomo config is already current and service is ready.")
                return
        candidate.write_bytes(content)
        candidate.chmod(0o600)
        # Test against cached rules without modifying the running core's files.
        cache = Path("/var/lib/private/mihomo/ruleset")
        if cache.is_dir():
            shutil.copytree(cache, Path(tmp) / "ruleset")
        result = subprocess.run(
            ["mihomo", "-t", "-d", tmp, "-f", str(candidate)],
            capture_output=True,
            timeout=120,
        )
        if result.returncode:
            raise RuntimeError(
                "Mihomo rejected local config; active configuration retained"
            )
        os.replace(candidate, CONFIG)
        try:
            restart()
        except Exception:
            if previous is not None:
                candidate.write_bytes(previous)
                candidate.chmod(0o600)
                os.replace(candidate, CONFIG)
                restart()
                raise RuntimeError(
                    "update failed; previous configuration restored"
                ) from None
            raise RuntimeError("initial configuration could not start") from None
        print(
            f"Mihomo updated: {len(data['proxies'])} nodes; selections managed by Mihomo."
        )


def main():
    if sys.argv[1:] == ["ready"]:
        try:
            wait_for_startup()
        except Exception as error:
            message = (
                str(error) if isinstance(error, RuntimeError) else type(error).__name__
            )
            raise SystemExit(f"Mihomo startup failed: {message}") from None
        return
    if os.geteuid() != 0:
        raise SystemExit("Run: sudo mihomo-update /absolute/path/to/desktop.yaml")
    if (
        len(sys.argv) != 3
        or sys.argv[1] != "update"
        or not Path(sys.argv[2]).is_absolute()
    ):
        raise SystemExit("Run: sudo mihomo-update /absolute/path/to/desktop.yaml")
    os.umask(0o077)
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (STATE / ".update.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            update(Path(sys.argv[2]))
        except Exception as error:
            # YAML and filesystem exceptions may contain sensitive input.
            message = (
                str(error) if isinstance(error, RuntimeError) else type(error).__name__
            )
            raise SystemExit(f"Mihomo update failed: {message}") from None


if __name__ == "__main__":
    main()
