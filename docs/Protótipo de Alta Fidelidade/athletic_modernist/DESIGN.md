---
name: Athletic Modernist
colors:
  surface: '#f7f9fb'
  surface-dim: '#d8dadc'
  surface-bright: '#f7f9fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f6'
  surface-container: '#eceef0'
  surface-container-high: '#e6e8ea'
  surface-container-highest: '#e0e3e5'
  on-surface: '#191c1e'
  on-surface-variant: '#3e4a3d'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f3'
  outline: '#6e7b6c'
  outline-variant: '#bdcaba'
  surface-tint: '#006e2d'
  primary: '#006b2c'
  on-primary: '#ffffff'
  primary-container: '#00873a'
  on-primary-container: '#f7fff2'
  inverse-primary: '#62df7d'
  secondary: '#565e74'
  on-secondary: '#ffffff'
  secondary-container: '#dae2fd'
  on-secondary-container: '#5c647a'
  tertiary: '#755800'
  on-tertiary: '#ffffff'
  tertiary-container: '#936f00'
  on-tertiary-container: '#fffbff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#7ffc97'
  primary-fixed-dim: '#62df7d'
  on-primary-fixed: '#002109'
  on-primary-fixed-variant: '#005320'
  secondary-fixed: '#dae2fd'
  secondary-fixed-dim: '#bec6e0'
  on-secondary-fixed: '#131b2e'
  on-secondary-fixed-variant: '#3f465c'
  tertiary-fixed: '#ffdf9a'
  tertiary-fixed-dim: '#f7be1d'
  on-tertiary-fixed: '#251a00'
  on-tertiary-fixed-variant: '#5a4300'
  background: '#f7f9fb'
  on-background: '#191c1e'
  surface-variant: '#e0e3e5'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
  display-lg-mobile:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  title-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  title-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
  title-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system blends Material Design 3 ergonomics with an energetic, modern athletic aesthetic. Designed for swift, friction-free sports court discovery and booking, the interface prioritizes legibility, high visual clarity under bright outdoor conditions, and tactile interaction.

The personality balances athletic dynamism with procedural reliability:
- **Tone:** Energetic, inviting, dependable, and swift.
- **Visual Style:** Modern Corporate Athletic. It utilizes clean Material 3 surface tiers (`surface-container`), high-contrast slate typography, crisp geometric cues, and vibrant lawn-green accents reminiscent of synthetic turf and indoor court lines.
- **Emotional Response:** Inspires enthusiasm for active play ("just one more game"), reassuring users of seamless scheduling with immediate, glanceable status indicators.

## Colors

The color system structures hierarchy through chromatic functionalism:

- **Primary (`#16A34A` / accents `#15803D` & `#22C55E`):** Represents vitality, open turf, and confirmation. Used for call-to-actions, active chip states, and selected court slots.
- **Secondary (`#0F172A` Slate Dark):** Acts as the grounding anchor for primary headings, high-emphasis text, bottom navigation icons, and structural focus.
- **Tertiary (`#EAB308` Court Yellow):** Used for highlighting special promotions, star ratings, and urgent notifications (e.g., "Last 2 spots").
- **Neutral Surface Palette:**
  - Canvas / Background: `#F8FAFC` (Slate 50)
  - Surface Low / Card Base: `#FFFFFF`
  - Surface Container / Muted Trays: `#F1F5F9` (Slate 100)
  - Surface Border / Dividers: `#E2E8F0` (Slate 200)
  - Text Muted / Body Secondary: `#64748B` (Slate 500)
- **Court Slot Status Semantics:**
  - **Available (Livre):** Surface `#DCFCE7` (Emerald 100), Outline `#22C55E` (Emerald 500), Text `#15803D` (Emerald 700).
  - **Occupied / Booked (Ocupado):** Surface `#F1F5F9` (Slate 100), Outline `#CBD5E1` (Slate 300), Text `#94A3B8` (Slate 400).
  - **Passed (Passado):** Surface `#E2E8F0` (Slate 200), Border transparent, Text `#94A3B8` with strikethrough styling and disabled touch handling.

## Typography

The typography leverages Inter for maximum numeric clarity and neutral geometric legibility across mobile displays.

