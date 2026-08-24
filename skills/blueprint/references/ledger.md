# Decision ledger

`.brainstorm/<YYYY-MM-DD>-<topic>.md` in the target project. Append-only
during rounds; it is the session's single source of truth and the input to
both the recap screen and the spec.

## Per-round block

    ## Round: briefing-hero-options  (screen: briefing-hero-options.html)
    - Q: Status card — options: A progress bar / B step dots / C ring gauge
      - **Chosen: A — progress bar.** Full option description copied here.
      - Note: replace the em dash in the status text.
    - Nit on run-config.precision-row: align right — resolved in …-v2.html

## Consumers

- **Recap screen (Step 6 gate)** renders directly from the ledger, so what
  the user approves is provably what was recorded.
- **Spec (Step 7)** is assembled from it: chosen-option blocks reorganized
  per UI item, plus a "Rejected alternatives" appendix (one line each) so
  implementing forge runs do not reintroduce rejected variants.
- **`resume` flag**: the ledger IS the session state. Resume = read ledger,
  restart the server (same `--project-dir`, same persisted port), re-push the
  last unresolved screen.

The ledger is session ephemera: gitignored, superseded by the committed spec.

## Manual verification recipe

Mid-session, kill the server and the agent process. Re-invoke with `resume`:
the agent must restate every recorded decision from the ledger without
re-asking, the tab must reconnect on the same port, and the next screen must
be the last unresolved one — not round one.
