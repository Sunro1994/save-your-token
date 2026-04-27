[한국어](README.ko.md)

# save-your-token

When using Claude Code, token consumption can spike quickly and hit the limit before you know it.
This project implements token-saving features to help you avoid that problem.

---

## How it works

`/token-diet` provides two core features.

**First, it analyzes your history.**

It parses the session files Claude Code stores locally and shows you exactly which command types consumed how many tokens — by looking directly at the internal files.

```
Average tokens per command: 36,700 tok

Token usage by category
  Code generation   8 cmds   52,400 tok   avg 6,550/cmd   41% 🔴
  Refactoring       4 cmds   31,800 tok   avg 7,950/cmd   25% 🟡
  Questions         5 cmds   14,200 tok   avg 2,840/cmd   11% 🟢

Top 3 token-heavy commands
  1. [Code gen]  Rewrite this entire feature from scratch  → 18,400 tok
  2. [Refactor]  Refactor the whole file                  → 15,200 tok
  3. [Code gen]  Build the API integration                → 12,600 tok
```

**Second, it diagnoses your environment and guides improvements.**

It automatically scans your CLAUDE.md size, MCP server count, `.claudeignore` status, ReadOnce hook, and rules setup.
It walks you through issues interactively — explaining why each one matters and how to fix it.
Nothing is applied until you confirm.

---

## Install

```bash
git clone https://github.com/Sunro1994/save-your-token.git
cd save-your-token

# Register the command
mkdir -p ~/.claude/commands
cp commands/token-diet.md ~/.claude/commands/token-diet.md
```

**ReadOnce hook (optional, recommended)**

Automatically blocks repeated reads of the same file.

```bash
mkdir -p ~/.claude/hooks
cp hooks/readonce-hook.sh ~/.claude/hooks/readonce-hook.sh
chmod +x ~/.claude/hooks/readonce-hook.sh
```

Add the following to `~/.claude/settings.json`.
If the file already exists, merge only the `hooks` key.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/readonce-hook.sh"
          }
        ]
      }
    ]
  }
}
```

---

## Run

In any Claude Code session:

```
/token-diet
```

---

## Step-by-step guide

After the analysis, you can work through 4 steps in order or jump to any specific one.
Each step explains the reason first. You decide what to apply.

| Step | What |
|------|------|
| 1 | Learn when to use `/compact` and `/clear` |
| 2 | Clean up MCPs, add `.claudeignore` |
| 3 | Split `rules/`, tune Extended Thinking |
| 4 | Improve memory structure, install ReadOnce hook |

---

## Included

### `.claudeignore` templates

Claude Code tries to read images, build artifacts, and config files during every project scan.
A `.claudeignore` in your project root limits what it touches.

```bash
cp examples/claudeignore-nextjs   ./my-nextjs-project/.claudeignore
cp examples/claudeignore-python   ./my-python-project/.claudeignore
cp examples/claudeignore-obsidian ./my-vault/.claudeignore
```

### ReadOnce hook

Every time Claude Code re-reads the same file, the full content is loaded into the context again.
This hook blocks duplicate reads of the same file within 5 minutes.
Supports macOS · Linux · Windows.

### prompt-lint hook

Detects token-wasteful patterns in your messages before they are sent to Claude and suggests a more targeted rewrite. The request is never blocked — it only shows a warning.

Patterns detected: whole-file requests, full rewrites from scratch, full refactors, fix-all-errors, vague large-scope requests, entire codebase references.

### context-watch hook

Automatically checks context usage after every Claude response.
No need to run `/context` manually — it alerts you when thresholds are crossed.

- 🟡 60%+: recommends `/compact`
- 🔴 80%+: warns to run `/clear` or `/compact`

### report-save hook

Automatically saves a daily token usage snapshot after each Claude response.
Stored at `~/.claude/token-diet-reports/YYYY-MM-DD.json`.
When you run `/token-diet`, this data is used to display a 7-day trend comparison.
Only saves once per day — if today's file already exists, it is skipped.

Full setup for all hooks: [`hooks/SETUP.md`](hooks/SETUP.md)

---

## How it's built

- `/token-diet` command: Parses JSONL session files under `~/.claude/projects/` to aggregate real token usage per command.
- ReadOnce hook: Intercepts Claude Code's `PreToolUse` event to block duplicate reads. Uses SHA-256 hashing for file path tracking. No dependencies beyond python3.
- prompt-lint hook: Intercepts each `UserPromptSubmit` event, matches the prompt against wasteful patterns, and prints rewrite suggestions to stderr. Writes Python to a temp file to avoid heredoc stdin conflicts.
- context-watch hook: Reads the latest session JSONL on each `Stop` event and calculates context usage against the 200k token limit.
- report-save hook: Runs on each `Stop` event, writes a JSON snapshot once per day, and skips silently if today's report already exists.
- Everything runs locally. No external servers or APIs.

---

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v1.0.0+
- python3 (included by default on macOS and Linux)

---

## Contributing

Issues and PRs are welcome. For significant changes, open an issue first to discuss.

## Credits

This project was inspired by [jjoa68/claude-token-diet](https://github.com/jjoa68/claude-token-diet).
The core idea of the ReadOnce hook, the step-by-step environment diagnosis flow, and the `.claudeignore` template concept all originate from that work.
The original is released under the MIT license.

What's new in this version:
- Token usage analysis by parsing actual session JSONL files
- Per-category command breakdown and TOP 5 report
- 7-day trend comparison using daily saved reports
- ReadOnce hook rewritten with SHA-256 hashing and stdin parsing fix
- prompt-lint hook for pre-send token waste detection
- context-watch hook for automatic context threshold alerts
- report-save hook for daily token usage snapshots
- Korean-only interface

## License

[MIT](LICENSE)
