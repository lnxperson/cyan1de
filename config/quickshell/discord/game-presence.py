#!/usr/bin/env python3
"""Show the running game as Discord activity using local RPC IPC.

The game name comes from the same metadata-based resolver used by capture
folders, so Steam, Proton, Wine and bare "exe" windows are all handled without
a per-game alias list. Presence is cleared by closing the RPC socket when no
game window remains.
"""

import fcntl
import json
import os
import re
import signal
import socket
import struct
import subprocess
import sys
import time
import uuid

HOME = os.path.expanduser("~")
CONFIG = os.path.join(HOME, ".config", "quickshell", "discord", "game-presence.conf")
DEFAULT_CLIENT_ID = "1062648118375616594"
POLL_SECONDS = 2

# Known desktop apps must never be mistaken for a game because of a title such
# as a folder named "Geometry Dash" in Nautilus.
NON_GAME = re.compile(
    r"^(org\.)?(gnome\.)?(nautilus|nemo|thunar|pcmanfm|dolphin|caja|"
    r"firefox|zen|chromium|google-chrome|chrome|brave|vivaldi|"
    r"alacritty|kitty|konsole|gnome-terminal|xterm|wezterm|foot|"
    r"discord|telegram|signal|whatsapp|slack|code|gedit|texteditor)$",
    re.I,
)

GAME_WINDOW = re.compile(
    r"^(steam[ _-]*app[ _-]*\d+|"
    r"lutris|heroic|bottles|wine|wine64|proton|dosbox|retroarch|"
    r"rpcs3|yuzu|ryujinx|pcsx2|dolphin|citra|ppsspp|duckstation|"
    r"melonds|mgba|geometrydash|geometry dash|minecraft|terraria|"
    r"balatro|stardew valley|osu!?|roblox|exe)$",
    re.I,
)

GENERIC_EXE = {
    "steam", "steamwebhelper", "proton", "wine", "wine64", "winepreloader",
    "umu", "umurun", "lutris", "heroic", "bottles", "launcher", "updater",
    "bootstrap", "steamworks", "steamcmd", "easyanticheat", "crashhandler",
}

STOP = False


def stop(signum, frame):
    global STOP
    STOP = True


def runtime_dir():
    base = os.environ.get("XDG_RUNTIME_DIR") or os.path.join("/tmp", "cyan1de-" + str(os.getuid()))
    path = os.path.join(base, "cyan1de")
    try:
        os.makedirs(path, mode=0o700, exist_ok=True)
    except OSError:
        pass
    return path


