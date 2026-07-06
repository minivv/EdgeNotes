# EdgeNotes

EdgeNotes is a small macOS edge-panel notes app. Move the pointer to the configured screen edge, open the panel, and keep folders and note cards close without switching apps.

## Features

- Edge-triggered notes panel with left or right screen placement.
- Folder and note cards with drag ordering, pinning, collapse controls, and color choices.
- Live Markdown editing for common writing syntax such as headings, emphasis, lists, blockquotes, and tasks.
- Theme presets bundled with the app.
- Optional GitHub Gist backup.
- Menu bar controls for showing the side panel, opening settings, and quitting the app.

## Download

Download the latest `EdgeNotes-macOS.zip` from the GitHub Releases page, unzip it, and move `EdgeNotes.app` to `/Applications`.

The app is currently distributed without Apple notarization. On first launch, macOS may require opening it from Finder with Control-click > Open.

## Build From Source

Requirements:

- macOS 14 or newer
- Xcode command line tools
- Swift 5.10 or newer

```bash
swift build
script/build_and_run.sh --verify
```

To create a release zip:

```bash
script/package_release.sh
```

The packaged app will be written to `dist/EdgeNotes-macOS.zip`.

## Themes

Themes in `themes/*.edgetheme` are bundled directly into the app at build time. Do not ignore or remove this folder unless you intentionally want to ship only the built-in fallback themes.

## License

MIT
