r"""Install the patientx/comfy-kitchen RDNA2 HIP wheel from its latest GitHub release.

Run with the python_env interpreter, from the comfyui-rocm folder:
    .\python_env\python.exe install_kitchen_rdna2.py

Exit code 0 = fork installed or already current, 1 = failed (whatever comfy-kitchen
was installed before stays in place).
"""
import importlib.metadata as md
import json
import os
import subprocess
import sys
import urllib.request

API = "https://api.github.com/repos/patientx/comfy-kitchen/releases/latest"
MARKER = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".kitchen_rdna2_asset")
UA = "comfyui-rocm"


def fetch_release():
    req = urllib.request.Request(
        API, headers={"User-Agent": UA, "Accept": "application/vnd.github+json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except Exception as first:
        # Some networks break Python's TLS revocation/cert handling; curl copes.
        try:
            out = subprocess.run(
                ["curl.exe", "-sL", "--ssl-no-revoke", "-H", "User-Agent: " + UA, API],
                capture_output=True, check=True, timeout=60,
            ).stdout
            return json.loads(out)
        except Exception:
            raise first


def pick_wheel(release):
    wheels = [a for a in release.get("assets", []) if a.get("name", "").endswith(".whl")]
    if not wheels:
        raise RuntimeError("the latest release has no .whl asset")
    wheels.sort(key=lambda a: "win_amd64" not in a["name"])
    return wheels[0]


def main():
    try:
        asset = pick_wheel(fetch_release())
    except Exception as e:
        print(f"[!] comfy-kitchen fork: could not read the latest release: {e}")
        return 1

    # comfy_kitchen-<version>-<python tag>-<abi tag>-<platform>.whl
    version = asset["name"].split("-")[1]
    stamp = str(asset["id"])

    try:
        installed = md.version("comfy-kitchen")
    except md.PackageNotFoundError:
        installed = None
    try:
        with open(MARKER, "r", encoding="utf-8") as f:
            last = f.read().strip()
    except OSError:
        last = ""

    if installed == version and last == stamp:
        print(f"[*] comfy-kitchen fork {version} is up to date.")
        return 0

    print(f"[*] Installing comfy-kitchen fork {version} ({asset['name']}) ...")
    # --no-deps: the wheel must not pull in or replace torch.
    r = subprocess.run([
        sys.executable, "-m", "pip", "install", "--force-reinstall", "--no-deps",
        "--quiet", "--no-warn-script-location", asset["browser_download_url"],
    ])
    if r.returncode != 0:
        print("[!] comfy-kitchen fork: pip install failed.")
        return 1

    with open(MARKER, "w", encoding="utf-8") as f:
        f.write(stamp)
    print(f"[*] comfy-kitchen fork {version} installed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