def read_config():
    enabled = True
    client_id = DEFAULT_CLIENT_ID
    try:
        with open(CONFIG, "r", encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = (part.strip() for part in line.split("=", 1))
                if key == "enabled":
                    enabled = value.lower() not in ("0", "false", "no", "off")
                elif key == "client_id" and value.isdigit():
                    client_id = value
    except OSError:
        pass
    return enabled, client_id


def run_json(args):
    try:
        result = subprocess.run(args, stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, text=True, timeout=5)
        if result.returncode != 0:
            return None
        return json.loads(result.stdout)
    except Exception:
        return None


def exe_paths(pid):
    try:
        pid = int(pid)
    except Exception:
        return []
    paths = []
    seen = set()
    for _ in range(16):
        if not pid or pid in seen:
            break
        seen.add(pid)
        try:
            with open("/proc/%d/cmdline" % pid, "rb") as fh:
                args = [part.decode("utf-8", "ignore")
                        for part in fh.read().split(b"\0") if part]
        except OSError:
            args = []
        for arg in args:
            base = re.split(r"[\\/]", arg)[-1]
            if base.lower().endswith(".exe") and len(base) > 4:
                paths.append((base[:-4], arg))
        try:
            with open("/proc/%d/status" % pid, "r", encoding="utf-8",
                      errors="ignore") as fh:
                match = re.search(r"^PPid:\s*(\d+)", fh.read(), re.M)
            pid = int(match.group(1)) if match else 0
        except Exception:
            pid = 0
    return paths


def has_game_executable(pid):
    for stem, path in exe_paths(pid):
        key = re.sub(r"[^a-z0-9]", "", stem.lower())
        if key in GENERIC_EXE or key in {"game", "main", "app", "bin"}:
            continue
        if "anti cheat" in key or "anticheat" in key or "launcher" in key:
            continue
        return True
    return False


def client_is_game(client):
    if not isinstance(client, dict) or client.get("hidden"):
        return False
    cls = str(client.get("class") or client.get("initialClass") or "")
    title = str(client.get("title") or "")
    if NON_GAME.search(cls.lower()):
        return False
    if GAME_WINDOW.search(cls.lower()) or GAME_WINDOW.search(title.lower()):
        return True
    return has_game_executable(client.get("pid"))


def game_name_for(client):
    address = str(client.get("address") or "")
    pid = str(client.get("pid") or "")
    selector = "address:" + address if address else "pid:" + pid
    script = 'source "$HOME/.config/quickshell/capture/common.sh"; capture_app_name "$1"'
    try:
        result = subprocess.run(["bash", "-c", script, "bash", selector],
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                text=True, timeout=8)
    except Exception:
        return ""
    if result.returncode != 0:
        return ""
    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    return lines[-1] if lines else ""


def current_game():
    clients = run_json(["hyprctl", "clients", "-j"]) or []
    candidates = [client for client in clients if client_is_game(client)]
    if not candidates:
        return None, ""

    def priority(client):
        try:
            focus = int(client.get("focusHistoryID", 999))
        except Exception:
            focus = 999
        return (0 if client.get("fullscreen") else 1, focus)

    client = sorted(candidates, key=priority)[0]
    return client, game_name_for(client)


class DiscordRpc:
    def __init__(self, client_id):
        self.client_id = client_id
        self.sock = None

    @property
    def connected(self):
        return self.sock is not None

    def socket_paths(self):
        base = os.environ.get("XDG_RUNTIME_DIR") or os.path.join("/run/user", str(os.getuid()))
        return [os.path.join(base, "discord-ipc-%d" % i) for i in range(10)]

    def connect(self):
        sock = None
        for path in self.socket_paths():
            try:
                candidate = socket.socket(socket.AF_UNIX)
                candidate.connect(path)
                sock = candidate
                break
            except OSError:
                try:
                    candidate.close()
                except Exception:
                    pass
        if sock is None:
            return False
        sock.settimeout(2)
        self.sock = sock
        self._write_frame(0, {"v": 1, "client_id": self.client_id})
        try:
            # Discord ignores commands sent before the handshake reply.
            self._read_frame()
        except Exception:
            self.close()
            return False
        return True

    def _write_frame(self, opcode, payload):
        data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.sock.sendall(struct.pack("<II", opcode, len(data)) + data)

    def _recv_exact(self, length):
        chunks = []
        remaining = length
        while remaining:
            chunk = self.sock.recv(remaining)
            if not chunk:
                raise OSError("Discord IPC closed")
            chunks.append(chunk)
            remaining -= len(chunk)
        return b"".join(chunks)

    def _read_frame(self):
        header = self._recv_exact(8)
        opcode, length = struct.unpack("<II", header)
        body = self._recv_exact(length) if length else b""
        payload = json.loads(body.decode("utf-8")) if body else {}
        return opcode, payload

    def command(self, name, args):
        nonce = str(uuid.uuid4())
        self._write_frame(1, {"cmd": name, "args": args, "nonce": nonce})
        deadline = time.time() + 3
        while time.time() < deadline:
            try:
                _, payload = self._read_frame()
            except Exception:
                return False
            if payload.get("nonce") == nonce:
                return payload.get("evt") != "ERROR"
        return False

    def set_activity(self, name, started):
        return self.command("SET_ACTIVITY", {
            "pid": os.getpid(),
            "activity": {
                "name": name,
                "type": 0,
                "timestamps": {"start": int(started)},
            },
        })

    def close(self):
        if self.sock is not None:
            try:
                self.sock.close()
            except OSError:
                pass
            self.sock = None


def acquire_lock():
    path = os.path.join(runtime_dir(), "discord-game-presence.lock")
    fd = os.open(path, os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(fd)
        return None
    return fd


def main():
    lock = acquire_lock()
    if lock is None:
        return 0

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    enabled, client_id = read_config()
    rpc = DiscordRpc(client_id)
    current_name = ""
    started = 0
    last_game_seen = 0
    next_connect = 0

    try:
        while not STOP:
            enabled, configured_id = read_config()
            if not enabled or not configured_id:
                rpc.close()
                current_name = ""
                started = 0
                time.sleep(POLL_SECONDS)
                continue

            if configured_id != rpc.client_id:
                rpc.close()
                rpc = DiscordRpc(configured_id)
                next_connect = 0

            client, name = current_game()
            now = time.time()

            if name:
                last_game_seen = now
                if name != current_name:
                    current_name = name
                    started = int(now)

                if not rpc.connected and now >= next_connect:
                    if rpc.connect():
                        next_connect = 0
                    else:
                        next_connect = now + 5

                if rpc.connected and not rpc.set_activity(current_name, started):
                    rpc.close()
                    next_connect = now + 5
            elif current_name and now - last_game_seen > 3:
                rpc.close()
                current_name = ""
                started = 0

            time.sleep(POLL_SECONDS)
    finally:
        rpc.close()
        os.close(lock)

    return 0


if __name__ == "__main__":
    sys.exit(main())
