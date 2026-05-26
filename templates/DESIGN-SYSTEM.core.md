# Core Design System Specification

This document is the **single source of truth** for core visual styling, layout responsiveness, animation performance, and accessibility standards across all projects.

> [!NOTE]
> Project-specific design tokens (such as specific colors, typography font families, and custom elements) are defined in the repository's root `DESIGN-SYSTEM.md` and inherit these rules.

## 1. Performance & Rendering Philosophy
All projects prioritize high performance, readability, and content delivery above excessive graphical weight. Design layout structure must prioritize fluid layout transitions and optimized rendering paths.

## 2. Animation & Interaction Guardrails
To ensure a fluid, high-performance experience and prevent UI lag:
* Use strictly CSS-first, hardware-accelerated properties: `transform` and `opacity`.
* Avoid animating layout-triggering properties (e.g., `width`, `height`, `margin`, `top/left/bottom/right`).
* Implement standard easing curves (e.g., standard ease-in-out: `cubic-bezier(0.4, 0, 0.2, 1)`).
* Keep transition durations short and snappy (normally under `300ms`).
* Respect the `prefers-reduced-motion` media query to ensure accessible motion.
* **Passive Listeners**: Any interaction binding to wheel, touch, or scroll events must register as a passive listener (`{ passive: true }`) to prevent blocking thread-level scrolling and animations.

## 3. Layout, Responsiveness & Accessibility
* Define base grid structure (e.g., 12-column grid, CSS Grid/Flexbox conventions).
* Core breakpoints:
  * Mobile: `< 640px`
  * Tablet: `640px` - `1024px`
  * Desktop: `> 1024px`
* **Touch Targets**: All interactive elements (buttons, links, form inputs) must have a minimum touch target size of `44px x 44px` on mobile displays to comply with accessibility standard WCAG 2.2 AA.

## 4. Typography Rules
* **Line Height**: Maintain `1.5` - `1.6` for body copy to preserve readability, and `1.2` - `1.3` for headers.
* Avoid browser default styling without setting a proper generic fallback list (e.g. `system-ui, sans-serif`).

## 5. Color Palette & Contrast Validation
* **Contrast Compliance**: All foreground/background color combinations must satisfy the **WCAG 2.2 AA** contrast ratio threshold (minimum 4.5:1 for normal body text, 3:1 for large display text or interactive borders).

## 6. Media & Asset Performance
To ensure optimized Largest Contentful Paint (LCP) and zero Cumulative Layout Shift (CLS):
* **Aspect Ratio Preservation**: Always specify explicit `width` and `height` dimensions on `<img>` elements or define them in CSS (e.g., `aspect-ratio: 16/9`) to prevent layout shifts as images load.
* **Aspect Ratio Constraints**: Do not stretch or distort images. Use `object-fit: cover` or `object-fit: contain` for flexible containers.
* **Loading Priority**:
  * Off-screen assets (below the fold) must be lazy-loaded using `<img loading="lazy">`.
  * Hero images or critical above-the-fold assets must bypass lazy loading and utilize `fetchpriority="high"` or preloads.
