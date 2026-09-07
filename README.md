# Session Restore for Omarchy

> **Fork.** Patched copy of [wbarakat/omarchy-session-restore](https://github.com/wbarakat/omarchy-session-restore)
> with three fixes and a menu installer — see [Fork changes](#fork-changes).

Save your open windows before a reboot, get them back on your workspaces after
the next boot — including terminal working directories and, if you use herdr,
your resumed AI agent sessions.

Built for the dual-boot workflow: reboot into another OS, boot back into
Omarchy, and pick up where you left off.

## What it does

- **Save** captures every open window: its launch command (rebuilt from
  `/proc/<pid>/cmdline`), workspace, floating state, and — for terminals —
  the shell's working directory.
- **Restore** runs automatically when the Omarchy shell starts after login
  and relaunches each window silently onto its saved workspace, without
  stealing focus. Terminals start back in their saved directories.
- **Agent resume** (optional): if a herdr server was running at save time, the
  restore waits for herdr to come back and restarts `claude --continue` in the
  matching pane, so your Claude Code conversation resumes by itself.
- The saved manifest is locked and consumed after one restore, so a boot (or
  a shell restart) never double-launches anything.

## Install

```bash
omarchy plugin add https://github.com/wbarakat/omarchy-session-restore.git --enable
```

The plugin's `service` entry point runs the restore at shell startup. Saving
is manual (see Usage) until you add the optional menu integration below.

**Menu integration (recommended):** merge
`extensions/omarchy-menu-snippet.jsonc` into
`~/.config/omarchy/extensions/omarchy-menu.jsonc` and run
`omarchy menu refresh`. This adds a "Save Session" row to the System menu and
makes Reboot and Shutdown save the session automatically first. This step
edits your menu config, so it is deliberately manual — the plugin never
changes your configuration by itself.

<details>
<summary>Manual install without the plugin system</summary>

```bash
git clone https://github.com/wbarakat/omarchy-session-restore.git
cd omarchy-session-restore
./install.sh
```

This copies the scripts to `~/.local/bin` and installs a `post-boot` hook
instead of the shell service. In the menu snippet, replace the plugin paths
with `~/.local/bin/...`. Use either the plugin or the manual install, not
both.

</details>

## Usage

```bash
~/.config/omarchy/plugins/io.github.wbarakat.session-restore/bin/omarchy-session-save
# preview what a restore would launch:
~/.config/omarchy/plugins/io.github.wbarakat.session-restore/bin/omarchy-session-restore --dry-run
```

With the menu integration installed, saving is automatic: reboot or shut down
from the Omarchy menu and the session is snapshotted first. On the next boot
into Omarchy everything relaunches within a few seconds of login.

State lives in `~/.local/state/omarchy/`:

- `session.json` — the window manifest (renamed to `.restored` after use)
- `herdr-agents.json` — agent panes to resume (also consumed after use)
- `session.lock` — guards against concurrent restores
- `session-restore.log` — timestamped save, window launch, and agent resume results

## Removal

```bash
omarchy plugin remove io.github.wbarakat.session-restore
```

Then remove the menu entries you added to
`~/.config/omarchy/extensions/omarchy-menu.jsonc` (if any) and, optionally,
the state files: `rm -f ~/.local/state/omarchy/session.json* ~/.local/state/omarchy/herdr-agents.json* ~/.local/state/omarchy/session.lock ~/.local/state/omarchy/session-restore.log`

For a manual install, additionally delete the three `omarchy-session-*`
scripts from `~/.local/bin` and
`~/.config/omarchy/hooks/post-boot.d/10-session-restore`.

## Requirements and dependencies

- Omarchy (Quattro) with Hyprland **0.56+** — the restore dispatches through
  the Lua API: `hl.dispatch(hl.dsp.exec_cmd(...))`
- `jq` and `flock` (both ship with Omarchy / util-linux)
- Optional: herdr for agent resume; `notify-send` for save feedback

No sudo, no network access, no external downloads. The plugin only reads
`hyprctl` output and `/proc`, and writes state under `~/.local/state/omarchy/`.

## Limitations

This is best-effort relaunch, not process freezing — only hibernation can
preserve actual application state across a reboot:

- Apps reopen fresh. Browsers and editors restore their own sessions if they
  are configured to; unsaved work is gone.
- Windows sharing one process (e.g. several Chromium windows or web apps)
  collapse to a single relaunch entry.
- Scratchpad/special workspaces are skipped.
- Only `claude` agents get a resume flag in herdr; other agent kinds start
  fresh.
- Saves triggered outside the menu (plain `systemctl reboot`) require running
  `omarchy-session-save` manually first.

## Setting it up on another machine

```bash
omarchy plugin add https://github.com/dougfour/omarchy-session-restore.git --enable
~/.config/omarchy/plugins/io.github.wbarakat.session-restore/bin/install-menu
```

The first command installs and enables the plugin, which restores at login.
The second adds the Save Session / Reboot / Shutdown rows to the Omarchy menu,
so a power action snapshots the session first — without it nothing is ever
saved and the plugin sits idle. It writes one marked block and refreshes the
menu; re-running it is a no-op, and `bin/remove-menu` takes only that block
back out.

Update everywhere later with `omarchy plugin update io.github.wbarakat.session-restore`.

## Fork changes

- **Never replay a manifest inside the boot that saved it.** The service runs
  the restore at every shell start, but the manifest is only consumed after a
  fully successful run, so a manual save followed by any shell restart
  relaunched every saved window as a duplicate. The save now stamps the boot
  id beside the manifest and the restore skips a matching one. Manifests
  without a stamp restore as before.
- **Detect launch failures.** `hyprctl` exits 0 even when the Lua it was
  handed fails — the only signal is the `error:` line it prints, which was
  being discarded — so every entry was logged as launched whether or not it
  was, and the `exit 1` branch was unreachable. The output is now read, the
  real reason logged, and the remaining windows still restored.
- **Skip `steam`.** Its window belongs to the `steamwebhelper` subprocess, so
  `/proc` yields a relative `./steamwebhelper` path plus a `-steampid` from
  the boot that is ending. Nothing usable to relaunch.
- **`bin/install-menu` / `bin/remove-menu`.** The upstream menu snippet is a
  manual copy-paste; these do it idempotently and reversibly.

Known limits, unchanged from upstream: placement is per workspace, not per
position or size, and windows sharing one process (several Chrome windows, or
several windows of a single-instance terminal) restore as one.

## License

MIT
