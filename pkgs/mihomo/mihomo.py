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


def api(path, payload=None):
    request = urllib.request.Request(
        API + path,
        data=json.dumps(payload).encode() if payload is not None else None,
        method="PUT" if payload is not None else "GET",
        headers={"Content-Type": "application/json"},
    )
    with HTTP.open(request, timeout=3) as response:
        body = response.read()
        return json.loads(body) if body else None


def check_startup():
    deadline = time.monotonic() + 30
    while True:
        try:
            config = api("/configs")
            if not config.get("tun", {}).get("enable"):
                raise RuntimeError("desktop TUN is disabled")
            proxies = api("/proxies")["proxies"]
            if not isinstance(proxies, dict) or not proxies:
                raise RuntimeError("Mihomo has no loaded proxies")
            return
        except urllib.error.HTTPError:
            raise RuntimeError("Mihomo controller rejected startup check") from None
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            if time.monotonic() >= deadline:
                raise RuntimeError("Mihomo controller did not become ready") from None
            time.sleep(0.5)


def restart():
    subprocess.run(
        ["systemctl", "restart", "mihomo.service"],
        check=True,
        capture_output=True,
        timeout=45,
    )


def update(source):
    try:
        old_proxies = api("/proxies")["proxies"] if CONFIG.exists() else {}
    except (OSError, ValueError):
        old_proxies = {}
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
        if previous == content and old_proxies:
            print("Mihomo config is already current.")
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
            check_startup()
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
