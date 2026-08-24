# Handoff

After the spec commits (Step 7), push a new recap screen in handoff mode.
Three routes, all clipboard-first.

## Route 1 — implementation plans

A `data-copy` button whose payload asks for plans from the spec, e.g.
"Using the writing-plans skill, create an implementation plan from
`docs/specs/<spec>.md`."

## Route 2 — spin off tickets

A `data-copy` button whose payload is prefixed with the `/to-tickets` skill
invocation, pointing at the committed spec: one issue per decided UI item,
preserving chosen-option detail and rejected alternatives; the tail is
pre-filled from the ledger (item count, tracker in use). This feeds
blacksmith's issue-sourced entry route.

## Route 3 — dispatch to blacksmith (invocation builder)

Builder markup (attributes are `composer.js`'s contract):

    <div data-invocation data-verb="/blacksmith-orchestrate"
         data-default-source="plan (docs/plans/<plan>.md)">
      <span data-source="plan (docs/plans/<plan>.md)" class="bp-selected">plan</span>
      <span data-source="#441 #442 #443">tickets</span>
      <div data-flag-group="orchestrator">
        <span data-flag="afk" data-on="true" class="bp-selected">afk</span>
        <span data-flag="unified" data-on="true" class="bp-selected">unified</span>
      </div>
      <div data-flag-group="passthrough">
        <span data-flag="lookup" data-on="true" class="bp-selected">lookup</span>
        <span data-flag="worktree" data-on="false">worktree</span>
      </div>
      <code data-cmd-preview></code>
    </div>

Assembly grammar: `<verb> <work-source> <orchestrator-flags> - <passthrough-flags>`
(the `-` separator is omitted when no pass-through flag is on).

**Flag metadata is generated, never hand-written.** At recap time, read the
CURRENT flag tables from blacksmith's and forge's `references/flags.md` and
emit one chip per flag. Pre-toggle the suggested set and print one line of
reasoning per suggestion under its group ("worktree — 4 independent items
collide on 0 files"). Which `data-source` segments are enabled follows which
of Routes 1–2 actually ran; both ran → user picks.

## Manual verification recipe

Author a recap screen with the builder above. Toggling `worktree` must update
the preview to append it after the `-`; selecting the tickets segment must
swap the work source; **Copy invocation** (`data-copy` on a button whose
payload the agent sets to the preview's initial value is NOT enough — the
preview is live, so read the copied text) must equal the preview exactly.
Cross-check every chip name against the current flag tables of both skills.
