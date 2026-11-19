#!/usr/bin/env python3
"""Static file server + CompanyInfo API proxy (same-origin for the browser)."""
from __future__ import annotations

import json
import ssl
import time
import urllib.error
import urllib.request
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
API = "https://api.companyinfo.ge/api"
UA = "Mozilla/5.0 (compatible; Kavshirebi/1.0)"
CTX = ssl.create_default_context()
RETRIES = 4


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_OPTIONS(self):
        if self.path.startswith("/proxy/"):
            self.send_response(204)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Accept, Content-Type")
            self.end_headers()
            return
        self.send_error(404)

    def do_GET(self):
        if self.path.startswith("/proxy/"):
            return self.proxy()
        return super().do_GET()

    def proxy(self):
        rel = self.path[len("/proxy/") :]
        url = f"{API}/{rel}"
        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": UA,
                "Accept": "application/json",
                "Origin": "https://companyinfo.ge",
                "Referer": "https://companyinfo.ge/",
            },
        )
        last_err = None
        for attempt in range(RETRIES):
            try:
                with urllib.request.urlopen(req, timeout=90, context=CTX) as resp:
                    body = resp.read()
                    ctype = resp.headers.get("Content-Type", "application/json")
                    self.send_response(200)
                    self.send_header("Content-Type", ctype)
                    self.send_header("Access-Control-Allow-Origin", "*")
                    self.send_header("Content-Length", str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)
                    return
            except urllib.error.HTTPError as e:
                body = e.read() if e.fp else b""
                self.send_response(e.code)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body or json.dumps({"error": str(e)}).encode())
                return
            except Exception as e:
                last_err = e
                time.sleep(0.4 * (attempt + 1))

        body = json.dumps({"error": str(last_err)}).encode()
        self.send_response(502)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        if self.path.startswith("/proxy/"):
            super().log_message(fmt, *args)


def main():
    port = 8765
    httpd = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"serving {ROOT} on http://0.0.0.0:{port}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
