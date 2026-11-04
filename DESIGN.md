# NOVA MUSIC — Design Reference Lock

## Brief
Designing a premium offline iOS music player for listeners who own their files.
Goal: import → play → enjoy with zero friction.
Tone: quiet luxury, cosmic night, confident and calm.
Must remember: album art is the hero; chrome stays out of the way.
Constraints: native SwiftUI, dark default + light mode, no third-party deps.
Research: Refero/Mobbin unavailable (subscription); locked from Apple Music / Spotify product patterns + craft references.

## Reference Lock
**Primary direction:** Dark charcoal full-bleed Now Playing (Apple Music simplicity + Spotify art dominance).

**Preserve:**
- Near-black canvases, soft charcoal surfaces
- Large square artwork with subtle depth (soft shadow, gentle scale on play)
- Minimal chrome; SF Symbols for controls
- Persistent mini player above tab bar
- Horizontal “shelf” carousels on Home

**Accent (NOVA identity):** Electric cyan `#3DDBD9` — used sparingly for play state, progress, primary CTAs. Not purple.

**Reject:**
- Purple/indigo gradients, neon glow stacks, pill-stat strips
- Card grids in the hero / first viewport of Home when empty
- Overcrowded player chrome

## Tokens
| Role | Dark | Light |
|------|------|-------|
| Background | `#0A0A0B` | `#F7F7F8` |
| Surface | `#161618` | `#FFFFFF` |
| Surface elevated | `#1E1E22` | `#F0F0F2` |
| Text primary | `#F5F5F7` | `#0A0A0B` |
| Text secondary | `#A1A1A6` | `#6E6E73` |
| Accent | `#3DDBD9` | `#0A9E9C` |
| Destructive | `#FF453A` | `#FF3B30` |
| Separator | white 8% | black 8% |

**Radius:** 10pt rows/controls, 14pt sheets, 16pt artwork thumbs, 24pt large art.
**Spacing:** 8 / 12 / 16 / 24 / 32.
**Type:** SF Pro / SF Pro Rounded for brand wordmark “NOVA”; system Dynamic Type.

## Screen Patterns
- **Home:** Personalized shelves; empty → centered import onboarding
- **Library:** Segmented sections (Songs / Albums / Artists / …)
- **Now Playing:** Full-screen art, artwork-derived gradient wash, swipe-down dismiss
- **Mini Player:** 64pt bar, art + title/artist + play + next
- **Import:** Document picker multi-select + progress sheet
