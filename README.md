# herdr-wake
Durable wake-up queue and delivery worker for herdr agent panes.

Producers (herdr-gh-watch, herdr-hjob) call `wake enqueue` and stop there. One long-running
`wake worker` finds the agent pane for each event when it is idle, sends all its pending
events as one prompt, and marks them delivered only when `herdr agent prompt` exits 0.
The producer interface is [docs/enqueue-contract.md](docs/enqueue-contract.md).

Python 3 stdlib only. Linux.

## Install
1. Install the plugin in herdr (`thientrile/herdr-wake`), then run its action
   **herdr-wake: put the wake command on PATH**. It installs `~/.local/bin/wake` and writes
   `~/.config/systemd/user/herdr-wake.service` when that is missing or outdated.
2. Enable the worker once:
   `systemctl --user daemon-reload && systemctl --user enable --now herdr-wake.service`.

Plugin updates need no manual step. The unit runs `~/.local/bin/wake worker`; that shim finds the
current install from herdr's registry on disk (`~/.config/herdr/plugins.json`, else the newest
managed checkout), so it works while the herdr server is down. The running worker checks the
installed script between passes; when an update changes it, the worker exits and systemd
(`Restart=always`) starts the new version.

## Commands
| command | does |
|---|---|
| `wake enqueue ...` | store one event durably; exit 0 only once it is on disk (see the contract) |
| `wake worker` | the single delivery process; a second one exits while the first holds the lock |
| `wake status` | counts per state, overdue events, the last transitions |
| `wake install-unit` | write the systemd user unit if missing or outdated (does not enable it) |

## How delivery behaves
- State dir `${XDG_STATE_HOME:-~/.local/state}/herdr-wake/`: `pending/ -> delivering/ -> delivered/`,
  or `failed/`. Every write is temp file -> fsync -> rename -> fsync(dir).
- On start the worker moves every `delivering` event back to `pending`: a crash mid-prompt re-sends
  (at-least-once). Each prompt carries `wake-id <batch_id>`.
- A busy or blocked agent is never a failure: the event waits with backoff `min(30*2^n, 600)s`.
  After 1 h it is flagged `overdue` and the owner is notified once (herdr notification plus the
  optional `notify_cmd` in `~/.config/herdr/plugins/config/thientrile.wake/`, as in gh-watch).
- `failed` only when the target cwd is gone for 24 h, or after 20 herdr prompt errors.
- Target pane at delivery time: same cwd, else a pane under the cwd (deepest), else a worktree of the
  same repo (the event's branch first). `--pane-hint` only breaks ties.

## Tests
`python3 -m unittest discover -s tests` (uses a fake `herdr` on PATH; no herdr server needed).
