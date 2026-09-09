# Reboot and Reopen

Your windows come back on their workspaces after a reboot — Chrome included.

Reboot or shut down from the Omarchy menu and the session is snapshotted
first. On the next login the windows relaunch silently onto the workspaces
they were on, terminals reopen in their old directories, and herdr agents
carry on where they left off.

## Install

```bash
omarchy plugin add https://github.com/dougfour/omarchy-reboot-and-reopen.git --enable
~/.config/omarchy/plugins/io.github.dougfour.reopen/bin/install-menu
```

Both commands matter. The first installs the plugin, which does the
restoring. The second adds the **Save Session**, **Reboot** and **Shutdown**
rows to the Omarchy menu, which is what does the saving — without it the
plugin sits idle and nothing is ever captured.

`install-menu` writes one marked block into
`~/.config/omarchy/extensions/omarchy-menu.jsonc` and refreshes the menu.
Re-running it is a no-op. `bin/remove-menu` takes that block back out and
leaves any rows you added yourself alone.

## Using it

Reboot or shut down with **SUPER + ESCAPE** → Reboot. That is the whole
workflow. The power actions snapshot the session first, joined with `;` so a
failed save can never block the reboot.

There is a **Save Session** row for taking a snapshot by hand. Saving without
rebooting is safe: a manifest is stamped with the boot that wrote it and is
never replayed inside that same boot, so a shell restart cannot relaunch
windows that are still open.

To see what a restore would do without running one:

```bash
~/.config/omarchy/plugins/io.github.dougfour.reopen/bin/reopen-restore --dry-run
```

State lives in `~/.local/state/omarchy/`:

- `session.json` — the window manifest, renamed to `.restored` once used
- `session.boot` — the boot id that manifest belongs to
- `herdr-agents.json` — agents to resume, also consumed after use
- `session-restore.log` — timestamped saves, launches and failures

## What it captures

Per window: the launch command rebuilt from `/proc/<pid>/cmdline`, the
workspace, floating state, and for terminals the shell's working directory.
Steam is skipped — its window belongs to the `steamwebhelper` subprocess, so
`/proc` yields a relative path and a PID from the boot that is ending.

herdr gets special handling. It runs as a TUI with no window of its own, so
it is restored through `omarchy-launch-terminal-herdr`, the same thing
**SUPER CTRL + RETURN** does. herdr then restores its own panes and agents,
and this plugin waits for that to settle and only starts an agent herdr did
not bring back itself.

## Limits

Two of them are structural, not bugs:

- **Workspace, not geometry.** Windows return to the right workspace. Their
  position and size are not restored — Hyprland does not expose or accept its
  layout tree, so no tool can put a tiled arrangement back exactly.
- **One window per process.** Windows that share a process collapse to one
  entry, because `/proc` gives one command line for all of them. Several
  Chrome windows, or several windows of a single-instance terminal, come back
  as one. Chrome reopens the rest itself if you have "Continue where you left
  off" enabled.

Launch failures that happen after Hyprland forks are invisible to `hyprctl`,
so if something does not come back, the journal has the real reason:

```bash
journalctl --user --since "-10 min" | grep uwsm_app-daemon
```

## Credit

Built on [wbarakat/omarchy-session-restore](https://github.com/wbarakat/omarchy-session-restore),
whose architecture this keeps — the `/proc` capture, the Lua long-bracket
escaping, the manifest lock, the herdr pane matching. The full history of
that original is preserved in this repository's git log.

Changes since the fork:

- **Chrome and other Chromium apps launch at all.** Chrome rewrites its own
  argv, so `/proc` reports the whole command line as a single element.
  Quoting that blob made one impossible argument and every restore failed
  with `Path "..." does not exist!` while still logging success.
- **A manifest is never replayed in the boot that saved it.** The restore
  runs at every shell start, so a manual save followed by a shell restart
  relaunched every saved window on top of the ones still open.
- **Launch failures are detected.** `hyprctl eval` exits 0 even when its Lua
  fails, so failures were logged as successes and one bad entry could stop
  the rest of the session from restoring.
- **herdr comes back.** It has no window of its own, so nothing represented
  it, its server never started, and the agent resume timed out every boot.
- **Agents are no longer duplicated.** herdr restores its own agents with
  their sessions intact; racing it started fresh, sessionless duplicates on
  top of good ones.
- **`install-menu` / `remove-menu`**, so the menu step survives being set up
  on a second machine.

## License

MIT
