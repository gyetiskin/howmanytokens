# HowManyTokens

A lightweight macOS menu bar app that shows how much of your Claude and Gemini
usage allowance you have consumed.

```
                                          [icon] C 41%   Mon 14:22
```

Clicking the icon opens a panel with the five-hour and weekly windows, a reset
countdown, and how recently the figures were measured.

## Design principle: no invented numbers

The app displays only figures it actually knows. When a percentage is known it is
shown; when it is not, the space is left blank rather than filled with an
estimate.

This matters because the two providers expose very different things. Claude
reports a real usage percentage. Gemini does not — it exposes token counts and
nothing else. Deriving a percentage from token counts requires a quota figure the
provider never publishes, so the app does not guess one. If you know your own
limit you can enter it; otherwise you see the measured token count and no
percentage.

The same rule governs three other cases:

- While Claude Code is closed the bridge file stops refreshing. The panel states
  how old the reading is, and the menu bar prefixes the figure with `~`.
- Once a window's reset time has passed, the percentage held is no longer valid,
  so no number is shown at all.
- When the icon has no known level to display, it is drawn as an empty outline.

## Requirements

- macOS 14 or later
- Xcode Command Line Tools (full Xcode is not required)
- `jq`, which ships with macOS at `/usr/bin/jq`
- Claude Code, for the Claude figures
- Gemini CLI, for the Gemini figures

## Installation

```bash
git clone https://github.com/<owner>/howmanytokens.git
cd howmanytokens
./build.sh --install
open /Applications/HowManyTokens.app
```

`build.sh` compiles a release binary, assembles a `.app` bundle marked as a
background agent, signs it ad-hoc, and optionally copies it into `/Applications`.
Without `--install` the bundle is left in `dist/`.

To launch it at login:

```bash
osascript -e 'tell application "System Events" to make login item at end \
  with properties {path:"/Applications/HowManyTokens.app", hidden:true, name:"HowManyTokens"}'
```

Remove it later under System Settings, General, Login Items.

## Setting up the data sources

The app reads local files only. It makes no network requests and sends nothing
anywhere.

### Claude

Claude Code passes a JSON payload on stdin to whatever status line command you
configure, and that payload carries the real subscription usage:

```json
"rate_limits": {
  "five_hour": { "used_percentage": <0-100>, "resets_at": <unix epoch seconds> },
  "seven_day": { "used_percentage": <0-100>, "resets_at": <unix epoch seconds> }
}
```

A small bridge script captures that and writes it where the app can read it.
Install it:

```bash
cp statusline/howmanytokens-statusline.sh ~/.claude/
chmod +x ~/.claude/howmanytokens-statusline.sh
```

