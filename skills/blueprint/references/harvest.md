# Design harvest

The harvest turns the target project's real design language into two cached
artifacts every screen builds on. **No screen may be pushed before the harvest
exists.** This is what separates a blueprint mockup from a generic-framework
mockup: the CSS the user sees is the project's own.

## Source priority

1. **Design docs** — `DESIGN.md`, `docs/DESIGN.md`, `docs/design/**` and
   similar (glob case-insensitively). These carry the *rules*.
2. **Token sources in code** — tailwind config, CSS custom properties, theme
   files, font imports, and the icon library the project actually imports.
3. **2–3 representative components from the surface being brainstormed** —
   real components beat prose for idioms: card chrome, spacing rhythm, empty
   states. Redesigning a page means reading that page's components.

## Cached artifacts (in the target project)

- `.brainstorm/style.css` — real CSS variables, font stacks, radii, shadows,
  spacing scale, plus mockup utility classes named after the project's own
  idioms. Served by the companion at `/style.css`; every frame imports it.
- `.brainstorm/design-notes.md` — prose rules CSS cannot carry ("status text
  never uses em dashes"), each with a source pointer back to the file it came
  from.

## Freshness

Later sessions re-check only the pointed-at sources (mtime or a short diff)
and refresh what changed. The `fresh` flag rebuilds from scratch. Suggest
gitignoring `.brainstorm/screens/`, ledgers, `server-info`, and `port`, while
**committing** `style.css` and `design-notes.md` — they are shared team
assets; screens and ledgers are session ephemera superseded by the spec.

## Manual verification recipe

In any project with a design doc: run the harvest, then open
`.brainstorm/style.css` and confirm every color/font value also appears in the
project's own token sources (grep a sampled hex value). Open
`design-notes.md` and follow one source pointer to the file it names; the rule
must be visible there. Then delete one pointer target's mtime cache
expectation by touching the file and re-run without `fresh`: only that source
is re-read.
