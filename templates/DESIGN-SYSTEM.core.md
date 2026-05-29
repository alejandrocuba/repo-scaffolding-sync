# Core Design System Specification

This document is the **single source of truth** for central visual styling, layout responsiveness, animation performance, and accessibility standards across all projects.

> [!NOTE]
> Project-specific typography, assets, colors, and components are defined in the project's root `DESIGN-SYSTEM.md` and inherit these rules.

## 1. Performance & Rendering Philosophy
* **Rendering**: Use `content-visibility: auto` + `contain-intrinsic-size` (using relative units `lh`/`rem`) on off-screen/content-heavy sections to prevent DOM render lag. Use `contain: layout style paint` for component isolation.
* **Transitions**: Use `transition-behavior: allow-discrete` + `@starting-style` to animate discrete properties (e.g., toggling `display: none` or `<dialog>`/`popover` overlays) natively.

## 2. Animation & Interaction Guardrails
* **Compositor**: Animate only CSS-first properties: `transform` (including individual translation/rotation properties) and `opacity`. Do not animate layout-triggering properties (`width`, `height`, margins, offsets).
* **Speed**: Keep durations snappy (normally `<300ms`) using standard ease-in-out (`cubic-bezier(0.4, 0, 0.2, 1)`) or physics-based easing (`linear()` / spring).
* **Reduced Motion**: Respect `prefers-reduced-motion` by scaling down or adjusting durations (using an `--animation-reduced` property) rather than flatly disabling all animations.
* **Interactivity & States**:
  * Use `:focus-visible` with `outline` + `outline-offset` for custom focus rings. Never use `outline: none` without a visible alternative.
  * Use `:user-invalid` / `:user-valid` for form validation to avoid showing premature errors on load.
  * Use `:has()` for parent styling based on child states (e.g., `form:has(:invalid)`), avoiding JS-staged classes.

## 3. Layout, Responsiveness & Viewports
* **Logical Properties**: Use logical properties (`inline-size`, `block-size`, `margin-inline`, `padding-block`, `inset-inline-start`) instead of physical properties (`width`, `height`, etc.) to support RTL and system translations natively.
* **Container Queries**: Require `@container` queries (`container-type: inline-size` or `size` on parents) for components. Avoid viewport media queries. Use `cqi`/`cqb` units for fluid internal spacing/typography.
* **Grid & Subgrid**: Use CSS Grid for 2D structures and Flexbox for 1D. Use `subgrid` (`grid-template-rows: subgrid`) to align nested content (titles, metadata, CTA blocks) across sibling grid cards. Set item spacing using `gap` instead of margins.
* **Viewport Mechanics**: Use dynamic viewport units (`dvh`/`dvw` or `dvb`/`dvi`) for full-viewport sizing. Avoid horizontal overflow: never use `100vw` for full-width blocks; prefer `100%` or `100dvw`.
* **Layout Stability**: Apply `scrollbar-gutter: stable` to scrollable containers to prevent shifts when content length changes.

## 4. Typography Rules
* **Sizing**: Use relative units (`rem`, `em`). Banish absolute `px`. Combine viewport/container units in `clamp()` (e.g., `clamp(1rem, 0.8rem + 1cqi, 2.5rem)`) for fluid scaling.
* **Line Height**: Maintain unitless values: `1.5`-`1.6` for body text, and `1.2`-`1.3` for headings.
* **Wrapping**: Use `text-wrap: balance` for headings (under 4 lines) and `text-wrap: pretty` for paragraphs. Apply selectively.
* **Fallbacks**: Declare generic fallbacks (e.g., `system-ui, sans-serif`) on all font-family definitions.

## 5. Accessibility & HTML Validation
* **Semantics**: Use semantic HTML5 tags (`<main>`, `<section>`, etc.) and correct ARIA mapping.
* **Validation**: Maintain valid HTML layouts. Avoid duplicate IDs, nesting interactive elements (e.g., `<button>` inside `<a>`), and invalid DOM parenting (e.g., non-list items directly inside `<ul>`).
* **Forms & Inputs**: Always use explicit `<label>` associations and provide correct `autocomplete` attributes on inputs to support native browser password managers and autofill.
* **Touch Targets**: Enforce a minimum target size of `44px x 44px` on mobile screens using padding or logical dimensions.
* **Contrast**: Satisfy WCAG 2.2 AA (min. 4.5:1 for body copy, 3:1 for headers/interactive borders).
* **Forced Colors Mode**: Ensure layouts remain usable in High Contrast Mode. Do not rely on background-images, box-shadows, or gradients for borders/indicators. Use `border` or `outline` styled with system color keywords (e.g. `CanvasText`, `LinkText`, `ButtonText`, `Highlight`) inside `@media (forced-colors: active)`.

## 6. Theming & Dark Mode
* **Anti-FOUC**: Declare supported schemes using `<meta name="color-scheme" content="light dark">` in the document `<head>`. Load user themes via a brief inline blocking script reading from `localStorage`.
* **System Color-Scheme**: Set `color-scheme: light dark` on `:root`/`html` to automatically theme default scrollbars and native inputs.
* **Semantic Tokens**: Define design colors using `light-dark()`, with media query and `@supports` checks to supply fallbacks for older browsers (see standard template pattern in `DESIGN-SYSTEM.md`).
* **Subtree Isolation**: Override the global theme locally (e.g., `color-scheme: dark` on code blocks/media players) as needed.

## 7. Media & Asset Performance
* **Layout Shift (CLS)**: Always specify explicit `width` and `height` dimensions or CSS `aspect-ratio` on `<img>` elements. Banish stretched/distorted images (use `object-fit: cover`/`contain`).
* **Resource Priority (LCP)**: Bypassing lazy loading for above-the-fold/hero assets; utilize `fetchpriority="high"` or `preload`. Apply `<img loading="lazy">` to all off-screen assets.
* **Modern Formats**: Serve raster images in next-gen formats (AVIF or WebP) rather than legacy JPEGs/PNGs for optimal payload sizes.

## 8. Styling Adherence
* **Tokens**: Strictly use core and project-specific design tokens. Never write ad-hoc styles, hardcoded colors, or custom fonts without authorization.