Then register it in `~/.claude/settings.json`, preserving any existing keys:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/howmanytokens-statusline.sh"
  }
}
```

The script writes `~/.claude/howmanytokens-usage.json` atomically, staging through
a temporary file so the app never reads a partial write. It also prints a short
summary to the status line, in the form `5h 41%  |  7d 18%  |  <model>`.

If you already use a status line command, merge the two lines that write the
bridge file into your own script rather than replacing it.

Two caveats worth knowing before you rely on this:

- The figures refresh only while Claude Code is running. They go stale otherwise,
  and the app says so rather than hiding it.
- Per Claude Code's own documentation, `rate_limits` is populated only for
  Claude.ai subscriptions, and only after the first API response of a session.
  Until then the panel explains why it is empty.

### Gemini

Gemini CLI reports token counts only through its telemetry stream, so telemetry
must be enabled and pointed at a local file. In `~/.gemini/settings.json`:

```json
{
  "telemetry": {
    "enabled": true,
    "target": "local",
    "outfile": "/Users/YOUR_USERNAME/.gemini/telemetry.jsonl",
    "logPrompts": false
  }
}
```

Use an absolute path; `~` is not expanded here. Setting `logPrompts` to `false`
matters: it keeps prompt text out of the file, leaving only the counts the app
needs.

If you point `outfile` somewhere else, tell the app with the `HMT_GEMINI_OUTFILE`
environment variable.

Gemini usage is recorded only from the moment telemetry is switched on. There is
no historical backfill.

## Usage

The menu bar shows a fill icon and the known percentages, for example
`C 41%  G 12%`. A provider with no known percentage is omitted rather than shown
as zero.

Click the icon for the detail panel:

- **Claude** — the five-hour and weekly windows, each with a percentage, a meter,
  and the time the window resets.
- **Gemini** — tokens used in the current five-hour window, with a percentage only
  if you have set a limit, plus a per-model breakdown.

The refresh button re-reads the files immediately. The gear button opens settings.

### Settings

| Setting | Description |
| --- | --- |
| Icon | Bar, Ring or Segments |
| Gemini 5h limit | Leave at 0 to show tokens without a percentage |
| Show Gemini | Hides the Gemini card and its menu bar entry |
| Show labels in menu bar | `C 41%` versus a bare `41%` |
| Refresh | 10, 20 or 60 seconds |

Claude has no limit setting because its real percentage comes from the provider.

### Icon

The menu bar icon is drawn rather than taken from SF Symbols, so the fill level is
visible in the icon itself. Colour indicates level: green, amber above 60 percent,
red above 85 percent. Stale data adds an orange dot.

To compare the three styles yourself:

```bash
HMT_ICON_PREVIEW=/tmp/icons.png ./.build/debug/HowManyTokens
```

This renders a sheet showing every style at several fill levels, against both dark
and light menu bar backgrounds.

## Diagnostics

To see what the app parsed without opening the interface:

```bash
HMT_DUMP=1 ./.build/debug/HowManyTokens
```

It prints each window, the age of the reading, and the exact string that would be
rendered in the menu bar.

Environment variables, useful for testing against fixtures:

| Variable | Purpose |
| --- | --- |
| `HMT_CLAUDE_FILE` | Path to the Claude bridge file |
| `HMT_GEMINI_OUTFILE` | Path to the Gemini telemetry file |
| `HMT_GEMINI_LIMIT` | Gemini limit, to exercise the percentage path |
| `HMT_DUMP` | Set to `1` to print state and exit |
| `HMT_ICON_PREVIEW` | Path for the icon comparison sheet |

## How it works

```
Sources/HowManyTokens/
  Model.swift            UsageWindow and ProviderUsage; five-hour blocks for Gemini
  UsageSource.swift      Source protocol, plus a cache that skips unchanged files
  ClaudeSource.swift     Reads the bridge file written by the status line script
  GeminiSource.swift     Reads the Gemini OTLP telemetry file
  JSONStream.swift       Splits concatenated pretty-printed JSON objects
  UsageCalculator.swift  Builds the menu bar string
  UsageStore.swift       Timer, background reads, published state
  Preferences.swift      UserDefaults-backed settings
  PanelView.swift        The dropdown panel and settings
  ProviderCard.swift     Provider card, window rows, staleness notice
  IconRenderer.swift     Menu bar icon drawing
  IconPreview.swift      Icon comparison sheet
  Formatting.swift       Token, duration, age and model formatting
  Diagnostics.swift      HMT_DUMP output
```

Files are parsed on a background queue, and a file whose size and modification
date are unchanged is not re-read.

The Gemini telemetry file is not one JSON object per line: it is a run of
pretty-printed objects appended back to back, so they are separated by tracking
brace depth. Because the OTLP record shape shifts between versions, the parser
walks the JSON tree collecting any object that carries token fields rather than
binding to a fixed schema.

## Limitations

- Claude figures do not refresh while Claude Code is closed.
- Gemini has no real quota figure; any percentage there reflects a limit you
  entered yourself.
- Gemini usage before telemetry was enabled is not recorded.
- Anthropic usage outside Claude Code is not reported separately.

## License

MIT — see [LICENSE](LICENSE).
