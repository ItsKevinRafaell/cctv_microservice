#!/usr/bin/env python3
"""
Lightweight cross-platform streaming helper for the CCTV stack.

It shells out to ffmpeg to capture from the local webcam (or a custom source)
and pushes the stream to MediaMTX running on the central laptop.
"""

from __future__ import annotations

import argparse
import os
import platform
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional


ROOT = Path(__file__).resolve().parent


def load_env() -> Dict[str, str]:
    env_path = ROOT / ".env"
    values: Dict[str, str] = {}
    if not env_path.exists():
        return values

    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def env_bool(env: Dict[str, str], key: str, default: bool = False) -> bool:
    val = env.get(key)
    if val is None:
        return default
    return val.lower() in {"1", "true", "yes", "on"}


def env_int(env: Dict[str, str], key: str, default: Optional[int]) -> Optional[int]:
    val = env.get(key)
    if not val:
        return default
    try:
        return int(val)
    except ValueError:
        print(f"[warn] Unable to parse integer for {key}={val!r}, using {default}", file=sys.stderr)
        return default


def resolve_ffmpeg(explicit: Optional[str], env: Dict[str, str]) -> str:
    candidates: List[str] = []
    if explicit:
        candidates.append(explicit)
    if env.get("FFMPEG_PATH"):
        candidates.append(env["FFMPEG_PATH"])

    # Local bin override
    if platform.system() == "Windows":
        candidates.append(str(ROOT / "bin" / "ffmpeg.exe"))
    candidates.append(str(ROOT / "bin" / "ffmpeg"))

    # PATH lookup (last resort)
    candidates.append("ffmpeg")

    for candidate in candidates:
        if not candidate:
            continue
        try:
            subprocess.run([candidate, "-version"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return candidate
        except (subprocess.CalledProcessError, FileNotFoundError):
            continue

    raise RuntimeError(
        "ffmpeg not found. Install it or place the binary in cctv-camera-2/bin/ffmpeg (or set FFMPEG_PATH)."
    )


def list_devices(ffmpeg_path: str, system_name: str) -> None:
    if system_name == "Windows":
        cmd = [ffmpeg_path, "-hide_banner", "-f", "dshow", "-list_devices", "true", "-i", "dummy"]
        print("[info] Enumerating DirectShow devices...")
        subprocess.run(cmd, check=False)
        return
    if system_name == "Darwin":
        cmd = [ffmpeg_path, "-hide_banner", "-f", "avfoundation", "-list_devices", "true", "-i", ""]
        print("[info] Enumerating AVFoundation devices...")
        subprocess.run(cmd, check=False)
        return
    if system_name == "Linux":
        print("[info] ffmpeg does not expose a unified device list on Linux.")
        print("       Cameras usually appear under /dev/video*. Example:")
        print("         ls -lh /dev/video*")
        return

    print(f"[warn] Unsupported platform for automatic listing: {system_name}")


def detect_default_device(ffmpeg_path: str, system_name: str) -> Optional[str]:
    if system_name == "Windows":
        try:
            result = subprocess.run(
                [ffmpeg_path, "-hide_banner", "-f", "dshow", "-list_devices", "true", "-i", "dummy"],
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="ignore",
            )
            in_video_section = False
            for raw_line in result.stdout.splitlines():
                line = raw_line.strip()
                if "DirectShow video devices" in line:
                    in_video_section = True
                    continue
                if "DirectShow audio devices" in line and in_video_section:
                    break
                if in_video_section and '"' in line:
                    parts = line.split('"')
                    if len(parts) >= 3 and parts[1]:
                        return parts[1]
            return None
        except Exception:
            return None
    if system_name == "Darwin":
        return "0"
    if system_name == "Linux":
        default_path = Path("/dev/video0")
        if default_path.exists():
            return str(default_path)
        return None
    return None


def build_input_args(
    args: argparse.Namespace,
    system_name: str,
    ffmpeg_path: str,
) -> List[str]:
    input_args: List[str] = []

    if args.source:
        if args.loop:
            input_args.extend(["-stream_loop", "-1"])
        input_args.extend(["-re", "-i", args.source])
        return input_args

    device = args.device
    if not device:
        device = detect_default_device(ffmpeg_path, system_name)
        if device:
            print(f"[info] Using detected device: {device}")
    if not device:
        raise RuntimeError("No video device specified. Use --device or set DEVICE in .env")

    fps = args.fps if args.fps is not None else 25
    width = args.width if args.width is not None else 640
    height = args.height if args.height is not None else 360
    pixel_format = args.pixel_format

    if system_name == "Windows":
        input_args.extend(["-f", "dshow", "-rtbufsize", "100M"])
        if fps and fps > 0:
            input_args.extend(["-framerate", str(fps)])
        if width and height and width > 0 and height > 0:
            input_args.extend(["-video_size", f"{width}x{height}"])
        if pixel_format:
            input_args.extend(["-pixel_format", pixel_format])
        input_args.extend(["-i", f"video={device}"])
    elif system_name == "Darwin":
        input_args.extend(["-f", "avfoundation"])
        if fps and fps > 0:
            input_args.extend(["-framerate", str(fps)])
        if width and height and width > 0 and height > 0:
            input_args.extend(["-video_size", f"{width}x{height}"])
        # Device index for avfoundation (e.g. "0")
        input_args.extend(["-i", f"{device}:"])
    elif system_name == "Linux":
        input_args.extend(["-f", "v4l2"])
        if fps and fps > 0:
            input_args.extend(["-framerate", str(fps)])
        if width and height and width > 0 and height > 0:
            input_args.extend(["-video_size", f"{width}x{height}"])
        if pixel_format:
            input_args.extend(["-input_format", pixel_format])
        input_args.extend(["-i", device])
    else:
        raise RuntimeError(f"Unsupported OS for device capture: {system_name}")

    return input_args


def build_output_url(args: argparse.Namespace) -> str:
    protocol = args.protocol.lower()
    if protocol == "rtsp":
        port = args.rtsp_port or 8554
        return f"rtsp://{args.host}:{port}/{args.stream_key}"
    if protocol == "rtmp":
        port = args.rtmp_port or 1935
        return f"rtmp://{args.host}:{port}/{args.stream_key}"
    raise RuntimeError(f"Unsupported protocol: {args.protocol}")


def build_output_args(args: argparse.Namespace) -> List[str]:
    gop = (args.fps or 25) * 2
    gop = gop if gop > 0 else 50
    bitrate = args.bitrate or "1200k"
    bitrate_lower = bitrate.lower()
    if bitrate_lower.endswith("k"):
        try:
            numeric = int(bitrate_lower[:-1])
            bufsize = f"{numeric * 2}k"
        except ValueError:
            bufsize = bitrate
    else:
        bufsize = bitrate

    output_args = [
        "-c:v",
        "libx264",
        "-preset",
        args.preset,
        "-tune",
        "zerolatency",
        "-pix_fmt",
        "yuv420p",
        "-profile:v",
        "baseline",
        "-g",
        str(gop),
        "-x264-params",
        f"scenecut=0:open_gop=0:keyint={gop}",
        "-b:v",
        bitrate,
        "-maxrate",
        bitrate,
        "-bufsize",
        bufsize,
        "-an",
    ]

    if args.protocol.lower() == "rtsp":
        output_args.extend(["-f", "rtsp", "-rtsp_transport", args.rtsp_transport, "-muxdelay", "0", "-muxpreload", "0"])
    else:
        output_args.extend(["-f", "flv"])

    output_args.append(build_output_url(args))

    return output_args


def command_to_string(cmd: Iterable[str]) -> str:
    if hasattr(shlex, "join"):
        return shlex.join(cmd)
    return " ".join(shlex.quote(part) for part in cmd)


def parse_args() -> argparse.Namespace:
    env = load_env()
    parser = argparse.ArgumentParser(description="Streaming helper for the AnomEye CCTV stack.")

    parser.add_argument("--host", help="IP/hostname dari laptop pusat (HOST)")
    parser.add_argument("--stream-key", help="Nama stream di MediaMTX (STREAM_KEY)")
    parser.add_argument("--protocol", choices=["rtsp", "rtmp"], help="Protocol keluar (PROTOCOL)")
    parser.add_argument("--rtsp-port", type=int, help="Port RTSP (RTSP_PORT)")
    parser.add_argument("--rtmp-port", type=int, help="Port RTMP (RTMP_PORT)")
    parser.add_argument("--device", help="Perangkat kamera (DEVICE)")
    parser.add_argument("--source", help="Sumber alternatif (file/rtsp/rtmp) (SOURCE)")
    parser.add_argument("--fps", type=int, help="Frame per detik (FPS)")
    parser.add_argument("--width", type=int, help="Lebar frame (WIDTH)")
    parser.add_argument("--height", type=int, help="Tinggi frame (HEIGHT)")
    parser.add_argument("--pixel-format", help="Format pixel input (PIXEL_FORMAT)")
    parser.add_argument("--bitrate", help="Bitrate video, contoh 1200k (BITRATE)")
    parser.add_argument("--preset", default="veryfast", help="x264 preset (PRESET)")
    parser.add_argument("--ffmpeg", help="Path ke ffmpeg (FFMPEG_PATH)")
    parser.add_argument("--rtsp-transport", default="tcp", help="Transport untuk RTSP (RTSP_TRANSPORT)")
    parser.add_argument("--loop", action="store_true", help="Ulangi source file/URL tanpa henti (LOOP)")
    parser.add_argument("--list-devices", action="store_true", help="Daftar perangkat video lalu keluar")
    parser.add_argument("--dry-run", action="store_true", help="Hanya tampilkan perintah ffmpeg")
    parser.add_argument("--loglevel", help="Tingkat log ffmpeg (LOGLEVEL)")

    args = parser.parse_args()

    # Apply env defaults
    if args.host is None:
        args.host = env.get("HOST")
    if args.stream_key is None:
        args.stream_key = env.get("STREAM_KEY", "cam3")
    if args.protocol is None:
        args.protocol = env.get("PROTOCOL", "rtsp")
    if args.rtsp_port is None:
        args.rtsp_port = env_int(env, "RTSP_PORT", None)
    if args.rtmp_port is None:
        args.rtmp_port = env_int(env, "RTMP_PORT", None)
    if args.device is None:
        args.device = env.get("DEVICE")
    if args.source is None:
        args.source = env.get("SOURCE")
    if args.fps is None:
        args.fps = env_int(env, "FPS", 25)
    if args.width is None:
        args.width = env_int(env, "WIDTH", 640)
    if args.height is None:
        args.height = env_int(env, "HEIGHT", 360)
    if args.bitrate is None:
        args.bitrate = env.get("BITRATE", "1200k")
    if args.preset is None and env.get("PRESET"):
        args.preset = env["PRESET"]
    if args.ffmpeg is None:
        args.ffmpeg = env.get("FFMPEG_PATH")
    if args.rtsp_transport is None and env.get("RTSP_TRANSPORT"):
        args.rtsp_transport = env["RTSP_TRANSPORT"]
    if not args.loop:
        args.loop = env_bool(env, "LOOP", False)
    if args.loglevel is None:
        args.loglevel = env.get("LOGLEVEL", "info")
    if args.pixel_format is None:
        args.pixel_format = env.get("PIXEL_FORMAT")

    return args


def main() -> int:
    args = parse_args()

    system_name = platform.system()

    try:
        ffmpeg_path = resolve_ffmpeg(args.ffmpeg, load_env())
    except RuntimeError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        return 1

    if args.list_devices:
        list_devices(ffmpeg_path, system_name)
        return 0

    if not args.host:
        print("[error] --host atau HOST di .env wajib diisi", file=sys.stderr)
        return 1

    if not args.stream_key:
        print("[error] --stream-key atau STREAM_KEY di .env wajib diisi", file=sys.stderr)
        return 1

    try:
        input_args = build_input_args(args, system_name, ffmpeg_path)
        output_args = build_output_args(args)
    except RuntimeError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        return 1

    cmd = [ffmpeg_path, "-hide_banner", "-loglevel", args.loglevel] + input_args + output_args
    cmd_str = command_to_string(cmd)

    print("[info] ffmpeg command:")
    print(f"        {cmd_str}")

    if args.dry_run:
        print("[info] Dry-run mode, tidak menjalankan ffmpeg.")
        return 0

    try:
        completed = subprocess.run(cmd)
        return completed.returncode
    except KeyboardInterrupt:
        print("\n[info] Dihentikan oleh user.")
        return 0
    except FileNotFoundError:
        print("[error] ffmpeg tidak ditemukan. Pastikan sudah terinstal.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
