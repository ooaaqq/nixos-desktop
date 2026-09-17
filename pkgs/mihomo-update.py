"""Manually install a private subscription; retain working state on failure."""

import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request

import yaml


STATE = Path("/var/lib/mihomo-subscription")
CONFIG = STATE / "config.yaml"
URL_FILE = Path("/run/secrets/mihomo-subscription-url")
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


def wait_ready():
    for _ in range(30):
        try:
            config = api("/configs")
            if not config.get("tun", {}).get("enable"):
                raise RuntimeError("desktop TUN is disabled")
            return api("/proxies")["proxies"]
        except Exception:
            time.sleep(0.5)
    raise RuntimeError("Mihomo controller did not become ready")


def restore_choices(choices, proxies):
    for name, selected in choices.items():
        if selected in proxies.get(name, {}).get("all", []):
            api("/proxies/" + urllib.parse.quote(name, safe=""), {"name": selected})


def restart():
    subprocess.run(["systemctl", "restart", "mihomo.service"], check=True,
                   capture_output=True, timeout=45)


def update():
    url = URL_FILE.read_text().strip()
    if urllib.parse.urlsplit(url).scheme != "https":
        raise RuntimeError("subscription must use HTTPS")
    try:
        old_proxies = api("/proxies")["proxies"] if CONFIG.exists() else {}
    except (OSError, ValueError):
        old_proxies = {}
    choices = {k: v["now"] for k, v in old_proxies.items()
               if v.get("type") == "Selector" and "now" in v}
    with tempfile.TemporaryDirectory(prefix=".update-", dir=STATE) as tmp:
        candidate = Path(tmp) / "config.yaml"
        # Never place the private URL in process arguments or diagnostic output.
        with HTTP.open(url, timeout=45) as response:
            if urllib.parse.urlsplit(response.url).scheme != "https":
                raise RuntimeError("subscription redirected outside HTTPS")
            content = response.read(4 * 1024 * 1024 + 1)
        if len(content) > 4 * 1024 * 1024:
            raise RuntimeError("subscription is too large")
        data = yaml.safe_load(content)
        if not isinstance(data, dict) or not data.get("proxies"):
            raise RuntimeError("subscription has no nodes")
        if (data.get("external-controller") != "127.0.0.1:9090"
                or data.get("dns", {}).get("listen") != "127.0.0.1:53"
                or data.get("tun", {}).get("enable") is not True
                or data.get("allow-lan") is not False):
            raise RuntimeError("subscription is missing desktop networking settings")
        candidate.write_bytes(content)
        candidate.chmod(0o600)
        # Test against cached rules without modifying the running core's files.
        cache = Path("/var/lib/private/mihomo/ruleset")
        if cache.is_dir():
            shutil.copytree(cache, Path(tmp) / "ruleset")
        result = subprocess.run(["mihomo", "-t", "-d", tmp, "-f", str(candidate)],
                                capture_output=True, timeout=120)
        if result.returncode:
            raise RuntimeError("Mihomo rejected subscription; active configuration retained")
        previous = CONFIG.read_bytes() if CONFIG.exists() else None
        if previous == content and old_proxies:
            print("Mihomo subscription is already current.")
            return
        if previous is not None:
            backup = STATE / "previous.yaml"
            backup.write_bytes(previous)
            backup.chmod(0o600)
        os.replace(candidate, CONFIG)
        try:
            restart()
            restore_choices(choices, wait_ready())
        except Exception:
            if previous is not None:
                candidate.write_bytes(previous)
                candidate.chmod(0o600)
                os.replace(candidate, CONFIG)
                restart()
                restore_choices(choices, wait_ready())
                raise RuntimeError("update failed; previous configuration restored") from None
            raise RuntimeError("initial configuration could not start") from None
        print(f"Mihomo updated: {len(data['proxies'])} nodes; existing selections retained.")


def main():
    if os.geteuid() != 0:
        raise SystemExit("Run: sudo mihomo-update")
    os.umask(0o077)
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (STATE / ".update.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            update()
        except Exception as error:
            # Network exceptions may contain the secret subscription URL.
            message = str(error) if isinstance(error, RuntimeError) else type(error).__name__
            raise SystemExit(f"Mihomo update failed: {message}") from None


if __name__ == "__main__":
    main()
