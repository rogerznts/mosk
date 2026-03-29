# Task: Minimalist Style

Apply the Premium Utilitarian Minimalism & Editorial UI design language to the current work.

## When to use

- User asks for clean, editorial, minimalist, or document-style aesthetic
- Workspace platforms, note-taking apps, or content-focused interfaces
- When the vibe is "Notion meets high-end magazine"

## Banned Elements

- DO NOT use `Inter`, `Roboto`, or `Open Sans`.
- DO NOT use thin-line icon libraries (`Lucide`, `Feather`, standard `Heroicons`).
- DO NOT use Tailwind default heavy shadows (`shadow-md`, `shadow-lg`, `shadow-xl`). Shadows must be ultra-diffuse, opacity < 0.05.
- DO NOT use primary colored backgrounds for large elements.
- DO NOT use gradients, neon colors, or 3D glassmorphism.
- DO NOT use `rounded-full` for large containers or primary buttons.
- DO NOT use emojis anywhere.
- DO NOT use generic placeholders ("John Doe", "Lorem Ipsum").
- DO NOT use AI copywriting clichés.

## Typographic Architecture

Extreme typographic contrast and premium font selection for an editorial feel.

- **Primary Sans-Serif:** `'SF Pro Display', 'Geist Sans', 'Helvetica Neue', 'Switzer', sans-serif`.
- **Editorial Serif (Hero/Quotes):** `'Lyon Text', 'Newsreader', 'Playfair Display', 'Instrument Serif', serif`. Tight tracking (`-0.02em` to `-0.04em`), tight line-height (`1.1`).
- **Monospace:** `'Geist Mono', 'SF Mono', 'JetBrains Mono', monospace`.
- **Body text:** Never `#000000`. Use off-black (`#111111` or `#2F3437`), `line-height: 1.6`. Secondary: `#787774`.

## Color Palette (Warm Monochrome + Spot Pastels)

- **Canvas:** `#FFFFFF` or `#F7F6F3` / `#FBFBFA`.
- **Cards:** `#FFFFFF` or `#F9F9F8`.
- **Borders:** `#EAEAEA` or `rgba(0,0,0,0.06)`.
- **Accent Pastels:**
  - Pale Red: `#FDEBEC` (Text: `#9F2F2D`)
  - Pale Blue: `#E1F3FE` (Text: `#1F6C9F`)
  - Pale Green: `#EDF3EC` (Text: `#346538`)
  - Pale Yellow: `#FBF3DB` (Text: `#956400`)

## Component Specifications

- **Bento Box Grids:** Asymmetrical CSS Grid. Cards with `border: 1px solid #EAEAEA`, radius `8px` or `12px` max, generous padding (`24px`–`40px`).
- **Primary CTA:** Solid `#111111` bg, `#FFFFFF` text. Radius `4px`–`6px`. No shadow. Hover: `#333333` or `scale(0.98)`.
- **Tags/Badges:** Pill-shaped, `text-xs`, uppercase, wide tracking. Muted pastel backgrounds.
- **Accordions:** No container boxes. Only `border-bottom: 1px solid #EAEAEA`. Clean `+`/`-` toggle.
- **Keystroke UIs:** `<kbd>` tags with `border: 1px solid #EAEAEA`, `radius: 4px`, `bg: #F7F6F3`, monospace.
- **Faux-OS Chrome:** White top bar with three small light gray circles (macOS controls).

## Iconography & Imagery

- **Icons:** Phosphor Icons (Bold/Fill) or Radix UI Icons. Consistent stroke width.
- **Illustrations:** Monochromatic continuous-line sketches with single muted pastel geometric fill.
- **Photography:** Desaturated, warm-toned. Subtle grain overlay (`opacity: 0.04`). Use `picsum.photos` for placeholders.
- **Section backgrounds:** Not flat — use subtle imagery at low opacity, soft radial gradients (`opacity: 0.03`), or minimal geometric patterns.

## Motion & Micro-Animations

Motion should feel invisible — present but never distracting.

- **Scroll Entry:** `translateY(12px)` + `opacity: 0` → resolved over `600ms` with `cubic-bezier(0.16, 1, 0.3, 1)`. Use `IntersectionObserver`.
- **Hover:** Ultra-subtle shadow shift (`0 0 0` → `0 2px 8px rgba(0,0,0,0.04)` over `200ms`). Buttons: `scale(0.98)` on `:active`.
- **Staggered Reveals:** Cascade delay `calc(var(--index) * 80ms)`.
- **Ambient Motion:** Optional slow radial gradient blob (`20s+`, `opacity: 0.02-0.04`), fixed + pointer-events-none.
- **Performance:** Animate only `transform` and `opacity`.

## Execution Protocol

1. Establish macro-whitespace first. `py-24` or `py-32` between sections.
2. Constrain typography content to `max-w-4xl` or `max-w-5xl`.
3. Apply custom typographic hierarchy and monochromatic variables.
4. Enforce `1px solid #EAEAEA` on every card, divider, and border.
5. Add scroll-entry animations to all major content blocks.
6. Ensure sections have visual depth (imagery, gradients, textures).
7. Deliver code that reflects the high-end editorial aesthetic natively.
