# Design Review — OSEE Magazine Design System

**Status:** Tokens + 9 components implemented. T6 complete minus this doc.

## Design Principles

The OSEE magazine editorial theme draws from the visual language of high-end print magazines (The New Yorker, The Economist, Monocle, Wallpaper*). Every UI surface should feel like a page in a beautifully typeset magazine, not a generic Material Design app.

### Core principles

1. **Typography first.** Two families: serif (Georgia — headlines, masthead, drop caps) + sans-serif (Inter — body, captions, labels). Hierarchy through size + weight + letter-spacing, not color.
2. **Editorial color palette.** Muted, considered colors. Gold as the brand accent (not blue). Paper cream as the canvas (not pure white). Ink black + paper cream = maximum contrast without harshness.
3. **The gold rule.** Every section break uses a 1.5px gold horizontal rule. This is the single most identifiable motif of the design.
4. **Magazine chrome, not app chrome.** Drop caps. Kicker labels. Section rules. Pull quotes. Publish stamps. These are not decorations — they're structural.
5. **Sharp corners.** No rounded buttons. Magazine pages are rectangular. Only exception: small radius (2-4px) for inputs and overlays.
6. **Generous whitespace.** Don't cram. Magazine layouts breathe.

## Component Catalog

| Component | Purpose | Used in |
|---|---|---|
| `MagazineMasthead` | Title banner with kicker, headline, subtitle, date, gold rule | All top-level pages |
| `MagazineDropCap` | First letter of paragraph styled as 56pt gold serif | Long-form text |
| `MagazineStat` | Large number + label | Dashboards, marketing |
| `MagazineCard` | Title + kicker + body + optional footer | Library, marketplace listings |
| `MagazineSectionRule` | Horizontal gold rule with optional label | Between sections |
| `MagazinePublishStamp` | "APPROVED" / "DRAFT" rotated 12° | Status indicators |
| `MagazineSidebar` | Vertical nav with serif labels | Teacher dashboard nav |
| `MagazinePullQuote` | Large serif quote with gold rule top/bottom | Coach highlights, testimonials |
| `MagazineNumberBadge` | Circled number for step indicators | Onboarding, multi-step flows |

## Color Tokens

| Token | Hex | Use |
|---|---|---|
| `MagazineColors.mastheadGold` | `#B89B5F` | Brand accent, rules, brand text |
| `MagazineColors.mastheadGoldLight` | `#D4B98A` | Hover states, light accents |
| `MagazineColors.paperCream` | `#FAF6EE` | Page background |
| `MagazineColors.inkBlack` | `#1A1A1A` | Primary text |
| `MagazineColors.inkGray` | `#4A4A4A` | Secondary text |
| `MagazineColors.accentRed` | `#A02B2B` | Stamps, errors |
| `MagazineColors.dropCapBlue` | `#1E3A5F` | Drop cap variant, secondary CTA |

## Typography Scale

| Token | Size | Line Height | Use |
|---|---|---|---|
| `display` | 48 | 56 | Masthead headlines |
| `headline` | 32 | 40 | Section titles |
| `title` | 24 | 32 | Card titles |
| `body` | 16 | 24 | Paragraphs |
| `caption` | 12 | 16 | Metadata |
| `overline` | 10 | 14 | Kickers, labels |

## Spacing Scale

4, 8, 12, 16, 24, 32, 48, 64 px — only. No magic numbers.

## Migration Guide

### For new pages

```dart
import 'package:osee_prep_hub/design/tokens.dart';
import 'package:osee_prep_hub/design/components.dart';

// Page header
MagazineMasthead(
  kicker: 'WEEKLY ISSUE',
  title: 'IELTS Week 3',
  subtitle: 'Speaking practice + reading drill',
  date: 'Jan 15, 2026',
),

// Section break
const MagazineSectionRule(label: 'Tasks'),

// Stat
MagazineStat(value: '87%', label: 'COMPLETION'),
```

### What NOT to do

- ❌ Don't use Material `Colors.primary` — use `MagazineColors.mastheadGold`
- ❌ Don't use default `TextStyle` — use `magazineBody()`, `magazineTitle()`, etc.
- ❌ Don't use `EdgeInsets.all(20)` — use `MagazineSpacing.lg` (24) or `.base` (16)
- ❌ Don't use `BorderRadius.circular(8)` — use `MagazineRadius.none` (sharp)
- ❌ Don't add inline `_MagazineFoo()` widgets — use the shared components

## Visual Review Checklist

- [ ] No Material defaults (Colors.primary, default Text)
- [ ] No inline _Magazine* widget definitions
- [ ] No hardcoded colors, sizes, or spacing
- [ ] Gold rules used between sections (not gray dividers)
- [ ] Serif (Georgia) for headlines, sans-serif (Inter) for body
- [ ] Paper cream background, ink black text — not pure white/black

## Future Work

- 🔄 Icon set: replace Material Icons with custom magazine-style icons (e.g., pen nib instead of edit)
- 🔄 Animation: page-turn transitions (low priority — magazines don't animate)
- 🔄 Dark mode: invert paper cream → dark gray, ink black → warm cream
- 🔄 Print stylesheet: when printing syllabi, output magazine-format PDF