# Task: Stitch Design System

Generate a `DESIGN.md` file optimized for Google Stitch screen generation.

## When to use

- User asks for a Stitch design system, DESIGN.md, or design tokens for Stitch
- Preparing a project for use with Google Stitch AI screen generation

## Overview

Translate the anti-slop frontend engineering directives into Stitch's native semantic design language — descriptive, natural-language rules paired with precise values that Stitch's AI agent can interpret.

The generated `DESIGN.md` is the single source of truth for prompting Stitch to generate screens with a curated, premium design language.

## Prerequisites
- Access to Google Stitch via [labs.google.com/stitch](https://labs.google.com/stitch)
- Optionally: Stitch MCP Server for programmatic integration

## Analysis & Synthesis Instructions

### 1. Define the Atmosphere
Evaluate the target project's intent:
- **Density:** "Art Gallery Airy" (1–3) → "Daily App Balanced" (4–7) → "Cockpit Dense" (8–10)
- **Variance:** "Predictable Symmetric" (1–3) → "Offset Asymmetric" (4–7) → "Artsy Chaotic" (8–10)
- **Motion:** "Static Restrained" (1–3) → "Fluid CSS" (4–7) → "Cinematic Choreography" (8–10)

Default baseline: Variance 8, Motion 6, Density 4.

### 2. Map the Color Palette
For each color: **Descriptive Name** + **Hex Code** + **Functional Role**.

Constraints:
- Max 1 accent color, saturation below 80%
- "AI Purple/Blue Neon" aesthetic BANNED
- Neutral bases (Zinc/Slate) with singular accents
- One palette for entire output — no warm/cool gray fluctuation
- Never pure black (`#000000`)

### 3. Establish Typography Rules
- **Display/Headlines:** Track-tight, controlled scale. Hierarchy through weight and color, not just size
- **Body:** Relaxed leading, max 65 characters per line
- **Font Selection:** `Inter` BANNED. Use `Geist`, `Outfit`, `Cabinet Grotesk`, or `Satoshi`
- **Serif Ban:** Generic serif (`Times New Roman`, `Georgia`) BANNED. For editorial, use `Fraunces`, `Gambarino`, `Editorial New`, or `Instrument Serif`
- **Dashboard Constraint:** Sans-Serif pairings exclusively (`Geist` + `Geist Mono` or `Satoshi` + `JetBrains Mono`)
- **High-Density Override:** Density > 7 → all numbers in Monospace

### 4. Define the Hero Section
- **Inline Image Typography:** Embed small contextual photos between words/letters in headline. Rounded, at type-height
- **No Overlapping:** Every element occupies its own clean spatial zone
- **No Filler:** "Scroll to explore", scroll arrows, bouncing chevrons BANNED
- **Asymmetric:** Centered Hero BANNED when variance > 4
- **CTA Restraint:** Max one primary CTA

### 5. Describe Component Stylings
For each component: shape, color, shadow depth, interaction behavior.
- **Buttons:** Tactile push on active. No neon glows. No custom cursors
- **Cards:** ONLY when elevation communicates hierarchy. Tint shadows. High-density: replace with border-top dividers
- **Inputs:** Label above, error below. Standard gap
- **Loading:** Skeletal loaders matching layout — no circular spinners
- **Empty States:** Composed compositions
- **Error States:** Clear, inline reporting

### 6. Define Layout Principles
- No overlapping elements
- Centered Hero BANNED when variance > 4
- 3-equal-cards BANNED — use zig-zag, asymmetric, or horizontal scroll
- CSS Grid over Flexbox math
- Max-width containment (~1400px)
- `min-h-[100dvh]` never `h-screen`

### 7. Define Responsive Rules
- **< 768px:** All multi-column → single column
- **No horizontal scroll on mobile**
- **Typography:** `clamp()` scaling. Body minimum `1rem`/`14px`
- **Touch targets:** Minimum `44px`
- **Inline images:** Stack below headline on mobile
- **Spacing:** `clamp(3rem, 8vw, 6rem)` for section gaps

### 8. Encode Motion Philosophy
- Spring physics: `stiffness: 100, damping: 20`. No linear easing
- Perpetual micro-interactions on active components
- Staggered cascade reveals
- Animate only `transform` and `opacity`

### 9. List Anti-Patterns
Encode as explicit "NEVER DO" rules:
- No emojis, no `Inter`, no generic serif
- No pure black, no neon glows, no oversaturated accents
- No gradient text on large headers, no custom cursors
- No overlapping elements, no 3-column equal grids
- No generic names, no fake numbers, no AI clichés
- No filler UI text, no broken Unsplash links
- No centered Hero (high-variance projects)

## Output Format

```markdown
# Design System: [Project Title]

## 1. Visual Theme & Atmosphere
(Evocative description of mood, density, variance, motion intensity)

## 2. Color Palette & Roles
- **Canvas White** (#F9FAFB) — Primary background
- **Charcoal Ink** (#18181B) — Primary text
- **[Accent Name]** (#XXXXXX) — Single accent
(Max 1 accent. Saturation < 80%.)

## 3. Typography Rules
- **Display:** [Font] — Track-tight, weight-driven hierarchy
- **Body:** [Font] — Relaxed leading, 65ch max-width
- **Mono:** [Font] — Code, metadata, timestamps

## 4. Component Stylings
* **Buttons:** Flat, tactile -1px on active
* **Cards:** Rounded 2.5rem, whisper shadow, hierarchy-only
* **Inputs:** Label above, error below, accent focus ring

## 5. Layout Principles
(Grid-first, asymmetric, single-column collapse < 768px)

## 6. Motion & Interaction
(Spring physics, staggered reveals, hardware-accelerated)

## 7. Anti-Patterns (Banned)
(Explicit forbidden list)
```

## Best Practices
- Be descriptive: "Deep Charcoal Ink (#18181B)" not just "dark text"
- Be functional: Explain what each element is used for
- Be consistent: Same terminology throughout
- Be precise: Include exact hex, rem, px values
- Be opinionated: This enforces a specific premium aesthetic
