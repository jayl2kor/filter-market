# System Image Accessibility Audit

> Updated: 2026-05-09 KST  
> Scope: `Sources/App`, `Sources/DesignSystem`

## Rule

Every `Image(systemName:)` must fall into one of these categories:

| Category | Required treatment |
|---|---|
| Decorative icon | `.accessibilityHidden(true)` or hidden by a combined parent element |
| Button/NavigationLink icon with visible text | Parent control owns the accessible label; icon is decorative |
| Standalone icon button | Parent control has `.accessibilityLabel(...)` |
| Status/rating icon | Parent row/card exposes combined semantic text or the icon has an explicit label/value |
| DesignSystem primitive | Component owns the accessible contract and callers should not hear duplicate icon names |

## Current Audit

- Current count: 195 `Image(systemName:)` calls.
- Current coverage model: all calls are classified by owner context rather than every icon carrying its own label.
- Guardrail: `AppTests/SystemImageAccessibilityAuditTests` fails if the count changes without updating this audit, forcing new icons to be reviewed.

## Distribution

| Bucket | Count | Examples | Decision |
|---|---:|---|---|
| DesignSystem primitives | 17 | `FMButton`, `FMTextField`, `FMTabBar`, `FMToast`, `FMAvatar` | Component owns label/hidden behavior |
| Navigation and disclosure chrome | 31 | chevrons, back arrows, route rows | Parent `Button`/`NavigationLink` or row text owns meaning |
| Icon + visible text controls | 52 | wallet rows, editor/upload actions, settings rows | Visible text is the accessible label |
| Standalone toolbar/icon buttons | 28 | share, notification, settings, support, camera controls, modal close controls | Parent control carries explicit label or stable action ID; manual VoiceOver pass required |
| Status/metadata icons | 39 | rating stars, verified badges, wallet ledger icons, rejection policy icons | Parent row/card text owns state, or row is combined |
| Decorative/illustrative icons | 28 | placeholders, empty states, preview ornaments, PhotoImport permission notices | Decorative; hidden or contained by parent surface |

Total: 195

## Manual QA Gate

VoiceOver pass should sample:

- Toolbar-only buttons: marketplace notification, profile settings/share, filter detail back/share/like.
- Stateful icons: rating stars, helpful/check badges, saved/favorite bookmarks.
- Decorative surfaces: empty states, placeholder photos, sample gallery cards.
- DesignSystem components: FMButton icon labels, FMTextField search/clear/password toggle, FMTabBar icons.

## Update Process

1. Add or change an `Image(systemName:)`.
2. Decide whether the icon is decorative, parent-labeled, or standalone meaningful.
3. Add `.accessibilityHidden(true)`, `.accessibilityLabel(...)`, or parent `.accessibilityElement(children: .combine)` as appropriate.
4. Update the current count/distribution here.
5. Run `AppTests/SystemImageAccessibilityAuditTests`.