- **Display & Headline:** Used sparingly for onboarding greetings, court titles, and high-impact hero screens. `display-lg-mobile` guarantees robust readability without truncating facility names.
- **Titles & Labels:** Optimized for tabular slot metrics, chip names, timestamps, and bottom bar labels. Tabular numeric figures should be enabled for time ranges (`18:00 - 19:00`) to keep grids aligned.
- **Body:** Neutral slate coloring ensures effortless scanning over booking terms, court amenities, and location directions.

## Layout & Spacing

The layout is built upon an 8dp/4dp strict incremental grid model optimized for Android handheld interfaces.

- **Columns & Margins:**
  - Mobile (Compact, < 600dp): 4 columns, 16dp (`margin: 1rem`) screen gutter and margin.
  - Tablet (Medium, 600dp - 840dp): 8 columns, 24dp margins, centered content container with a maximum width of 720dp for single-hand scheduling sheets.
- **Horizontal Carousels:** Date selectors and sports category filters break out to full screen bleed, padding their leading item by `1rem` to align strictly with vertical page margins.
- **Touch Targets:** Interactive slot cards, date tokens, and buttons enforce a 48dp minimum physical target area to facilitate tap precision before or during physical activity.

## Shapes

The shape system adopts Material 3 curvature hierarchy:

- **Large Structural Elements (Cards, Modal Sheets):** `16px` to `24px` radius (`rounded-lg` to `rounded-xl`). Creates friendly, polished container silhouettes that accommodate high-density visual content.
- **Interactive Controls (Buttons, Text Inputs, Segmented Controls):** `10px` to `12px` radius. Delivers tactile feedback without turning fully circular.
- **Filter Chips & Badges:** Full pill-shaped radius (`9999px`) or `8px` rounded rectangles for sport tag pills, maintaining high distinction against square-ish court cards.

## Components

### Sport Filter Chips
- **States:** Default (unselected) has a `1px` border of `#E2E8F0`, `#FFFFFF` background, `#0F172A` text, and sport icon in `#64748B`. Selected state fills with `#16A34A`, white text, white icon, and no border.
- **Padding:** `8px 16px`, height `36px`, rounded `9999px`.

### Horizontal Date Picker
- Horizontal scroll strip displaying Day of week (label-sm, muted) stacked over Day number (title-md, bold).
- Selected day turns into a `#16A34A` background card with white typography and a subtle glow.
- Unselected days maintain a `#FFFFFF` container with `#E2E8F0` border and `#0F172A` label.

### Court Cards (Card de Quadra)
- **Layout:** High-aspect 16:9 court image container with rounded top corners (16dp).
- **Distance Tag:** Positioned overlay top-right or below title: badge with `#0F172A` semi-translucent background, white text (`label-sm`), pin icon.
- **Content Area:** Title in `title-md`, pricing (`R$ / hora`) anchored on the right, badges for surface type (Society, Saibro, Sintética) along the bottom.

### 60-Minute Interactive Slot Matrix
- **Available:** `#DCFCE7` fill, border `1px solid #22C55E`, `#15803D` bold text. On touch/selection: turns solid `#16A34A` with `#FFFFFF` text.
- **Occupied:** Background `#F1F5F9`, border `1px solid #E2E8F0`, text `#94A3B8`. Displays a small lock icon or "Ocupado" caption.
- **Passed:** Background `#E2E8F0`, text `#94A3B8` struck-through, click-disabled.

### Buttons & Inputs
- **Primary Action Button:** Solid `#16A34A`, height `48dp`, border-radius `12px`, typography `label-lg` white. Ripple effect uses `#15803D`.
- **Input Fields:** Outlined Material style with `1px solid #CBD5E1`, transitioning to `2px solid #16A34A` on focus. Background remains `#FFFFFF`.

### Bottom Navigation Bar
- Grounded fixed bar at the bottom, height `64dp` + system bar padding, background `#FFFFFF` with `1px` top border in `#E2E8F0`.
- 3 Tabs: **Quadras** (Courts), **Reservas** (Bookings), **Perfil** (Profile).
- Active item uses active indicator pill with subtle emerald tint `#DCFCE7` and primary `#16A34A` icon/label. Inactive items remain `#64748B`.