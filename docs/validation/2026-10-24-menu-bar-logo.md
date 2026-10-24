# Menu bar logo — 2026-10-24

- Replaced StatusIcon.svg with the exact path from the supplied logo, black on a transparent background. Adjusted only the viewport to center the mark and provide a legible width within the existing 18 pt status image.
- Retained template rendering in the asset catalog and installStatusItem(), allowing the system to adapt the single-color mark to menu bar appearance.
- Verified the SVG path matches the supplied source and contains no opaque background rectangle.
- Ran xcodegen generate and the README Debug xcodebuild command: BUILD SUCCEEDED. Log: build/icon-review/status-icon-build.log.
- Loaded StatusIcon from the built app bundle using AppKit and visually inspected its rendered preview: build/icon-review/status-preview.png.
- Did not restart the installed app; live menu bar rendering and dark appearance remain unverified. No Swift source changed.

README: unchanged — the icon replacement changes no usage or development commands; Composer maintenance remains documented.

AGENTS.md: unchanged — existing asset and build rules cover this replacement.
