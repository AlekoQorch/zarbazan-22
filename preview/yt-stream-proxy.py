#!/usr/bin/env python3
"""Minimal YouTube → audio proxy for iOS background playback.

Extracts a stream via InnerTube on THIS server, then pipes bytes to the client
(so googlevideo IP binding stays on the server). CORS + Range enabled.
"""
from __future__ import annotations

import json
import re
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 8787
VIDEO_RE = re.compile(r"^[A-Za-z0-9_-]{6,15}$")

CLIENTS = [
    {
        "name": "ANDROID_VR",
        "key": "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w",
        "ua": "com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip",
        "client": {
            "clientName": "ANDROID_VR",
            "clientVersion": "1.60.19",
            "deviceMake": "Oculus",
            "deviceModel": "Quest 3",
            "androidSdkVersion": 32,
            "osName": "Android",
            "osVersion": "12L",
            "hl": "ka",
            "gl": "GE",
        },
    },
    {
        "name": "ANDROID_VR_US",
        "key": "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w",
        "ua": "com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip",
        "client": {
            "clientName": "ANDROID_VR",
            "clientVersion": "1.60.19",
            "deviceMake": "Oculus",
            "deviceModel": "Quest 3",
            "androidSdkVersion": 32,
            "osName": "Android",
            "osVersion": "12L",
            "hl": "en",
            "gl": "US",
        },
    },
    {
        "name": "IOS",
        "key": "AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc",
        "ua": "com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)",
        "client": {
            "clientName": "IOS",
            "clientVersion": "21.26.4",
            "deviceMake": "Apple",
            "deviceModel": "iPhone16,2",
            "osName": "iPhone",
            "osVersion": "18.3.2.22D82",
            "hl": "ka",
            "gl": "GE",
        },
    },
    {
        "name": "ANDROID",
        "key": "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w",
        "ua": "com.google.android.youtube/19.28.35 (Linux; U; Android 14) gzip",
        "client": {
            "clientName": "ANDROID",
            "clientVersion": "19.28.35",
            "androidSdkVersion": 34,
            "osName": "Android",
            "osVersion": "14",
            "hl": "ka",
            "gl": "GE",
        },
    },
]

PIPED = [
    "https://api.piped.private.coffee",
    "https://pipedapi.ducks.party",
    "https://pipedapi.reallyaweso.me",
    "https://pipedapi.darkness.services",
]

INVIDIOUS = [
    "https://inv.nadeko.net",
    "https://invidious.nerdvpn.de",
    "https://iv.ggtyler.dev",
]


def pick_innertube_url(data: dict) -> tuple[str | None, str | None]:
    sd = data.get("streamingData") or {}
    adaptive = sd.get("adaptiveFormats") or []
    progressive = sd.get("formats") or []
    audio = [
        f
        for f in adaptive
        if "audio" in str(f.get("mimeType", "")).lower() and f.get("url")
    ]
    audio.sort(
        key=lambda f: (
            0 if "mp4" in str(f.get("mimeType", "")) else 1,
            -(f.get("bitrate") or 0),
        )
    )
    if audio:
        return audio[0]["url"], audio[0].get("mimeType") or "audio/mp4"
    for f in progressive:
        if f.get("url"):
            return f["url"], f.get("mimeType") or "video/mp4"
    hls = sd.get("hlsManifestUrl")
    if hls:
        return hls, "application/vnd.apple.mpegurl"
    return None, None


