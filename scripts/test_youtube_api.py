#!/usr/bin/env python3
"""Live YouTube Data API v3 smoke test.

Usage:
  export YOUTUBE_DATA_API_KEY='your-key'
  python3 scripts/test_youtube_api.py [query]

Exits 0 on success with real search results + durations.
"""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.parse
import urllib.request

APP_UA = "NovaMusic/1.0 (test; YouTubeDataAPI)"


def parse_iso8601_duration(iso: str) -> float:
    body = iso.upper()
    if body.startswith("PT"):
        body = body[2:]
    total = 0.0
    number = ""
    for ch in body:
        if ch.isdigit():
            number += ch
            continue
        value = float(number or 0)
        number = ""
        if ch == "H":
            total += value * 3600
        elif ch == "M":
            total += value * 60
        elif ch == "S":
            total += value
    return total


def get_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"Accept": "application/json", "User-Agent": APP_UA})
    with urllib.request.urlopen(req, timeout=25) as resp:
        return json.load(resp)


def main() -> int:
    key = os.environ.get("YOUTUBE_DATA_API_KEY", "").strip()
    if not key or key == "PASTE_YOUR_YOUTUBE_DATA_API_KEY_HERE":
        print("FAIL: set YOUTUBE_DATA_API_KEY to a real YouTube Data API v3 key.")
        print("See docs/YOUTUBE_SETUP.md")
        return 2

    query = " ".join(sys.argv[1:]).strip() or "lofi hip hop"
    params = urllib.parse.urlencode(
        {
            "part": "snippet",
            "type": "video",
            "videoEmbeddable": "true",
            "videoCategoryId": "10",
            "maxResults": "8",
            "q": query,
            "key": key,
        }
    )
    search_url = f"https://www.googleapis.com/youtube/v3/search?{params}"
    data = get_json(search_url)
    if "error" in data:
        print("FAIL API:", data["error"].get("message"))
        return 1

    items = data.get("items") or []
    if not items:
        # retry without category
        params2 = urllib.parse.urlencode(
            {
                "part": "snippet",
                "type": "video",
                "videoEmbeddable": "true",
                "maxResults": "8",
                "q": query,
                "key": key,
            }
        )
        data = get_json(f"https://www.googleapis.com/youtube/v3/search?{params2}")
        items = data.get("items") or []

    if not items:
        print(f"FAIL: no results for {query!r}")
        return 1

    ids = [it["id"]["videoId"] for it in items if it.get("id", {}).get("videoId")]
    details = get_json(
        "https://www.googleapis.com/youtube/v3/videos?"
        + urllib.parse.urlencode({"part": "contentDetails", "id": ",".join(ids), "key": key})
    )
    durations = {
        it["id"]: parse_iso8601_duration(it["contentDetails"]["duration"])
        for it in details.get("items") or []
        if it.get("contentDetails", {}).get("duration")
    }

    print(f"OK query={query!r} results={len(items)}")
    for it in items:
        vid = it["id"]["videoId"]
        sn = it["snippet"]
        thumb = (
            sn.get("thumbnails", {}).get("high", {}).get("url")
            or sn.get("thumbnails", {}).get("medium", {}).get("url")
        )
        dur = durations.get(vid, 0)
        assert thumb and thumb.startswith("https://"), "missing thumbnail"
        assert sn.get("title"), "missing title"
        assert sn.get("channelTitle"), "missing channel"
        print(f"- {vid} | {dur:.0f}s | {sn['channelTitle']} | {sn['title'][:60]}")
        print(f"  thumb: {thumb}")
        print(f"  embed: https://www.youtube.com/embed/{vid}?playsinline=1")

    # offline parser self-check
    assert parse_iso8601_duration("PT3M21S") == 201
    assert parse_iso8601_duration("PT1H2M3S") == 3723
    print("OK duration parser")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
