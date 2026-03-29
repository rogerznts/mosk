# Task: Soft / Agency Style

Apply the $150k+ agency-level design language to the current work.

## When to use

- User asks for premium, agency, expensive, high-end, or Awwwards-tier aesthetic
- SaaS products, portfolios, or marketing sites that need to feel like a top agency built them
- When the vibe is "Linear meets Apple meets Dribbble editorial"

## The "Absolute Zero" Directive (Strict Anti-Patterns)

If your code includes ANY of these, the design instantly fails:

- **Banned Fonts:** Inter, Roboto, Arial, Open Sans, Helvetica. Use `Geist`, `Clash Display`, `PP Editorial New`, or `Plus Jakarta Sans`.
- **Banned Icons:** Thick-stroked Lucide, FontAwesome, Material Icons. Use Phosphor Light, Remix Line.
- **Banned Borders/Shadows:** Generic 1px solid gray. Harsh dark drop shadows (`shadow-md`, `rgba(0,0,0,0.3)`).
- **Banned Layouts:** Edge-to-edge sticky navbars. Symmetrical 3-column Bootstrap grids without massive whitespace.
- **Banned Motion:** `linear` or `ease-in-out` transitions. Instant state changes.

## Creative Variance Engine

Before writing code, silently select ONE combination:

### Vibe & Texture (Pick 1)
1. **Ethereal Glass (SaaS/AI/Tech):** OLED black (`#050505`), radial mesh gradients, vantablack cards, `backdrop-blur-2xl`, white/10 hairlines, wide geometric Grotesk.
2. **Editorial Luxury (Lifestyle/Agency):** Warm creams (`#FDFBF7`), muted sage/espresso, Variable Serif for massive headings, CSS noise overlay (`opacity-[0.03]`).
3. **Soft Structuralism (Consumer/Portfolio):** Silver-grey/white, massive bold Grotesk, airy floating components, highly diffused ambient shadows.

### Layout (Pick 1)
1. **Asymmetrical Bento:** Masonry-like CSS Grid of varying card sizes. Mobile: single-column stack, all col-span reset.
2. **Z-Axis Cascade:** Stacked cards with varying depth, subtle rotation. Mobile: remove rotation/overlap, standard vertical stack.
3. **Editorial Split:** Massive typography left, interactive content right. Mobile: full-width vertical stack.

**Mobile Override:** All asymmetric layouts MUST fall back to `w-full`, `px-4`, `py-8` below `768px`. Use `min-h-[100dvh]` never `h-screen`.

## Haptic Micro-Aesthetics

### The "Double-Bezel" (Nested Architecture)
Never place a premium card flatly on the background. Use nested enclosures:
- **Outer Shell:** `bg-black/5` or `bg-white/5`, `ring-1 ring-black/5`, `p-1.5`, `rounded-[2rem]`.
- **Inner Core:** Own background, inner highlight (`shadow-[inset_0_1px_1px_rgba(255,255,255,0.15)]`), calculated smaller radius (`rounded-[calc(2rem-0.375rem)]`).

### Button Architecture
- Fully rounded pills (`rounded-full`, `px-6 py-3`).
- Trailing icon arrow (`↗`) in its own circular wrapper (`w-8 h-8 rounded-full bg-black/5`) flush with the button's right padding.

### Spatial Rhythm
- **Macro-Whitespace:** `py-24` to `py-40` for sections.
- **Eyebrow Tags:** Microscopic pill badges before H1/H2s (`rounded-full px-3 py-1 text-[10px] uppercase tracking-[0.2em]`).

## Motion Choreography

All motion must simulate real-world mass and spring physics. Use custom cubic-beziers (`ease-[cubic-bezier(0.32,0.72,0,1)]`).

### Fluid Island Nav
- Closed: floating glass pill (`mt-6`, `mx-auto`, `w-max`, `rounded-full`).
- Hamburger morphs lines into X with `rotate-45` / `-rotate-45`.
- Menu opens as screen-filling overlay (`backdrop-blur-3xl bg-black/80`).
- Links stagger-reveal (`translate-y-12 opacity-0` → `translate-y-0 opacity-100`).

### Magnetic Button Physics
- `group` utility. `active:scale-[0.98]` for physical press.
- Inner icon: `group-hover:translate-x-1 group-hover:-translate-y-[1px] scale-105`.

### Scroll Entry
- Gentle heavy fade-up (`translate-y-16 blur-md opacity-0` → `translate-y-0 blur-0 opacity-100` over 800ms+).
- Use `IntersectionObserver` or Framer Motion `whileInView`. Never `window.addEventListener('scroll')`.

## Performance Guardrails

- Animate only via `transform` and `opacity`.
- `backdrop-blur` only on fixed/sticky elements.
- Grain/noise on fixed `pointer-events-none` pseudo-elements.
- Strict z-index discipline: only for systemic layers.

## Pre-Output Checklist

- [ ] No banned fonts, icons, borders, shadows, layouts, or motion
- [ ] Vibe + Layout archetypes were consciously selected
- [ ] All major cards use Double-Bezel nested architecture
- [ ] CTAs use Button-in-Button trailing icon pattern
- [ ] Section padding minimum `py-24`
- [ ] All transitions use custom cubic-bezier — no `linear` or `ease-in-out`
- [ ] Scroll entry animations present
- [ ] Layout collapses gracefully below 768px
- [ ] All animations use only `transform` and `opacity`
- [ ] `backdrop-blur` only on fixed/sticky elements
- [ ] Overall impression reads as "$150k agency build"