def resolve_innertube(video_id: str) -> tuple[str | None, str | None, str]:
    last = "no stream"
    for c in CLIENTS:
        body = json.dumps(
            {
                "context": {"client": c["client"]},
                "videoId": video_id,
                "contentCheckOk": True,
                "racyCheckOk": True,
            }
        ).encode()
        req = urllib.request.Request(
            f"https://www.youtube.com/youtubei/v1/player?key={c['key']}&prettyPrint=false",
            data=body,
            method="POST",
            headers={
                "Content-Type": "application/json",
                "User-Agent": c["ua"],
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=12) as resp:
                data = json.load(resp)
        except Exception as e:  # noqa: BLE001
            last = str(e)
            continue
        status = (data.get("playabilityStatus") or {}).get("status")
        if status and status != "OK":
            last = status
            continue
        url, mime = pick_innertube_url(data)
        if url:
            return url, mime, c["name"]
        last = "empty formats"
    return None, None, last


def resolve_piped(video_id: str) -> tuple[str | None, str | None]:
    for base in PIPED:
        try:
            req = urllib.request.Request(
                f"{base}/streams/{video_id}",
                headers={"User-Agent": "NovaMusicProxy/1.0", "Accept": "application/json"},
            )
            with urllib.request.urlopen(req, timeout=8) as resp:
                data = json.load(resp)
        except Exception:  # noqa: BLE001
            continue
        audio = data.get("audioStreams") or []
        audio.sort(
            key=lambda a: (
                0 if "mp4" in str(a.get("mimeType", "")) else 1,
                -(a.get("bitrate") or 0),
            )
        )
        if audio and audio[0].get("url"):
            return audio[0]["url"], audio[0].get("mimeType") or "audio/mp4"
        muxed = [
            v
            for v in (data.get("videoStreams") or [])
            if not v.get("videoOnly") and v.get("url")
        ]
        pref = next(
            (
                v
                for v in muxed
                if "piped" in v["url"] or "videoplayback" in v["url"]
            ),
            None,
        )
        if pref:
            return pref["url"], pref.get("mimeType") or "video/mp4"
        if muxed:
            return muxed[0]["url"], muxed[0].get("mimeType") or "video/mp4"
    return None, None


def resolve_invidious(video_id: str) -> tuple[str | None, str | None]:
    for base in INVIDIOUS:
        try:
            req = urllib.request.Request(
                f"{base}/api/v1/videos/{video_id}",
                headers={"User-Agent": "NovaMusicProxy/1.0", "Accept": "application/json"},
            )
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.load(resp)
        except Exception:  # noqa: BLE001
            continue
        formats = list(data.get("adaptiveFormats") or []) + list(data.get("formatStreams") or [])
        audio = [
            f
            for f in formats
            if "audio" in str(f.get("type") or f.get("mimeType") or "").lower() and f.get("url")
        ]
        audio.sort(
            key=lambda a: (
                0 if "mp4" in str(a.get("type") or a.get("mimeType") or "") else 1,
                -(int(a.get("bitrate") or 0) if str(a.get("bitrate") or "").isdigit() else 0),
            )
        )
        if audio:
            mime = audio[0].get("type") or audio[0].get("mimeType") or "audio/mp4"
            return audio[0]["url"], mime
    return None, None


def resolve(video_id: str) -> tuple[str | None, str | None, str]:
    url, mime, via = resolve_innertube(video_id)
    if url:
        return url, mime, via
    url, mime = resolve_piped(video_id)
    if url:
        return url, mime, "piped"
    url, mime = resolve_invidious(video_id)
    if url:
        return url, mime, "invidious"
    return None, None, via


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args) -> None:  # noqa: A003
        print("[yt-proxy]", self.address_string(), fmt % args)

    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,HEAD,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Expose-Headers", "Content-Type,Content-Length,Accept-Ranges,Content-Range")

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_HEAD(self) -> None:  # noqa: N802
        self._handle(head_only=True)

    def do_GET(self) -> None:  # noqa: N802
        self._handle(head_only=False)

    def _handle(self, head_only: bool) -> None:
        path = self.path.split("?", 1)[0]
        if path in ("/", "/health"):
            body = b'{"ok":true,"service":"nova-yt-proxy"}'
            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if not head_only:
                self.wfile.write(body)
            return

        if path.startswith("/resolve/"):
            video_id = path[len("/resolve/") :]
            if not VIDEO_RE.match(video_id):
                self.send_error(400, "bad id")
                return
            url, mime, via = resolve(video_id)
            payload = {
                "ok": bool(url),
                "via": via,
                "mime": mime,
                "proxy": f"/stream/{video_id}" if url else None,
                "direct": url,
            }
            body = json.dumps(payload).encode()
            self.send_response(200 if url else 422)
            self._cors()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if not head_only:
                self.wfile.write(body)
            return

        if path.startswith("/stream/"):
            video_id = path[len("/stream/") :]
            if not VIDEO_RE.match(video_id):
                self.send_error(400, "bad id")
                return
            url, mime, via = resolve(video_id)
            if not url:
                body = json.dumps({"ok": False, "error": via or "unavailable"}).encode()
                self.send_response(422)
                self._cors()
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                if not head_only:
                    self.wfile.write(body)
                return

            range_header = self.headers.get("Range")
            headers = {
                "User-Agent": "Mozilla/5.0 NovaMusicProxy/1.0",
                "Accept": "*/*",
            }
            if range_header:
                headers["Range"] = range_header
            req = urllib.request.Request(url, headers=headers)
            try:
                upstream = urllib.request.urlopen(req, timeout=30)
            except urllib.error.HTTPError as e:
                self.send_response(e.code)
                self._cors()
                self.end_headers()
                return
            except Exception as e:  # noqa: BLE001
                body = str(e).encode()
                self.send_response(502)
                self._cors()
                self.send_header("Content-Type", "text/plain")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                if not head_only:
                    self.wfile.write(body)
                return

            status = getattr(upstream, "status", 200) or 200
            self.send_response(status)
            self._cors()
            ctype = upstream.headers.get("Content-Type") or mime or "application/octet-stream"
            self.send_header("Content-Type", ctype)
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Nova-Via", via)
            for h in ("Content-Length", "Content-Range"):
                if upstream.headers.get(h):
                    self.send_header(h, upstream.headers.get(h))
            self.end_headers()
            if head_only:
                upstream.close()
                return
            try:
                while True:
                    chunk = upstream.read(64 * 1024)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
            finally:
                upstream.close()
            return

        self.send_error(404, "not found")


def main() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"nova-yt-proxy on http://0.0.0.0:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
