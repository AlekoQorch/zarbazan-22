# NOVA MUSIC — YouTube ჩაკეცვაზე

iOS Safari **ვიდეო embed-ს აპაუზებს** ჩაკეცვისას. ამიტომ NOVA YouTube-ს ასე უკრავს:

1. **ჯერ** ცდილობს **აპში YouTube აუდიო სტრიმს** (HTML5) — ჩაკეცვაზე გრძელდება  
2. თუ YouTube დაბლოკავს ამ გზას → ხსნის **YouTube / YouTube Music აპს**, სადაც ჩაკეცვა ყოველთვის მუშაობს  

## გახსენი (ახალი build)

https://htmlpreview.github.io/?https://raw.githubusercontent.com/AlekoQorch/zarbazan-22/cursor/youtube-search-player-b486/preview/nova-music.html?v=4&tab=youtube

1. Explore → **YouTube** → მოძებნე → დაატაპე  
2. თუ აპში ჩაირთო — ჩაკეცე, მუსიკა უნდა გაგრძელდეს  
3. თუ YouTube აპი გაიხსნა — იქაც ჩაკეცვაზე ისმის  

**Home Screen-ზე დაამატე** (Share → Add to Home Screen). ძველი ხატულა წაშალე თუ Loading რჩება.

სტრიმ პროქსი მუშაობს cloud agent-ის გაშვებისას (`preview/yt-stream-proxy.py` + Cloudflare tunnel).
