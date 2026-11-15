#!/usr/bin/env python3
"""
TV WiFi Cast — laptop full-screen sender (no Chrome “what to share” picker).
Captures the entire primary monitor and streams JPEG frames to the phone app.
"""
from __future__ import annotations

import argparse
import ssl
import sys
import time
from io import BytesIO

import mss
import websocket
from PIL import Image


def encode_frame(raw_bgra: bytes, width: int, height: int, max_w: int = 1280, quality: int = 55) -> bytes:
    img = Image.frombytes("RGB", (width, height), raw_bgra, "raw", "BGRX")
    if width > max_w:
        ratio = max_w / float(width)
        img = img.resize((max_w, max(1, int(height * ratio))), Image.Resampling.BILINEAR)
    buf = BytesIO()
    img.save(buf, format="JPEG", quality=quality, optimize=True)
    return buf.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser(description="Cast full laptop screen to TV WiFi Cast phone app")
    parser.add_argument("ip", nargs="?", help="Phone WiFi IP, e.g. 192.168.2.142")
    parser.add_argument("--port", type=int, default=8443)
    parser.add_argument("--fps", type=float, default=10.0)
    parser.add_argument("--monitor", type=int, default=1, help="mss monitor index (1 = primary)")
    args = parser.parse_args()

    ip = args.ip
    if not ip:
        ip = input("Phone IP shown in the app (e.g. 192.168.2.142): ").strip()
    if not ip:
        print("IP required.")
        return 1

    url = f"wss://{ip}:{args.port}/ws"
    print(f"Connecting to {url} …")
    print("Phone app must be on Start receiver. Ctrl+C to stop.")

    sslopt = {"cert_reqs": ssl.CERT_NONE, "check_hostname": False}
    try:
        ws = websocket.create_connection(url, sslopt=sslopt, timeout=8)
    except Exception as e:
        print(f"Connect failed: {e}")
        print("Check: same WiFi, Start receiver on phone, IP/port correct.")
        return 1

    print("Connected. Streaming FULL desktop (no picker)…")
    interval = 1.0 / max(args.fps, 1.0)
    frames = 0
    try:
        with mss.mss() as sct:
            monitors = sct.monitors
            if args.monitor < 0 or args.monitor >= len(monitors):
                print(f"Invalid monitor {args.monitor}. Available: 0..{len(monitors)-1}")
                return 1
            mon = monitors[args.monitor]
            while True:
                t0 = time.perf_counter()
                shot = sct.grab(mon)
                jpeg = encode_frame(shot.raw, shot.width, shot.height)
                if len(jpeg) < 900_000:
                    ws.send(jpeg, opcode=websocket.ABNF.OPCODE_BINARY)
                    frames += 1
                    if frames % 30 == 0:
                        print(f"  sent {frames} frames…")
                elapsed = time.perf_counter() - t0
                time.sleep(max(0.0, interval - elapsed))
    except KeyboardInterrupt:
        print("\nStopped.")
    except Exception as e:
        print(f"Stream error: {e}")
        return 1
    finally:
        try:
            ws.close()
        except Exception:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
