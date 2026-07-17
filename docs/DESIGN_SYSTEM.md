# Tái Chế Xanh — Product Design System

## Product direction

The interface follows a **Jade Night × Warm Paper** art direction: deep jade
surfaces communicate trust and field operations, while warm paper backgrounds
keep citizen flows calm and approachable. Apricot and coral are reserved for
attention, rewards, and time-sensitive actions.

The product avoids a generic dashboard aesthetic. Each role has a distinct job:

- Citizen: discover, report, and follow the collection journey.
- Collector: see the next job, navigate, and complete it safely.
- Enterprise: triage requests, coordinate people, and read operations.
- Admin: manage accounts and resolve exceptions with higher information density.

## Core tokens

Tokens live in `lib/src/ui/shared/app_theme.dart`.

- Color: `AppPalette`
- Space: `AppSpacing`
- Radius: `AppRadii`
- Motion: `AppMotion`
- Material theme: `AppTheme.light()`

Feature code should use these tokens rather than raw colors, corner radii, or
animation durations. Important controls remain at least 44 logical pixels.

## Shared components

Reusable components live in `lib/src/ui/shared/widgets.dart`. Prefer
`AppSurface`, `SectionTitle`, `StatusChip`, `ReportCard`, `AppMetric`,
`AppLoadingView`, and the brand components before creating a feature-local
equivalent.

## Assets

- `assets/images/eco_city_hero.jpg`: optimized in-app editorial hero.
- `assets/images/eco_city_hero.png`: lossless source artwork.
- `assets/images/app_icon_master.png`: original launcher icon master.

Both assets were generated specifically for this project and contain no
third-party marks or embedded text. Native launcher icon sizes are derived from
the master artwork.

## Product truth

The current API does not expose a collector's public live location, vehicle,
schedule, or ETA. Citizen UI may show report locations and real report states,
but must not imply that a truck is being tracked live until those backend
capabilities exist.
