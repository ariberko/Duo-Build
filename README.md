# DuoBuild

Describe an app in plain words, see a live preview, then refine it. Made for the foldable **iPhone Duo**.

**Describe → Preview → Refine**

- **Open (inner display)** - the builder chat and the live preview sit side by side. Ask for a change on the left, watch the preview update on the right.
- **Closed (cover display)** - one pane at a time, with a Builder / Preview switch at the top and a "Preview updated · View" button after each change.
- Works the same on any iPhone, iPad and Stage Manager window. The layout is picked only from the space the window has.

## What you can do

- Make a project: name it, describe it (or tap a starter idea) and tap **Create**.
- Refine it in the chat, or tap a suggested change.
- Use the preview: type in fields, tick list rows, tap buttons. **Refresh** redraws it. **Reset** clears what you typed.
- Pick a preview size: Fit to Pane, iPhone, Small iPhone.
- Every change is a saved version. **Version History** lets you restore any older one (restoring adds a new version, so nothing is lost).
- Rename, duplicate and delete projects (from the card's long-press menu or the ⋯ menu).
- Everything is saved on the device and is still there after you close the app.

## AI and Demo mode

DuoBuild never runs code from an AI. The AI only writes a small JSON **UI spec** that can use these parts: text, button, card, image (built-in symbols), list, input field, stack, divider and spacer, plus an accent color, background and spacing. DuoBuild checks the spec (`SpecValidator`) and draws it with real SwiftUI controls.

- **Demo mode** (default) - no AI and no network. Designs come from built-in templates and simple rules, like "make it green", "add a button that says Share", "add a list of milk, eggs and bread", "use a dark background", "rename it to …" or "remove the buttons". It is always labeled Demo. If it doesn't understand a request, it says so and changes nothing.
- **Claude (your own key)** - in Settings → AI Service → Claude, paste your Anthropic API key. DuoBuild checks it with the free model list call, then saves it in the iPhone Keychain (this device only). Requests go straight from the phone to `api.anthropic.com`, billed to your own Anthropic account. Pick Claude Opus 5.5, Sonnet 5.5 or Haiku 5.5. There's no DuoBuild server and the developer never sees the key. Code: `ClaudeAIService`, `SpecPrompt`, `Keychain`.
- **Your backend** - for a hosted version where you hold one key for everyone. Enter your server's https address. See [docs/BACKEND.md](docs/BACKEND.md).

## iPhone Duo notes

- Apple asks apps to adapt to the available size, not to ask "is it folded?". DuoBuild follows that: two panes when the window is at least 680 pt wide (or 600 pt in a regular-width size class), otherwise one pane. See `WorkspaceLayout`.
- All workspace state (draft text, preview input, preview size, chosen pane) lives above the panes, so opening or closing the phone mid-task loses nothing.
- **Not built: a tabletop layout** (preview on top half, controls on the bottom half). It needs an official hinge/posture API, and DuoBuild doesn't use unverified or guessed APIs. Once Apple documents one in the SDK, it can be added in `WorkspaceView`.
- No separate app runs on the second screen.

## Where things are

```
DuoBuild.swiftpm/      All app code. Opens in Swift Playgrounds on iPad.
  App/                 App entry point
  Sources/Model/       UISpec, Project, versions, SpecValidator
  Sources/AI/          AIService, Demo mode, backend service, settings
  Sources/Store/       ProjectStore (JSON file in Application Support), sample data
  Sources/Views/       Home, New Project, Workspace (builder, preview, history), renderer, settings
Tests/DuoBuildTests/   Unit tests (spec, demo engine, persistence, versions, layout)
project.yml            Builds the App Store app and tests from the same code (XcodeGen)
AppAssets/             App icon and accent color. Redraw the icon: python3 scripts/make_icon.py
```

## Build and run

1. On a Mac with Xcode 16 or newer: `brew install xcodegen`, then `xcodegen` in this folder.
2. Open `DuoBuild.xcodeproj` and run the `DuoBuild` scheme. Run tests with ⌘U.

Or on iPad: download the repo ZIP, unzip it in Files, tap `DuoBuild.swiftpm` and press ▶︎ in Swift Playgrounds.

## Automatic checks

- `.github/workflows/build.yml` - every push builds the app, runs the unit tests and builds the Playgrounds app on GitHub's Macs.
- `.github/workflows/screenshots.yml` - push a commit with `[screenshots]` in its message to get iPhone, iPhone dark and iPad mini screenshots on the `screenshots` branch.
- `.github/workflows/testflight.yml` - needs the repo secrets `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8`. Run "Upload to TestFlight", or push a commit with `[testflight]` in its message.
