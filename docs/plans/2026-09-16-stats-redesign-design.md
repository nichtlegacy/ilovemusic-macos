# History and Stats redesign

## Goal

Turn the current card-heavy analytics dashboard into a calm, native macOS workspace. Preserve the existing local history data, aggregation semantics, filters, and context actions while improving hierarchy, resizing, chart interaction, accessibility, and window behavior.

## Reference and design choice

The chosen direction is an overview-first design. The first viewport should answer how much the user listened, whether usage is changing, and what dominated the selected period. Detailed distributions and rankings remain available farther down the page without competing with the primary trend.

CodexBar is the reference for compact chart proportions, adaptive geometry, pointer interaction, semantic surfaces, and accessibility. ILoveMusic will not copy its provider/source architecture or turn this window into a dense power dashboard.

## Window and toolbar

- Keep History and Stats in one auxiliary `NSWindow`.
- Use a full-size content view with a transparent title bar and a unified native toolbar.
- Put a native segmented control for History and Stats in the toolbar.
- Put the Stats time-range picker at the trailing side of the toolbar and show it only for Stats.
- Persist the selected destination, selected time range, window position, and window size.
- Use a default content size near 1040 by 760 points and a minimum near 760 by 560 points.
- Restore a saved frame before deciding to center the window. Do not recenter a restored window.
- Keep the window resizable, closable, and miniaturizable.

The toolbar replaces the current custom capsule navigation and content divider. It should use standard macOS focus, keyboard, hover, and accessibility behavior.

## Stats hierarchy

The page uses a single vertical scroll view with approximately 24 points of outer padding and 18 points of vertical rhythm. Content receives a maximum readable width and stays centered when the window becomes very wide.

The order is:

1. A compact summary strip with total listening time, today's listening time, streak, and average session.
2. A full-width Listening Trend as the primary visualization.
3. Top Channels and Genre Distribution as supporting breakdowns.
4. Listening by Hour and the Weekday by Hour heatmap as behavior patterns.
5. Top Artists and Top Songs as compact rankings.

The summary metrics become compact cells in one shared surface rather than four independent large cards. The average session moves into this strip instead of appearing as detached footer text.

The primary trend gets the strongest heading and the most space. Supporting panels use restrained semantic fills and separators. They do not all receive equal visual weight.

## Responsive layout

The layout responds to available content width rather than assuming two columns:

- At comfortable widths, supporting modules use two columns.
- At medium widths, the main trend remains full width and supporting modules use adaptive columns where their content still fits.
- At narrow widths, all modules become a single column. Legends move below charts and rankings reduce their initially visible rows.
- The heatmap, donut, labels, and chart plot areas derive their geometry from the proposed size.
- Charts keep a compact target height around 170 to 190 points unless their content genuinely needs more room.

Responsive decisions should live in small, testable layout helpers instead of being scattered as geometry checks throughout the views.

## Surfaces and typography

- Use system fonts, semantic colors, and the app's accent only for data emphasis and selection.
- Use a subtle quaternary or material surface for grouped modules, a separator-color border, approximately 14-point corner radii, and 16-point internal padding.
- Remove decorative gradients and heavy borders from data surfaces.
- Use clear section titles, optional one-line context, and compact secondary labels.
- Keep numbers monospaced where changing digits would otherwise shift the layout.
- Support light and dark appearances, increased contrast, and reduced transparency.

## Chart behavior

Listening Trend, Listening by Hour, and Top Channels should expose the value nearest the pointer. Hovering highlights the active datum and shows a compact tooltip containing its label and formatted listening duration. The geometry used for drawing and hit testing must share one source of truth.

Charts should use explicit domains and compact axis formatting. Edge labels must stay readable instead of being clipped by the plot bounds. The trend can retain a restrained area treatment, but the line and selected point carry the emphasis.

The heatmap computes cell size from available width. It supports:

- hover highlighting and a tooltip;
- click selection;
- keyboard focus and arrow-key movement;
- an intensity legend and a distinct unavailable-data state;
- accessibility children that describe weekday, hour, and listening duration.

Every chart also receives a useful overall accessibility label and value. Individual bars, points, segments, or heatmap cells expose meaningful values where practical.

## Empty and sparse data

When there are no events for the selected period, show one clear page-level empty state with a short explanation and a way to choose a broader period. Do not render a grid of individually empty cards.

Sparse data keeps the normal structure but avoids misleading interpolation or inflated chart domains. Rankings show only rows that exist.

## History destination

History remains an equal destination in the same window. Its content becomes quieter and more native:

- use a native search field and a compact station filter;
- keep the result count secondary;
- retain day grouping, copying, and filtering context actions;
- replace large gradient cards with compact list rows and native selection/hover behavior;
- keep artwork, title, artist, station, time, and duration aligned in stable columns;
- preserve the existing empty and no-match actions.

The redesign should also make the mixed German and English interface copy internally consistent. It must follow the language convention selected for the rest of the app rather than introducing a new localization system in this work.

## State and architecture

`PlayHistoryStats`, `StatsSnapshot`, `StatsSnapshotProvider`, and existing preference keys remain the source of truth. Presentation code must not duplicate or reinterpret aggregation logic.

Introduce only the small state needed for:

- selected destination and time range;
- hover or keyboard chart selection;
- responsive layout decisions.

Extract pure chart hit-testing and layout calculations where they can be tested without rendering SwiftUI. Avoid a new dashboard framework or generic chart abstraction.

## Verification

- Add focused tests for persisted destination fallback, window configuration, frame restoration behavior, responsive column decisions, and pure chart hit-testing or edge-label layout.
- Keep all existing history recording, aggregation, snapshot caching, settings, and persistence tests passing.
- Build and sign the release app.
- Open the window through both the menu and the menu-bar footer.
- Verify History and Stats at the default, minimum, tall, and very wide sizes.
- Verify restored position and size after closing and reopening.
- Exercise every time range with empty, sparse, and populated histories.
- Check chart hover, selection, keyboard navigation, and VoiceOver descriptions.
- Check light and dark appearances, increased contrast, and reduced transparency.
- Update the README screenshot only after the final runtime UI has been visually verified.

## Non-goals

- No changes to history recording or statistics formulas
- No new metrics, remote analytics, export, or cloud synchronization
- No arbitrary custom date-range picker
- No provider/source architecture copied from CodexBar
- No general-purpose chart framework
- No redesign of the player popover or Settings window
