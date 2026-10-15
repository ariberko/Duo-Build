# DuoBuild backend contract

DuoBuild can talk to **your own server** instead of Demo mode. The server holds the AI provider's API key and turns requests into a DuoBuild UI spec. The app never sends or stores an API key.

## Setup

- In the app: Settings → AI Service → **Your Backend**, then enter the address (must be `https://`; `http://localhost` is allowed for testing).
- Or ship a default in `project.yml` → `DuoBuildBackendURL`.

## Request

`POST <your address>` with `Content-Type: application/json`:

```json
{
  "schemaVersion": 1,
  "action": "generate",            // or "refine"
  "projectName": "Pocket Budget",   // only for "generate"
  "prompt": "A simple expense tracker",
  "spec": null,                     // the current spec, for "refine"
  "history": [ { "role": "user", "text": "…" }, { "role": "assistant", "text": "…" } ]
}
```

`history` holds up to the last 12 user and assistant messages.

## Response

`200` with:

```json
{
  "summary": "Built an expense tracker with a monthly total and recent list.",
  "spec": {
    "title": "Pocket Budget",
    "theme": { "accent": "green", "background": "system", "spacing": "medium" },
    "nodes": [
      { "type": "text", "text": "Pocket Budget", "style": "largeTitle" },
      { "type": "card", "text": "$1,284", "detail": "Spent this month", "symbol": "creditcard.fill" },
      { "type": "list", "items": ["Coffee · $4.50", "Train · $32"], "symbol": "dollarsign.circle" },
      { "type": "input", "text": "Amount" },
      { "type": "button", "text": "Add Expense", "message": "Expense added" }
    ]
  }
}
```

On an error, return a non-2xx status and optionally `{ "error": "message" }`. DuoBuild shows it and keeps the old design.

## The UI spec

| type | fields |
|------|--------|
| `text` | `text`, `style` (`largeTitle`, `title`, `headline`, `body`, `caption`), `color` |
| `button` | `text`, `message` (shown when tapped in the preview), `style: "caption"` for a secondary button, `color` |
| `card` | `text` (title), `detail`, `symbol`, `color`, `children` |
| `image` | `symbol` (an SF Symbol name), `size` (`small`, `medium`, `large`), `color` |
| `list` | `items` (strings), `symbol` |
| `input` | `text` (placeholder) |
| `stack` | `axis` (`vertical`, `horizontal`), `spacing`, `children` |
| `divider`, `spacer` | none |

Colors: `blue indigo purple pink red orange yellow green mint teal brown gray primary secondary`.
Backgrounds: `system grouped tinted dark`. Spacing: `none small medium large`.

Limits enforced by the app: at most 150 components, 5 levels of nesting, 400 characters per text and 30 list items. Unknown types show as an "Unsupported component" box. Unknown values fall back to defaults. Nothing in a spec is ever run as code, and images never load from the web.

## Suggested server prompt

Ask your model to answer **only** with JSON that matches the response above, to keep the existing `id` values when refining, and to change only what the user asked for.
