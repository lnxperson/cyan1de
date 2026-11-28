#!/usr/bin/env python3
"""Show the running game as Discord Rich Presence using local RPC IPC.

The game name comes from the same metadata-based resolver used by capture
folders, so Steam, Proton, Wine and bare "exe" windows are handled without a
per-game alias list. Native Steam games are detected from their executable
paths and Steam environment too.

When possible, the helper looks up Discord's public detectable-game list and
uses the game's official application ID, which gives the correct name and icon.
Unknown games and offline machines fall back to a generic application ID.
Presence is cleared by closing the RPC socket when no game window remains.
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
import urllib.request
import uuid

HOME = os.path.expanduser("~")
CONFIG = os.path.join(HOME, ".config", "quickshell", "discord", "game-presence.conf")
CACHE_DIR = os.path.join(
    os.environ.get("XDG_CACHE_HOME") or os.path.join(HOME, ".cache"), "cyan1de")
GAME_CACHE = os.path.join(CACHE_DIR, "discord-detectable.json")
DETECTABLE_URL = "https://discord.com/api/v10/applications/detectable"
GAME_CACHE_AGE = 7 * 24 * 60 * 60
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

STEAM_CLASS = re.compile(r"steam[ _-]*app[ _-]*(\d+)", re.I)
GENERIC_EXE = {
    "steam", "steamwebhelper", "proton", "wine", "wine64", "winepreloader",
    "umu", "umurun", "lutris", "heroic", "bottles", "launcher", "updater",
    "bootstrap", "steamworks", "steamcmd", "easyanticheat", "crashhandler",
}
STEAM_ENV_KEYS = ("SteamAppId", "STEAM_APP_ID", "steam_appid", "GameID", "gameid")
DETECTABLE_INDEX = None
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
    use_game_ids = True
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
                elif key == "use_discord_game_ids":
                    use_game_ids = value.lower() not in ("0", "false", "no", "off")
    except OSError:
        pass
    return enabled, client_id, use_game_ids


def run_json(args):
    try:
        result = subprocess.run(args, stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, text=True, timeout=5)
        if result.returncode != 0:
            return None
        return json.loads(result.stdout)
    except Exception:
        return None


def iter_ancestors(pid):
    try:
        pid = int(pid)
    except Exception:
        return
    seen = set()
    while pid and pid not in seen:
        seen.add(pid)
        yield pid
        try:
            with open("/proc/%d/status" % pid, "r", encoding="utf-8",
                      errors="ignore") as fh:
                match = re.search(r"^PPid:\s*(\d+)", fh.read(), re.M)
            pid = int(match.group(1)) if match else 0
        except Exception:
            pid = 0


def game_paths(pid):
    """Return (stem, path, kind) for game executables in a process tree."""
    paths = []
    seen = set()

    def add(stem, path, kind):
        key = (stem.lower(), str(path).lower(), kind)
        if key not in seen and stem:
            seen.add(key)
            paths.append((stem, path, kind))

    for ancestor in iter_ancestors(pid):
        try:
            with open("/proc/%d/cmdline" % ancestor, "rb") as fh:
                args = [part.decode("utf-8", "ignore")
                        for part in fh.read().split(b"\0") if part]
        except OSError:
            args = []
        for arg in args:
            normalized = arg.replace("\\", "/")
            base = normalized.rsplit("/", 1)[-1]
            if base.lower().endswith(".exe") and len(base) > 4:
                add(base[:-4], arg, "exe")
            if "/steamapps/common/" in normalized.lower():
                parts = [part for part in normalized.split("/") if part]
                keys = [part.lower() for part in parts]
                if "common" in keys:
                    index = keys.index("common")
                    if index + 1 < len(parts):
                        add(parts[-1], parts[index + 1], "steam")
        try:
            target = os.readlink("/proc/%d/exe" % ancestor)
        except OSError:
            continue
        if "/steamapps/common/" in target.replace("\\", "/").lower():
            add(target.rsplit("/", 1)[-1], target, "steam")

    return paths


def steam_env_ids(pid):
    ids = []
    for ancestor in iter_ancestors(pid):
        try:
            with open("/proc/%d/environ" % ancestor, "rb") as fh:
                data = fh.read()
        except OSError:
            continue
        env = {}
        for item in data.split(b"\0"):
            if b"=" not in item:
                continue
            key, value = item.split(b"=", 1)
            env[key.decode("utf-8", "ignore")] = value.decode("utf-8", "ignore")
        for key in STEAM_ENV_KEYS:
            raw = env.get(key)
            if not raw:
                continue
            digits = re.sub(r"\D", "", raw).lstrip("0")
            if digits and len(digits) <= 10 and digits not in ids:
                ids.append(digits)
    return ids


def has_game_executable(pid):
    for stem, path, kind in game_paths(pid):
        if kind == "steam":
            return True
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
    if STEAM_CLASS.search(cls) or GAME_WINDOW.search(cls.lower()) or GAME_WINDOW.search(title.lower()):
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


def normalize(value):
    return re.sub(r"[^a-z0-9]", "", str(value or "").lower())


def load_detectable():
    try:
        age = time.time() - os.path.getmtime(GAME_CACHE)
        with open(GAME_CACHE, "r", encoding="utf-8", errors="ignore") as fh:
            cached = json.load(fh)
        if isinstance(cached, list) and (age < GAME_CACHE_AGE or cached):
            return cached
    except Exception:
        pass

    try:
        os.makedirs(CACHE_DIR, mode=0o700, exist_ok=True)
        request = urllib.request.Request(
            DETECTABLE_URL, headers={"User-Agent": "cyan1de-game-presence/1"})
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = response.read()
        games = json.loads(payload.decode("utf-8"))
        if not isinstance(games, list):
            return []
        temporary = GAME_CACHE + ".tmp"
        with open(temporary, "wb") as fh:
            fh.write(payload)
        os.replace(temporary, GAME_CACHE)
        return games
    except Exception:
        return []


def detectable_index():
    global DETECTABLE_INDEX
    if DETECTABLE_INDEX is None:
        by_name = {}
        by_exe = {}
        by_steam = {}
        for game in load_detectable():
            if not isinstance(game, dict):
                continue
            official = normalize(game.get("name"))
            for name in [game.get("name")] + list(game.get("aliases") or []):
                key = normalize(name)
                if not key:
                    continue
                # An official name beats another game's alias.
                if key == official:
                    by_name[key] = game
                else:
                    by_name.setdefault(key, game)
            for executable in game.get("executables") or []:
                if not isinstance(executable, dict):
                    continue
                key = normalize(os.path.basename(
                    str(executable.get("name") or "").replace("\\", "/")))
                if key:
                    by_exe.setdefault(key, game)
            for sku in game.get("third_party_skus") or []:
                if isinstance(sku, dict) and sku.get("distributor") == "steam":
                    appid = normalize(sku.get("id"))
                    if appid:
                        by_steam.setdefault(appid, game)
        DETECTABLE_INDEX = (by_name, by_exe, by_steam)
    return DETECTABLE_INDEX


def discord_app_for(client, name):
    by_name, by_exe, by_steam = detectable_index()
    if not (by_name or by_exe or by_steam):
        return None

    game = by_name.get(normalize(name))
    if game:
        return game

    ids = steam_env_ids(client.get("pid"))
    cls = str(client.get("class") or client.get("initialClass") or "")
    match = STEAM_CLASS.search(cls)
    if match:
        ids.append(match.group(1))
    for appid in ids:
        game = by_steam.get(normalize(appid))
        if game:
            return game

    for stem, path, kind in game_paths(client.get("pid")):
        for part in re.split(r"[\\/]", str(path)):
            found = by_name.get(normalize(part))
            if found:
                return found
        found = by_exe.get(normalize(stem))
        if found:
            return found
    return None


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

    def set_activity(self, name, started, details=None):
        activity = {
            "name": name,
            "type": 0,
            "timestamps": {"start": int(started)},
        }
        if details:
            activity["details"] = details
        return self.command("SET_ACTIVITY", {
            "pid": os.getpid(),
            "activity": activity,
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

    enabled, fallback_id, use_game_ids = read_config()
    rpc = DiscordRpc(fallback_id)
    current_name = ""
    started = 0
    last_game_seen = 0
    next_connect = 0

    try:
        while not STOP:
            enabled, configured_id, use_game_ids = read_config()
            if not enabled or not configured_id:
                rpc.close()
                current_name = ""
                started = 0
                time.sleep(POLL_SECONDS)
                continue

            client, name = current_game()
            now = time.time()

            if name:
                last_game_seen = now
                target_id = configured_id
                display_name = name
                details = name

                if use_game_ids and client is not None:
                    official = discord_app_for(client, name)
                    if official and str(official.get("id") or "").isdigit():
                        target_id = str(official["id"])
                        display_name = str(official.get("name") or name)
                        details = ""

                if display_name != current_name:
                    current_name = display_name
                    started = int(now)

                if target_id != rpc.client_id:
                    rpc.close()
                    rpc = DiscordRpc(target_id)
                    next_connect = 0

                if not rpc.connected and now >= next_connect:
                    if rpc.connect():
                        next_connect = 0
                    else:
                        next_connect = now + 5

                if rpc.connected and not rpc.set_activity(current_name, started, details):
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
