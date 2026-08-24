# Screen authoring

Screens are HTML *content fragments* written to `<project>/.brainstorm/screens/`.
The companion wraps them in the frame (header, tray, harvested `style.css`,
`composer.js`) automatically; a file starting with `<!DOCTYPE` or `<html` is
served as-is for full-control pages. Never write screens with heredocs — use
the file-creation tool.

## Fragment contract

Every interactive element is declared with data attributes; `composer.js` does
the rest. Attribute names are load-bearing — they must match this contract
exactly.

    <div data-screen="briefing-hero-options">
      <section data-question="status-card" data-label="Status card">
        <div data-choice="a">…option card A…</div>
        <div data-choice="b">…option card B…</div>
      </section>
      <div class="mockup">
        <div data-region="run-config.precision-row">…mockup part…</div>
      </div>
    </div>

- `data-screen` — round id; it becomes the `[blueprint:…]` header of the
  pasted response, so name it after the screen file (sans `.html`).
- `data-question` + `data-label` — one per question; the label is what the
  pasted response calls it.
- `data-choice` — lowercase letter per option card; click selects, re-click
  another card moves the selection.
- `data-region` — stable id on any mockup part worth a nit; alt-click flags
  it and asks for a note. Include one hint line per screen teaching the
  gesture ("⌥/Alt-click any part of a mockup to flag a nit").
- Recap screens set `data-mode="recap"` and `data-approve-copy` on the root;
  see [handoff.md](handoff.md) for the builder markup.

## Discipline

- **Never reuse filenames.** Revisions get `-v2`, `-v3` suffixes; the server
  serves the newest file by mtime.
- **One screen = one round.** 2–4 options per question; explain the question
  on the page, not only in the terminal.
- **Unload when returning to the terminal.** Push a fresh `waiting-N.html`
  ("Continuing in terminal…") so the user is not staring at a resolved
  choice.
- Every fragment styles itself from the harvested tokens (the frame imports
  `/style.css`); a screen that only works with generic styling is a red flag
  per [anti-patterns.md](anti-patterns.md).

## Terminal fallback

With the `terminal` flag, no display, or a server that fails to bind twice:
the workflow does not branch. Options become terminal multiple-choice
questions (the host's question UI where available, numbered lists otherwise);
mockups become ledger-grade prose plus small ASCII sketches where genuinely
helpful. Answers arrive in the same format as pasted responses, so
downstream steps never care which mode ran.

## Manual verification recipe

Start the companion on a scratch dir, write the fragment above as
`demo.html`, and open the URL. Clicking option A outlines it and the tray
reads "1 selections"; alt-clicking the region prompts for a note and the tray
counts 1 nit; **Copy response** produces exactly the format in
[composer.md](composer.md). Write `demo-v2.html` with changed text: the open
tab reloads to it without a refresh.
