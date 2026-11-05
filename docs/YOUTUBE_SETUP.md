# YouTube Data API v3 — setup for NOVA MUSIC

NOVA MUSIC searches **real** YouTube music via the official **YouTube Data API v3** (optional) or Piped search, then plays a **direct audio/HLS stream** through AVPlayer / HTML5 audio so playback continues when the phone is locked or folded. Streams are not saved offline.

## 1. Create a Google Cloud project

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Create a project (or select an existing one).
3. Open **APIs & Services → Library**.
4. Search for **YouTube Data API v3** → **Enable**.

## 2. Create an API key

1. **APIs & Services → Credentials → Create credentials → API key**.
2. Copy the key.
3. **Restrict the key** (recommended):
   - **API restrictions:** allow only **YouTube Data API v3**.
   - **Application restrictions (iOS):** add your app’s bundle ID  
     (this project: `com.nova.music` — confirm in Xcode target).

Quota: Google’s default free quota is enough for personal/dev search. Monitor usage in Cloud Console.

## 3. Put the key in the app (pick one)

### A. Settings (runtime — easiest on device)

1. Run the app → **Settings → YouTube**.
2. Paste the API key → **Save**.
3. Open **Explore → YouTube** and search.

The key is stored in the app’s `UserDefaults` on device (not committed to git).

### B. Info.plist / Xcode build setting

1. Copy `Secrets.example.plist` → `NovaMusic/Secrets.plist` (gitignored).
2. Set `YOUTUBE_DATA_API_KEY` to your key.
3. Or set a user-defined build setting `YOUTUBE_DATA_API_KEY` and keep Info.plist as:

```xml
<key>YOUTUBE_DATA_API_KEY</key>
<string>$(YOUTUBE_DATA_API_KEY)</string>
```

Resolution order in code: **Settings override → Secrets.plist → Info.plist**.

### C. HTML phone preview

Open the preview → Explore → YouTube → enter the same API key (saved in `localStorage` on that browser only).

## 4. What the app calls

| Purpose | Official endpoint |
|--------|-------------------|
| Search videos | `GET https://www.googleapis.com/youtube/v3/search` (`part=snippet`, `type=video`, `videoEmbeddable=true`, music-biased query) |
| Durations | `GET https://www.googleapis.com/youtube/v3/videos` (`part=contentDetails`) |
| Playback | Direct audio/HLS URL → `AVPlayer` / HTML5 `<audio>` (background-capable) |

## 5. Verify from a terminal

```bash
export YOUTUBE_DATA_API_KEY='your-key-here'
python3 scripts/test_youtube_api.py
```

You should see real titles, channel names, thumbnails, and ISO-8601 durations.

## Compliance

- Search: YouTube Data API v3 when a key is set; otherwise public Piped search metadata.
- Play: ephemeral audio/HLS stream in the system player (not downloaded for offline storage).
- Background playback requires a real media URL — iframe embeds pause when iOS suspends the page.
