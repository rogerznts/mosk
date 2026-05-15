# Task: Redesign

Audit and upgrade an existing interface to premium quality without breaking functionality.

## When to use

- User asks to improve, upgrade, or redesign an existing page or component
- Fixing "generic AI look" in existing code
- Elevating visual quality of a working interface

## Workflow

1. **Scan** — Read the codebase. Identify framework, styling method, and current design patterns.
2. **Diagnose** — Run through the audit below. List every generic pattern and missing state.
3. **Fix** — Apply targeted upgrades working with the existing stack. Do not rewrite from scratch.

## Design Audit

### Typography
- Browser defaults or Inter everywhere → Replace with `Geist`, `Outfit`, `Cabinet Grotesk`, `Satoshi`
- Headlines lack presence → Increase size, tighten letter-spacing, reduce line-height
- Body text too wide → Limit to ~65 characters, increase line-height
- Only Regular/Bold weights → Introduce Medium (500) and SemiBold (600)
- Numbers in proportional font → Use monospace or `font-variant-numeric: tabular-nums`
- Missing letter-spacing adjustments → Negative tracking for headers, positive for labels
- Orphaned words → Fix with `text-wrap: balance` or `text-wrap: pretty`

### Color and Surfaces
- Pure `#000000` → Off-black, dark charcoal, or tinted dark
- Oversaturated accents → Keep saturation below 80%
- Multiple accent colors → Pick one, remove the rest
- Mixing warm/cool grays → Stick to one gray family
- Purple/blue "AI gradient" → Neutral bases with single accent
- Generic `box-shadow` → Tint shadows to match background hue
- Flat with zero texture → Add subtle noise, grain, or micro-patterns
- Inconsistent lighting direction → Audit all shadows for single light source
- Random dark sections in light page → Keep consistent tone or commit to full dark mode
- Empty flat sections → Add background imagery, subtle patterns, or ambient gradients

### Layout
- Everything centered/symmetrical → Break with offset margins, mixed aspect ratios
- Three equal card columns → Replace with zig-zag, asymmetric grid, horizontal scroll, masonry
- `height: 100vh` → Replace with `min-height: 100dvh`
- Complex flexbox math → Replace with CSS Grid
- No max-width container → Add ~1200-1440px constraint with auto margins
- No overlap or depth → Use negative margins for layering
- Missing whitespace → Double the spacing
- Buttons not bottom-aligned in card groups → Pin to bottom
- Inconsistent vertical rhythm → Align shared elements across columns

### Interactivity and States
- No hover states → Add background shift, scale, or translate
- No active/pressed feedback → `scale(0.98)` or `translateY(1px)`
- Instant transitions → 200-300ms smooth transitions
- Missing focus ring → Visible focus indicators (accessibility requirement)
- No loading states → Skeleton loaders matching layout
- No empty states → Composed "getting started" view
- No error states → Clear inline error messages
- Animations using `top`/`left`/`width`/`height` → Switch to `transform` and `opacity`

### Content
- Generic names → Diverse, realistic names
- Fake round numbers → Organic data (`47.2%`, `$99.00`)
- "Acme Corp" → Contextual brand names
- AI copywriting clichés → Plain, specific language
- Lorem Ipsum → Real draft copy
- Title Case everywhere → Sentence case

### Component Patterns
- Generic card look → Remove border, or use only bg color, or only spacing
- Pill "New"/"Beta" badges → Square badges, flags, or plain text
- 3-card carousel testimonials → Masonry wall or embedded social posts
- Pricing table with 3 towers → Highlight recommended with color/emphasis
- Modals for everything → Inline editing, slide-overs, expandable sections

### Code Quality
- Div soup → Semantic HTML (`<nav>`, `<main>`, `<article>`, `<aside>`)
- Inline styles mixed with classes → Move to project styling system
- Hardcoded pixel widths → Relative units
- Missing alt text → Describe image content
- Arbitrary z-index values → Clean z-index scale
- Import hallucinations → Verify every import in `package.json`

## Upgrade Techniques

### Typography
- Variable font animation on scroll/hover
- Outlined-to-fill transitions on entry
- Text mask reveals (typography as window to video)

### Layout
- Broken grid / asymmetry with calculated randomness
- Whitespace maximization for single-element focus
- Parallax card stacks on scroll
- Split-screen scroll

### Motion
- Smooth scroll with inertia
- Staggered entry with Y-axis + opacity cascade
- Spring physics for all interactive elements
- Scroll-driven reveals (masks, wipes, SVG paths)

### Surface
- True glassmorphism (backdrop-blur + inner border + inner shadow)
- Spotlight borders under cursor
- Grain/noise overlays (fixed, pointer-events-none)
- Colored, tinted shadows

## Fix Priority

Apply changes in this order for maximum impact, minimum risk:

1. Font swap
2. Color palette cleanup
3. Hover and active states
4. Layout and spacing
5. Replace generic components
6. Add loading, empty, error states
7. Polish typography scale and spacing

## Rules

- Work with the existing tech stack. Do not migrate frameworks.
- Do not break existing functionality.
- Before importing any new library, check `package.json`.
- If Tailwind, check version (v3 vs v4) before config changes.
- Keep changes reviewable and focused.
