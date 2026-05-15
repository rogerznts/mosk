# Task: Brutalist Style

Apply the Industrial Brutalism & Tactical Telemetry design language to the current work.

## When to use

- User asks for brutalist, industrial, terminal, military, or Swiss typography aesthetic
- Data-heavy dashboards, portfolios, or editorial sites that need to feel like declassified blueprints

## Visual Archetypes

Pick ONE per project and commit to it. Do not mix both modes within the same interface.

### Swiss Industrial Print
Derived from 1960s corporate identity systems and heavy machinery blueprints.
* High-contrast light modes (newsprint/off-white substrates). Reliance on monolithic, heavy sans-serif typography. Unforgiving structural grids outlined by visible dividing lines. Aggressive, asymmetric use of negative space punctuated by oversized, viewport-bleeding numerals or letterforms. Heavy use of primary red as an alert/accent color.

### Tactical Telemetry & CRT Terminal
Derived from classified military databases, legacy mainframes, and aerospace Heads-Up Displays (HUDs).
* Dark mode exclusivity. High-density tabular data presentation. Absolute dominance of monospaced typography. Integration of technical framing devices (ASCII brackets, crosshairs). Application of simulated hardware limitations (phosphor glow, scanlines, low bit-depth rendering).

## Typographic Architecture

Typography is the primary structural and decorative infrastructure. Imagery is secondary.

### Macro-Typography (Structural Headers)
* **Fonts:** Neue Haas Grotesk (Black), Inter (Extra Bold/Black), Archivo Black, Roboto Flex (Heavy), Monument Extended.
* **Scale:** Massive using fluid typography (`clamp(4rem, 10vw, 15rem)`).
* **Tracking:** Extremely tight, often negative (`-0.03em` to `-0.06em`).
* **Leading:** Highly compressed (`0.85` to `0.95`).
* **Casing:** Exclusively uppercase.

### Micro-Typography (Data & Telemetry)
* **Fonts:** JetBrains Mono, IBM Plex Mono, Space Mono, VT323, Courier Prime.
* **Scale:** Fixed and small (`10px` to `14px` / `0.7rem` to `0.875rem`).
* **Tracking:** Generous (`0.05em` to `0.1em`).
* **Leading:** Standard to tight (`1.2` to `1.4`).
* **Casing:** Exclusively uppercase. Used for all metadata, navigation, unit IDs, and coordinates.

### Textural Contrast (Artistic Disruption)
* **Fonts:** Playfair Display, EB Garamond, Times New Roman.
* Used exceedingly sparingly. Must be subjected to heavy post-processing (halftone filters, 1-bit dithering).

## Color System

Gradients, soft drop shadows, and modern translucency are strictly prohibited.

**Choose ONE substrate palette per project.**

### Swiss Industrial Print (Light)
* **Background:** `#F4F4F0` or `#EAE8E3` (Matte, unbleached documentation paper).
* **Foreground:** `#050505` to `#111111` (Carbon Ink).
* **Accent:** `#E61919` or `#FF2A2A` (Aviation/Hazard Red). ONLY accent color.

### Tactical Telemetry (Dark)
* **Background:** `#0A0A0A` or `#121212` (Deactivated CRT. Avoid pure `#000000`).
* **Foreground:** `#EAEAEA` (White phosphor).
* **Accent:** `#E61919` or `#FF2A2A` (Aviation/Hazard Red).
* **Terminal Green (`#4AF626`):** Optional. Use ONLY for a single specific UI element — never as a general text color.

## Layout and Spatial Engineering

* **Blueprint Grid:** Strict CSS Grid. Elements anchored precisely to grid tracks and intersections.
* **Visible Compartmentalization:** Solid borders (`1px` or `2px solid`) to delineate zones. `<hr>` spans full container width.
* **Bimodal Density:** Extreme data density mixed with vast negative space framing macro-typography.
* **Geometry:** Absolute rejection of `border-radius`. All corners exactly 90 degrees.

## UI Components and Symbology

* **Syntax Decoration:** `[ DELIVERY SYSTEMS ]`, `< RE-IND >`, `>>>`, `///`
* **Industrial Markers:** `®`, `©`, `™` as structural geometric elements.
* **Technical Assets:** Crosshairs (`+`) at grid intersections, barcode lines, warning stripes, randomized strings (`REV 2.6`, `UNIT / D-01`).

## Textural and Post-Processing Effects

* **Halftone / 1-Bit Dithering:** Dot-matrix patterns via CSS `mix-blend-mode: multiply` with SVG radial dot patterns.
* **CRT Scanlines:** `repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0,0,0,0.1) 2px, rgba(0,0,0,0.1) 4px)`.
* **Mechanical Noise:** Low-opacity SVG static/noise filter on DOM root.

## Engineering Directives

1. Use `display: grid; gap: 1px;` with contrasting parent/child backgrounds for razor-thin dividing lines.
2. Use precise semantic tags (`<data>`, `<samp>`, `<kbd>`, `<output>`, `<dl>`).
3. Implement CSS `clamp()` for macro-typography to scale aggressively across viewports.
