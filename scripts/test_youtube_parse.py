#!/usr/bin/env python3
"""Offline tests for YouTube duration parsing + sample payload shape (no API key)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

# Reuse parser from live script
sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_youtube_api import parse_iso8601_duration  # noqa: E402


SAMPLE_SEARCH = {
    "items": [
        {
            "id": {"kind": "youtube#video", "videoId": "jfKfPfyJRdk"},
            "snippet": {
                "publishedAt": "2021-07-01T00:00:00Z",
                "channelTitle": "Lofi Girl",
                "title": "lofi hip hop radio - beats to relax/study to",
                "thumbnails": {
                    "default": {"url": "https://i.ytimg.com/vi/jfKfPfyJRdk/default.jpg"},
                    "medium": {"url": "https://i.ytimg.com/vi/jfKfPfyJRdk/mqdefault.jpg"},
                    "high": {"url": "https://i.ytimg.com/vi/jfKfPfyJRdk/hqdefault.jpg"},
                },
            },
        }
    ]
}


def main() -> int:
    assert parse_iso8601_duration("PT21S") == 21
    assert parse_iso8601_duration("PT3M") == 180
    assert parse_iso8601_duration("PT3M21S") == 201
    assert parse_iso8601_duration("PT1H") == 3600
    assert parse_iso8601_duration("PT1H2M3S") == 3723
    assert parse_iso8601_duration("PT10H11M12S") == 36672

    item = SAMPLE_SEARCH["items"][0]
    assert item["id"]["videoId"] == "jfKfPfyJRdk"
    assert item["snippet"]["thumbnails"]["high"]["url"].startswith("https://")
    assert "channelTitle" in item["snippet"]

    # Round-trip JSON stability
    assert json.loads(json.dumps(SAMPLE_SEARCH))["items"][0]["id"]["videoId"]

    print("OK offline YouTube parse/fixture tests")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
