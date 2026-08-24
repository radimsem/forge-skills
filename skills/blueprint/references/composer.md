# Composer contract

The clipboard is the only return channel: the browser never talks to the
agent. Clicks assemble one human-readable prompt; the user pastes it into the
terminal; the paste is the user's authoritative answer, merged with any free
text they typed around it.

## The pasted response format (canonical)

    [blueprint:briefing-hero-options]
    1) Status card → A
    2) Detail layout → A — note: replace the em dash with something more human
    Nit on run-config.precision-row: align the precision value right like the other rows

- The header names the screen (`data-screen`). **A paste whose header names a
  different round than the current one is a stop-and-ask, never a guess.**
- Numbering follows on-screen question order; a question with no selection
  and no note is omitted from the body but still advances the number, so
  numbers always match what the user saw. A note without a selection renders
  the choice as `(no selection)`.
- Nit lines follow the questions, one per flagged `data-region`.
- The format is deliberately prose, not JSON: the user sees what they are
  sending, can edit it inline before sending, and terminal-fallback answers
  look identical — downstream workflow never branches on mode.

## Tray behavior

Fixed full-width bottom bar: live `N selections · M notes · K nits` count and
one **Copy response** button (`navigator.clipboard` with an `execCommand`
fallback; the button flashes "copied — paste it in the terminal"). On recap
screens the button becomes **Copy approval** and copies `data-approve-copy`.

## Agent-side parsing rules

1. Verify the `[blueprint:…]` header matches the round you last pushed.
2. Map numbered lines back to questions by order, not by label text.
3. Treat `Nit on <region>:` lines as change requests against that
   `data-region`; resolve them in the next screen version and record them in
   the ledger.
4. Anything in the message outside the pasted block is ordinary user text.

## Manual verification recipe

Run `sh tests/blueprint_test.sh` — the composer-core assertions check this
exact format against `assembleResponse`/`assembleInvocation`. Then perform
the browser recipe in [screens.md](screens.md) and diff the copied text
against the format above.
