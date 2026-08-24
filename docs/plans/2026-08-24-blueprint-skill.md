# Blueprint Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `skills/blueprint/` — a visual/interactive brainstorming skill whose browser screens copy composed prompts to the user's clipboard — plus its shipped machinery (`serve.mjs`, `frame.html`, `composer.js`), test suite, and docs integration.

**Architecture:** Deterministic machinery ships as versioned code under `scripts/` (a GET-only SSE live-reload server, a frame shell, a composer engine whose pure core is Node-testable); judgment ships as prose (`SKILL.md` + `references/`), following the forge/blacksmith progressive-disclosure pattern. The browser never talks back to the agent — clicks assemble a human-readable prompt the user pastes into the terminal.

**Tech Stack:** POSIX `sh` (tests), Node stdlib only (`node:http`, `node:fs`) — no npm, no dependencies, no build step. Prose is the behavior contract.

**Spec:** `docs/specs/2026-08-24-blueprint-skill-design.md` — read it before starting; every task below implements a numbered section of it.

## Global Constraints

- No package manager, no dependencies: `serve.mjs` uses Node stdlib only; `composer.js` is a plain classic script (no modules — Node tests `require()` it and read `globalThis.blueprintComposer`).
- All shell is POSIX `sh` — no bashisms (repo convention; scripts are written to pass shellcheck).
- `tests/docs_test.sh` invariants apply to every new `.md` under `skills/`: frontmatter with `name`+`description` in `SKILL.md`, all relative links resolve at commit time, no `TBD`/`TODO`/`FIXME` anywhere in shipped prose.
- The `flag_names` helper in `docs_test.sh` extracts the first column of EVERY table under a heading: any section compared for flag parity (`## Flags` in `references/flags.md`, the flag table in `SKILL.md` `## Parameters`, `## Blueprint flags` in `README.md`) must contain exactly ONE table; non-flag content under those headings goes in prose.
- Every `references/*.md` except `flags.md` and `anti-patterns.md` carries a `Manual verification recipe` section (checked mechanically in Task 6).
- The renamed tracker skill is `/to-tickets` (not `/to-issues`) — use that name everywhere. Forge's own routing references are out of scope.
- Never touch `install.sh`, `deps_table`, or `tests/install_test.sh` — blueprint has no install-time dependencies.
- Commit after every task on the existing branch `feat/blueprint-skill`. Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Hard behavioral floor (mirror it in prose, never weaken): nothing touches the target codebase before the Step 6 approval gate.

---

### Task 1: `serve.mjs` + `frame.html` + server smoke tests

**Files:**
- Create: `skills/blueprint/scripts/serve.mjs`
- Create: `skills/blueprint/scripts/frame.html`
- Test: `tests/blueprint_test.sh`

**Interfaces:**
- Consumes: nothing (first task).
- Produces (later tasks and the running agent rely on these exactly):
  - CLI: `node skills/blueprint/scripts/serve.mjs --project-dir <dir> [--port N] [--open] [--idle-timeout-minutes N]` (idle default `0` = never exit).
  - Disk contract under `<project>/.brainstorm/`: `screens/` (watched fragment dir, created on start), `server-info` (JSON `{port,pid,url}`, present only while running), `port` (persisted stable port), `style.css` (served if present, empty CSS otherwise).
  - HTTP: `GET /` newest screen wrapped in frame; `GET /style.css`; `GET /composer.js`; `GET /events` (SSE, emits `data: reload` on screen changes); everything else 404; non-GET 405.
  - Frame markers: body `id="blueprint-frame"`, content placeholder `<!--BLUEPRINT:CONTENT-->`, tray ids `#bp-tray` `#bp-count` `#bp-copy`, header ids `#bp-dot` `#bp-screen-name`, content wrapper `#bp-content`. CSS hooks: `.bp-selected`, `.bp-nit`.
  - Fragments starting `<!DOCTYPE`/`<html` (case-insensitive) are served unwrapped.

- [ ] **Step 1: Write the failing test suite**

Create `tests/blueprint_test.sh` (mode 755):

```sh
#!/bin/sh
# Smoke tests for blueprint's shipped machinery: serve.mjs (Task 1) and the
# composer core (Task 2). Node-only; no dependencies.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BP="$ROOT/skills/blueprint"
PASSES=0; FAILS=0
SERVER_PID=""
TMP=$(mktemp -d)
trap 'kill "$SERVER_PID" 2>/dev/null; rm -rf "$TMP"' EXIT INT TERM

assert_contains() { # haystack needle label
  case "$1" in
    *"$2"*) PASSES=$((PASSES+1)); echo "PASS: $3" ;;
    *) FAILS=$((FAILS+1)); echo "FAIL: $3" ;;
  esac
}
assert_not_contains() {
  case "$1" in
    *"$2"*) FAILS=$((FAILS+1)); echo "FAIL: $3" ;;
    *) PASSES=$((PASSES+1)); echo "PASS: $3" ;;
  esac
}
assert_eq() {
  if [ "$1" = "$2" ]; then PASSES=$((PASSES+1)); echo "PASS: $3"
  else FAILS=$((FAILS+1)); echo "FAIL: $3"; printf 'got:\n%s\nwant:\n%s\n' "$1" "$2"; fi
}

# --- serve.mjs: serves newest fragment, wrapped in the frame ---
mkdir -p "$TMP/.brainstorm/screens"
printf '<p>hello-fragment</p>' > "$TMP/.brainstorm/screens/first.html"
node "$BP/scripts/serve.mjs" --project-dir "$TMP" >/dev/null 2>&1 &
SERVER_PID=$!
i=0
while [ ! -f "$TMP/.brainstorm/server-info" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i+1)); done
[ -f "$TMP/.brainstorm/server-info" ] || { echo "FAIL: server-info never appeared"; exit 1; }
PORT=$(sed 's/.*"port":\([0-9]*\).*/\1/' "$TMP/.brainstorm/server-info")

BODY=$(curl -sf "http://127.0.0.1:$PORT/")
assert_contains "$BODY" 'hello-fragment' "serves the fragment"
assert_contains "$BODY" 'blueprint-frame' "fragment is wrapped in the frame"

sleep 1.1  # ensure a newer mtime on coarse filesystems
printf '<p>second-fragment</p>' > "$TMP/.brainstorm/screens/second.html"
BODY2=$(curl -sf "http://127.0.0.1:$PORT/")
assert_contains "$BODY2" 'second-fragment' "serves the newest screen"

sleep 1.1
printf '<!DOCTYPE html><html><body>raw-doc</body></html>' > "$TMP/.brainstorm/screens/third.html"
BODY3=$(curl -sf "http://127.0.0.1:$PORT/")
assert_contains "$BODY3" 'raw-doc' "full documents are served"
assert_not_contains "$BODY3" 'blueprint-frame' "full documents bypass the frame"

CSS_STATUS=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/style.css")
assert_eq "$CSS_STATUS" "200" "style.css route answers even with no harvest yet"

kill "$SERVER_PID"; wait "$SERVER_PID" 2>/dev/null; SERVER_PID=""
sleep 0.3
if [ -f "$TMP/.brainstorm/server-info" ]; then
  FAILS=$((FAILS+1)); echo "FAIL: server-info removed on shutdown"
else
  PASSES=$((PASSES+1)); echo "PASS: server-info removed on shutdown"
fi

echo "PASSES=$PASSES FAILS=$FAILS"
[ "$FAILS" -eq 0 ]
```

- [ ] **Step 2: Run it to verify it fails**

Run: `sh tests/blueprint_test.sh`
Expected: FAIL — `node` errors with "Cannot find module .../serve.mjs" (surfaced as the server-info exit at line "server-info never appeared").

- [ ] **Step 3: Implement `frame.html`**

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>blueprint</title>
<link rel="stylesheet" href="/style.css">
<style>
  body { margin: 0; font-family: system-ui, sans-serif; }
  #bp-frame-head { display: flex; align-items: center; gap: 8px; padding: 10px 16px;
    border-bottom: 1px solid rgba(128,128,128,.3); font-weight: 600; }
  #bp-dot { width: 9px; height: 9px; border-radius: 50%; background: #c33; }
  #bp-dot.live { background: #3fb96f; }
  #bp-screen-name { opacity: .6; font-weight: 400; }
  #bp-content { padding: 16px 16px 84px; max-width: 1100px; margin: 0 auto; }
  #bp-tray { position: fixed; left: 0; right: 0; bottom: 0; display: flex;
    justify-content: space-between; align-items: center; padding: 10px 16px;
    border-top: 1px solid rgba(128,128,128,.3);
    background: var(--bp-tray-bg, #eef1fb); }
  #bp-copy { background: var(--bp-accent, #5b7cfa); color: #fff; border: 0;
    border-radius: 6px; padding: 8px 16px; font-weight: 600; cursor: pointer; }
  .bp-selected { outline: 2px solid var(--bp-accent, #5b7cfa); outline-offset: -2px; }
  [data-region]:hover { outline: 1px dashed rgba(128,128,128,.6); }
  .bp-nit { outline: 2px dashed var(--bp-nit, #e0863a) !important; }
  .bp-note-btn { border: 1px solid rgba(128,128,128,.4); background: none;
    border-radius: 4px; margin-left: 6px; cursor: pointer; }
  .bp-note-input { display: block; width: 100%; margin-top: 6px; padding: 4px 8px;
    border: 1px solid var(--bp-accent, #5b7cfa); border-radius: 6px; }
</style>
</head>
<body id="blueprint-frame">
  <div id="bp-frame-head"><span id="bp-dot"></span><span>blueprint</span><span id="bp-screen-name"></span></div>
  <div id="bp-content">
<!--BLUEPRINT:CONTENT-->
  </div>
  <div id="bp-tray"><span id="bp-count">0 selections · 0 notes · 0 nits</span><button id="bp-copy">Copy response</button></div>
  <script>
    (function () {
      var dot = document.getElementById('bp-dot');
      function connect() {
        var es = new EventSource('/events');
        es.onopen = function () { dot.classList.add('live'); };
        es.onmessage = function () { location.reload(); };
        es.onerror = function () { dot.classList.remove('live'); es.close(); setTimeout(connect, 1500); };
      }
      connect();
    })();
  </script>
  <script src="/composer.js"></script>
</body>
</html>
```

- [ ] **Step 4: Implement `serve.mjs`**

```js
#!/usr/bin/env node
// blueprint companion server. Serves the newest screen fragment from
// <project>/.brainstorm/screens/ wrapped in frame.html, pushes reloads over
// SSE, and ingests nothing: GET-only, no state beyond "which file is newest".
// Disk contract: server-info (present only while running), port (persisted so
// restarts reuse the same port and the user's open tab reconnects).
import { createServer } from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 || i === process.argv.length - 1 ? fallback : process.argv[i + 1];
}

const projectDir = arg('project-dir', null);
if (!projectDir) {
  console.error('usage: serve.mjs --project-dir <dir> [--port N] [--open] [--idle-timeout-minutes N]');
  process.exit(2);
}
const brainDir = path.join(projectDir, '.brainstorm');
const screensDir = path.join(brainDir, 'screens');
fs.mkdirSync(screensDir, { recursive: true });
const portFile = path.join(brainDir, 'port');
const infoFile = path.join(brainDir, 'server-info');
const idleMinutes = Number(arg('idle-timeout-minutes', '0')) || 0; // 0 = never exit

const frame = fs.readFileSync(path.join(SCRIPT_DIR, 'frame.html'), 'utf8');
const composerPath = path.join(SCRIPT_DIR, 'composer.js');

function newestScreen() {
  const files = fs.readdirSync(screensDir).filter((f) => f.endsWith('.html'));
  if (!files.length) return null;
  files.sort(
    (a, b) =>
      fs.statSync(path.join(screensDir, b)).mtimeMs - fs.statSync(path.join(screensDir, a)).mtimeMs,
  );
  return fs.readFileSync(path.join(screensDir, files[0]), 'utf8');
}

function page() {
  const fragment = newestScreen();
  if (fragment === null) {
    return frame.replace('<!--BLUEPRINT:CONTENT-->', '<p>No screens yet — waiting for the first round…</p>');
  }
  const head = fragment.trimStart().slice(0, 9).toLowerCase();
  if (head.startsWith('<!doctype') || head.startsWith('<html')) return fragment;
  return frame.replace('<!--BLUEPRINT:CONTENT-->', fragment);
}

const clients = new Set();
let lastActivity = Date.now();

const server = createServer((req, res) => {
  lastActivity = Date.now();
  if (req.method !== 'GET') { res.writeHead(405); res.end(); return; }
  const url = req.url.split('?')[0];
  if (url === '/') {
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    res.end(page());
  } else if (url === '/style.css') {
    const p = path.join(brainDir, 'style.css');
    res.writeHead(200, { 'content-type': 'text/css' });
    res.end(fs.existsSync(p) ? fs.readFileSync(p) : '');
  } else if (url === '/composer.js') {
    res.writeHead(200, { 'content-type': 'text/javascript' });
    res.end(fs.existsSync(composerPath) ? fs.readFileSync(composerPath) : '');
  } else if (url === '/events') {
    res.writeHead(200, {
      'content-type': 'text/event-stream',
      'cache-control': 'no-cache',
      connection: 'keep-alive',
    });
    res.write('\n');
    clients.add(res);
    req.on('close', () => clients.delete(res));
  } else {
    res.writeHead(404); res.end();
  }
});

let reloadTimer = null;
fs.watch(screensDir, () => {
  clearTimeout(reloadTimer);
  reloadTimer = setTimeout(() => {
    for (const c of clients) c.write('data: reload\n\n');
  }, 100);
});

const savedPort = fs.existsSync(portFile) ? Number(fs.readFileSync(portFile, 'utf8').trim()) : 0;
const wantPort = Number(arg('port', String(savedPort))) || 0;
server.on('error', (e) => {
  // A stale persisted port may be taken by another process: fall back to any
  // free port rather than dying. Explicit --port conflicts still surface.
  if (e.code === 'EADDRINUSE' && !process.argv.includes('--port')) server.listen(0, '127.0.0.1');
  else throw e;
});
server.listen(wantPort, '127.0.0.1', () => {
  const port = server.address().port;
  fs.writeFileSync(portFile, String(port));
  const url = `http://localhost:${port}/`;
  fs.writeFileSync(infoFile, JSON.stringify({ port, pid: process.pid, url }));
  console.log(JSON.stringify({ type: 'server-started', url, screens: screensDir }));
  if (process.argv.includes('--open')) {
    spawn(process.platform === 'darwin' ? 'open' : 'xdg-open', [url], {
      stdio: 'ignore',
      detached: true,
    }).unref();
  }
});

function shutdown() {
  try { fs.unlinkSync(infoFile); } catch { /* already gone */ }
  process.exit(0);
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
if (idleMinutes > 0) {
  setInterval(() => {
    if (Date.now() - lastActivity > idleMinutes * 60000) shutdown();
  }, 30000).unref();
}
```

- [ ] **Step 5: Run the tests and make sure they pass**

Run: `sh tests/blueprint_test.sh`
Expected: `PASSES=7 FAILS=0`, exit 0. Also run `node --check skills/blueprint/scripts/serve.mjs` — no output.

- [ ] **Step 6: Commit**

```bash
git add skills/blueprint/scripts/serve.mjs skills/blueprint/scripts/frame.html tests/blueprint_test.sh
git commit -m "feat(blueprint): live-reload companion server with frame shell

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: `composer.js` — pure core + DOM wiring

**Files:**
- Create: `skills/blueprint/scripts/composer.js`
- Modify: `tests/blueprint_test.sh` (append composer-core section before the final summary lines)

**Interfaces:**
- Consumes: frame ids/classes from Task 1 (`#bp-content`, `#bp-count`, `#bp-copy`, `#bp-screen-name`, `.bp-selected`, `.bp-nit`).
- Produces:
  - `globalThis.blueprintComposer.assembleResponse(screenId, answers, nits) -> string` where `answers` is `[{label, choice, note}]` in on-screen order (`choice` is a lowercase letter string or `null`; `note` is string or `null`) and `nits` is `[{region, note}]`.
  - `globalThis.blueprintComposer.assembleInvocation(meta) -> string` where `meta` is `{verb, source, orchestrator: [{name, on}], passthrough: [{name, on}]}`.
  - Fragment authoring contract (Task 3's `screens.md` documents exactly this): screen root `[data-screen="<id>"]` (optional `data-mode="recap"`, `data-approve-copy="<text>"`); questions `[data-question="<id>"][data-label="<Human label>"]` containing option cards `[data-choice="<letter>"]`; nit-able mockup parts `[data-region="<stable-id>"]` (alt-click); copy buttons `[data-copy="<payload>"]`; invocation builder root `[data-invocation][data-verb="…"][data-default-source="…"]` containing `[data-source="…"]` segments, chip groups `[data-flag-group="orchestrator|passthrough"]` with chips `[data-flag="<name>"][data-on="true|false"]`, and a preview element `[data-cmd-preview]`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/blueprint_test.sh`, immediately BEFORE the `echo "PASSES=$PASSES FAILS=$FAILS"` line:

```sh
# --- composer core: prompt + invocation assembly (pure, Node-testable) ---
cat > "$TMP/check-composer.js" <<'EOF'
require(process.env.BP + '/scripts/composer.js');
const c = globalThis.blueprintComposer;
const which = process.argv[2];
if (which === 'response') {
  process.stdout.write(c.assembleResponse('demo', [
    { label: 'Tray', choice: 'a', note: null },
    { label: 'Nits', choice: 'b', note: 'discoverable' },
    { label: 'Skipped', choice: null, note: null },
  ], [{ region: 'run.row', note: 'align right' }]));
} else {
  process.stdout.write(c.assembleInvocation({
    verb: '/blacksmith-orchestrate',
    source: 'plan (docs/plans/x.md)',
    orchestrator: [{ name: 'afk', on: true }, { name: 'unified', on: true }, { name: 'budget', on: false }],
    passthrough: [{ name: 'lookup', on: true }, { name: 'tdd', on: false }],
  }));
}
EOF

RESP=$(BP="$BP" node "$TMP/check-composer.js" response)
WANT_RESP=$(printf '[blueprint:demo]\n1) Tray → A\n2) Nits → B — note: discoverable\nNit on run.row: align right')
assert_eq "$RESP" "$WANT_RESP" "assembleResponse follows the clipboard contract"

INV=$(BP="$BP" node "$TMP/check-composer.js" invocation)
assert_eq "$INV" "/blacksmith-orchestrate plan (docs/plans/x.md) afk unified - lookup" \
  "assembleInvocation follows the grammar (off-flags and empty groups omitted)"
```

- [ ] **Step 2: Run to verify the new assertions fail**

Run: `sh tests/blueprint_test.sh`
Expected: the 7 server assertions PASS; the two new ones FAIL (node: Cannot find module `.../composer.js`). `FAILS=2`, exit 1.

- [ ] **Step 3: Implement `composer.js`**

```js
// blueprint composer: selection, per-question notes, alt-click nit flags, the
// fixed bottom tray, and the recap-mode invocation builder. Classic script by
// design: the Node test suite require()s this file and reads
// globalThis.blueprintComposer; the DOM wiring below is guarded.

function assembleResponse(screenId, answers, nits) {
  // Numbering follows on-screen question order; questions with no selection
  // and no note are omitted from the body but still advance the number, so
  // the numbers always match what the user sees.
  var lines = ['[blueprint:' + screenId + ']'];
  var n = 0;
  answers.forEach(function (a) {
    n += 1;
    if (a.choice === null && !a.note) return;
    var line = n + ') ' + a.label + ' → ' + (a.choice === null ? '(no selection)' : a.choice.toUpperCase());
    if (a.note) line += ' — note: ' + a.note;
    lines.push(line);
  });
  nits.forEach(function (t) {
    lines.push('Nit on ' + t.region + ': ' + t.note);
  });
  return lines.join('\n');
}

function assembleInvocation(meta) {
  var on = function (fs) {
    return fs.filter(function (f) { return f.on; }).map(function (f) { return f.name; });
  };
  var orch = on(meta.orchestrator);
  var pass = on(meta.passthrough);
  var parts = [meta.verb, meta.source].concat(orch);
  if (pass.length) parts = parts.concat(['-'], pass);
  return parts.join(' ');
}

globalThis.blueprintComposer = { assembleResponse: assembleResponse, assembleInvocation: assembleInvocation };

if (typeof document !== 'undefined') (function () {
  var content = document.getElementById('bp-content');
  if (!content) return;
  var root = content.querySelector('[data-screen]');
  var screenId = root ? root.getAttribute('data-screen') : 'unnamed-screen';
  var nameEl = document.getElementById('bp-screen-name');
  if (nameEl) nameEl.textContent = '· ' + screenId;

  function questionEls() {
    return Array.prototype.slice.call(content.querySelectorAll('[data-question]'));
  }

  // Inject a collapsed note toggle per question.
  questionEls().forEach(function (q) {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'bp-note-btn';
    btn.textContent = '✎';
    btn.addEventListener('click', function () {
      var input = q.querySelector('.bp-note-input');
      if (!input) {
        input = document.createElement('input');
        input.className = 'bp-note-input';
        input.placeholder = 'note for this question…';
        input.addEventListener('input', update);
        q.appendChild(input);
      } else {
        input.hidden = !input.hidden;
      }
      if (!input.hidden) input.focus();
    });
    q.appendChild(btn);
  });

  function collectAnswers() {
    return questionEls().map(function (q) {
      var sel = q.querySelector('[data-choice].bp-selected');
      var input = q.querySelector('.bp-note-input');
      return {
        label: q.getAttribute('data-label') || q.getAttribute('data-question'),
        choice: sel ? sel.getAttribute('data-choice') : null,
        note: input && !input.hidden && input.value ? input.value : null,
      };
    });
  }

  function collectNits() {
    return Array.prototype.slice.call(content.querySelectorAll('[data-region].bp-nit')).map(function (el) {
      return { region: el.getAttribute('data-region'), note: el.getAttribute('data-bp-nit') || '' };
    });
  }

  function update() {
    var a = collectAnswers();
    var sels = a.filter(function (x) { return x.choice !== null; }).length;
    var notes = a.filter(function (x) { return x.note; }).length;
    var countEl = document.getElementById('bp-count');
    if (countEl) countEl.textContent = sels + ' selections · ' + notes + ' notes · ' + collectNits().length + ' nits';
  }

  function renderPreview() {
    var b = content.querySelector('[data-invocation]');
    if (!b) return;
    var out = b.querySelector('[data-cmd-preview]');
    if (!out) return;
    var grab = function (group) {
      return Array.prototype.slice
        .call(b.querySelectorAll('[data-flag-group="' + group + '"] [data-flag]'))
        .map(function (el) { return { name: el.getAttribute('data-flag'), on: el.getAttribute('data-on') === 'true' }; });
    };
    var src = b.querySelector('[data-source].bp-selected');
    out.textContent = assembleInvocation({
      verb: b.getAttribute('data-verb'),
      source: src ? src.getAttribute('data-source') : b.getAttribute('data-default-source'),
      orchestrator: grab('orchestrator'),
      passthrough: grab('passthrough'),
    });
  }

  function copyText(text, el) {
    var done = function () {
      var old = el.textContent;
      el.textContent = 'copied — paste it in the terminal';
      setTimeout(function () { el.textContent = old; }, 1600);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, function () { legacyCopy(text); done(); });
    } else {
      legacyCopy(text); done();
    }
  }
  function legacyCopy(text) {
    var ta = document.createElement('textarea');
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    document.body.removeChild(ta);
  }

  content.addEventListener('click', function (ev) {
    var region = ev.target.closest('[data-region]');
    if (ev.altKey && region) {
      ev.preventDefault();
      if (region.classList.contains('bp-nit')) {
        region.classList.remove('bp-nit');
        region.removeAttribute('data-bp-nit');
      } else {
        var note = window.prompt('Nit on ' + region.getAttribute('data-region') + ':', '');
        if (note) {
          region.classList.add('bp-nit');
          region.setAttribute('data-bp-nit', note);
        }
      }
      update();
      return;
    }
    var opt = ev.target.closest('[data-choice]');
    if (opt) {
      var q = opt.closest('[data-question]');
      if (q) {
        Array.prototype.slice.call(q.querySelectorAll('[data-choice]')).forEach(function (el) {
          el.classList.remove('bp-selected');
        });
        opt.classList.add('bp-selected');
        update();
      }
      return;
    }
    var srcSeg = ev.target.closest('[data-source]');
    if (srcSeg) {
      var builder = srcSeg.closest('[data-invocation]');
      if (builder) {
        Array.prototype.slice.call(builder.querySelectorAll('[data-source]')).forEach(function (el) {
          el.classList.remove('bp-selected');
        });
        srcSeg.classList.add('bp-selected');
        renderPreview();
      }
      return;
    }
    var flag = ev.target.closest('[data-flag]');
    if (flag) {
      var next = flag.getAttribute('data-on') === 'true' ? 'false' : 'true';
      flag.setAttribute('data-on', next);
      flag.classList.toggle('bp-selected', next === 'true');
      renderPreview();
      return;
    }
    var copyEl = ev.target.closest('[data-copy]');
    if (copyEl) copyText(copyEl.getAttribute('data-copy'), copyEl);
  });

  var copyBtn = document.getElementById('bp-copy');
  if (copyBtn) {
    if (root && root.getAttribute('data-mode') === 'recap') {
      copyBtn.textContent = 'Copy approval';
      copyBtn.addEventListener('click', function () {
        copyText(root.getAttribute('data-approve-copy') || 'Approved — proceed to the spec.', copyBtn);
      });
    } else {
      copyBtn.addEventListener('click', function () {
        copyText(assembleResponse(screenId, collectAnswers(), collectNits()), copyBtn);
      });
    }
  }

  update();
  renderPreview();
})();
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `sh tests/blueprint_test.sh`
Expected: `PASSES=9 FAILS=0`, exit 0. Also `node --check skills/blueprint/scripts/composer.js` — no output.

- [ ] **Step 5: Commit**

```bash
git add skills/blueprint/scripts/composer.js tests/blueprint_test.sh
git commit -m "feat(blueprint): composer engine with Node-testable prompt assembly

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: References — `harvest.md`, `screens.md`, `composer.md`

**Files:**
- Create: `skills/blueprint/references/harvest.md`
- Create: `skills/blueprint/references/screens.md`
- Create: `skills/blueprint/references/composer.md`

**Interfaces:**
- Consumes: the fragment authoring contract and function shapes from Task 2 (attribute names must match `composer.js` EXACTLY: `data-screen`, `data-question`, `data-label`, `data-choice`, `data-region`, `data-mode="recap"`, `data-approve-copy`, `data-copy`, `data-invocation`, `data-verb`, `data-default-source`, `data-source`, `data-flag-group`, `data-flag`, `data-on`, `data-cmd-preview`); the server disk/HTTP contract from Task 1.
- Produces: reference filenames and section headings that Task 5's `SKILL.md` links to, and the `Manual verification recipe` sections Task 6's test greps for.

- [ ] **Step 1: Write `references/harvest.md`**

```markdown
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
```

- [ ] **Step 2: Write `references/screens.md`**

```markdown
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
```

- [ ] **Step 3: Write `references/composer.md`**

```markdown
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
```

- [ ] **Step 4: Run the docs suite**

Run: `sh tests/docs_test.sh | grep FAIL; echo "exit=$?"`
Expected: no `FAIL` lines mentioning blueprint (the global link/placeholder/frontmatter checks now cover these files; blueprint-specific checks arrive in Task 6). Note: the `broken_links` check walks these files — the links to `handoff.md` and `anti-patterns.md` do NOT resolve yet. If the suite fails on them, this task and Task 4 must land in ONE commit; in that case defer this step and Step 5's commit, complete Task 4 first, and commit both together with the message from Task 4 Step 6.

- [ ] **Step 5: Commit (only if Step 4 passed standalone)**

```bash
git add skills/blueprint/references/harvest.md skills/blueprint/references/screens.md skills/blueprint/references/composer.md
git commit -m "docs(blueprint): harvest, screen-authoring, and composer references

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: References — `ledger.md`, `handoff.md`, `anti-patterns.md`, `flags.md`

**Files:**
- Create: `skills/blueprint/references/ledger.md`
- Create: `skills/blueprint/references/handoff.md`
- Create: `skills/blueprint/references/anti-patterns.md`
- Create: `skills/blueprint/references/flags.md`

**Interfaces:**
- Consumes: builder markup contract from Task 2; screen discipline from Task 3.
- Produces: the `## Flags` table whose first column (`fresh`, `terminal`, `resume`) Task 5's `SKILL.md` table and Task 6's README table must match exactly; section names Task 5 links to.

- [ ] **Step 1: Write `references/ledger.md`**

```markdown
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
```

- [ ] **Step 2: Write `references/handoff.md`**

```markdown
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
```

- [ ] **Step 3: Write `references/anti-patterns.md`**

```markdown
# Anti-patterns & red flags

Canonical home for blueprint lessons; add new ones here, not to SKILL.md.

| Anti-pattern | Correction |
|---|---|
| Generic-framework mockups that could be any app | No screen before harvest; every fragment leans on `.brainstorm/style.css` |
| Re-improvising the frame or composer inline | Interactive machinery ships in `scripts/`; fragments carry content only |
| Reusing a screen filename | New file per revision (`layout-v2.html`); the server serves the newest |
| Accepting a paste with a stale `[blueprint:…]` header | Stop and ask; never guess which round an answer belongs to |
| Leaving a resolved screen up during terminal discussion | Push a fresh `waiting-N.html` |
| Implementation before the Step 6 gate | Hard stop — the gate has no bypass in this skill |
| Hand-writing flag chips into the handoff builder | Metadata is generated from the two skills' `flags.md` at recap time |
| Pushing screens with heredocs | File-creation tool only; heredocs dump noise into the terminal |
```

- [ ] **Step 4: Write `references/flags.md`**

```markdown
# Blueprint — Flag matrix

Flags are orthogonal and parsed from anywhere in the invocation.

## Flags

| Flag | Effect | Owner |
|---|---|---|
| `fresh` | Force a full design re-harvest, ignoring the `.brainstorm/` cache | [harvest.md](harvest.md) |
| `terminal` | Skip the browser; run every round in the terminal fallback | [screens.md](screens.md) |
| `resume` | Continue from an existing ledger: restart the server, re-push the last unresolved screen | [ledger.md](ledger.md) |

## Composition rules

All three compose freely. `terminal` + `resume` resumes without restarting
the server. `fresh` affects only Step 2; it never clears ledgers or screens.
There are no conflicting combinations.
```

- [ ] **Step 5: Run the docs suite**

Run: `sh tests/docs_test.sh | grep -c FAIL`
Expected: `0` — all cross-file links among the seven reference files now resolve.

- [ ] **Step 6: Commit**

```bash
git add skills/blueprint/references/
git commit -m "docs(blueprint): ledger, handoff, anti-patterns, and flag matrix references

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

(If Task 3 deferred its commit due to the link check, this commit includes all seven reference files; use this message.)

---

### Task 5: `SKILL.md`

**Files:**
- Create: `skills/blueprint/SKILL.md`

**Interfaces:**
- Consumes: every reference filename from Tasks 3–4 (all linked); the flag names from `references/flags.md` (`fresh`, `terminal`, `resume`) — the Parameters table's first column must match them exactly and be the ONLY table under `## Parameters`.
- Produces: the workflow contract the running agent obeys; the `## Parameters` heading Task 6's parity check reads.

- [ ] **Step 1: Write `SKILL.md`**

```markdown
---
name: blueprint
description: Brainstorm UI/UX changes into an approved design through interactive browser proposals rendered in the project's real design language. Option clicks assemble a response prompt copied to the user's clipboard. Use when the user runs /blueprint or wants to brainstorm, redesign, or visually verify UI/UX work before implementation.
---

# Blueprint

> Design it in the browser, approve it at the gate, hand the blueprint to the
> blacksmith: **blueprint → forge → blacksmith-orchestrate**.

## Overview

Blueprint owns the whole UI/UX brainstorming arc: harvest the project's real
design language, push interactive proposal screens, resolve rounds through
clipboard-pasted responses, gate on approval, write the spec, and hand off to
plans, tickets, or orchestration. The browser never talks back to the agent —
the user's paste is the only return channel, so the companion server keeps no
state and its death mid-session loses nothing.

The interactive machinery ships in [scripts/](scripts/serve.mjs) and is never
reimplemented inline; each session authors only HTML content fragments per
[references/screens.md](references/screens.md).

## Parameters

Flags compose and are parsed from anywhere in the invocation; the canonical
matrix with composition rules is [references/flags.md](references/flags.md).

| Flag | Effect |
|---|---|
| `fresh` | Force a full design re-harvest, ignoring the `.brainstorm/` cache |
| `terminal` | Skip the browser; run every round in the terminal fallback |
| `resume` | Continue from an existing ledger: restart the server, re-push the last unresolved screen |

## When to Use

Use for UI/UX brainstorming: new screens, redesigns, component-level polish,
anything where the user should *see* options before choosing. If the topic
has no visual dimension (pure backend or API design), say so in one line and
defer to a plain brainstorming workflow instead of forcing a browser on a
text problem.

## Workflow

    Part 1 — Setup (1–3):    classify → harvest → start companion
    Part 2 — Rounds (4–5):   push screen → read pasted response, ledger it   (loop)
    Part 3 — Close (6–8):    [GATE] recap + approval → spec → handoff

### Step 1 — Classify & parse

Confirm the topic is visual (see When to Use). Parse flags. Enumerate the UI
items in scope — sessions typically batch several; each becomes a track
through the rounds.

### Step 2 — Design harvest

Build or refresh `.brainstorm/style.css` and `.brainstorm/design-notes.md`
per [references/harvest.md](references/harvest.md). **No screen may be pushed
before the harvest exists.**

### Step 3 — Start the companion

Run `node <skill>/scripts/serve.mjs --project-dir <project> --open` in the
background. Verify aliveness by statting `.brainstorm/server-info`; share the
printed URL every round as fallback. If the server cannot start twice, or the
`terminal` flag is set, degrade per the terminal-fallback section of
[references/screens.md](references/screens.md) with a one-line warning.

### Step 4 — Push a round

Author a content fragment per [references/screens.md](references/screens.md)
into `.brainstorm/screens/`, then summarize in the terminal what is on
screen and ask the user to click and paste.

**HARD GATE: nothing touches the target codebase before Step 6 approval. No
flag bypasses this.**

### Step 5 — Resolve the round

Parse the pasted response per
[references/composer.md](references/composer.md): verify the screen header,
map answers by order, treat nits as change requests. Append decisions to the
ledger per [references/ledger.md](references/ledger.md). Revise (new `-vN`
screen) or advance; push a waiting screen when returning to terminal-only
discussion.

### Step 6 — GATE: recap and approval

Push a recap screen rendered from the ledger (`data-mode="recap"`). The user
approves in the terminal, or clicks **Copy approval** and pastes the phrase.
No approval → stop here.

### Step 7 — Spec

Assemble the design doc from the ledger into
`docs/specs/YYYY-MM-DD-<topic>-design.md`: design decisions per UI item plus
a one-line-each "Rejected alternatives" appendix. Self-review for
placeholders, contradictions, scope, ambiguity; fix inline; commit.

### Step 8 — Handoff

Push the handoff screen per
[references/handoff.md](references/handoff.md): plans route, `/to-tickets`
route, and the blacksmith invocation builder with generated flag chips.

## Anti-patterns

New lessons go to [references/anti-patterns.md](references/anti-patterns.md),
the canonical home — not into this file.
```

- [ ] **Step 2: Run the docs suite**

Run: `sh tests/docs_test.sh | grep -c FAIL`
Expected: `0` — frontmatter present, all links resolve (including `scripts/serve.mjs`), no placeholders.

- [ ] **Step 3: Commit**

```bash
git add skills/blueprint/SKILL.md
git commit -m "feat(blueprint): SKILL.md — 8-step visual brainstorming workflow

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: `docs_test.sh` blueprint block + `README.md`

**Files:**
- Modify: `tests/docs_test.sh` (append the blueprint block before the final summary/exit lines, mirroring the blacksmith block's placement)
- Modify: `README.md` (add the blueprint section; heading `## Blueprint flags` for the flag table)

**Interfaces:**
- Consumes: heading strings exactly as created earlier — `## Flags` in `skills/blueprint/references/flags.md`, `## Parameters` in `skills/blueprint/SKILL.md`; the existing `flag_names`, `assert_eq`, `assert_nonempty` helpers in `docs_test.sh`.
- Produces: mechanical enforcement of the three-way flag sync and the recipe convention for blueprint.

- [ ] **Step 1: Add the README section**

Add after the blacksmith-orchestrate section, following the README's existing structure (verb-first intro, then flags):

```markdown
## blueprint

Design it before you forge it: `/blueprint` runs an interactive UI/UX
brainstorming session in the browser. Proposal screens are rendered from the
project's own design language (DESIGN.md + harvested tokens and components);
clicking options, notes, and nit flags assembles a response prompt copied to
your clipboard — paste it back into the session to resolve the round. An
approval gate, a generated spec, and a handoff screen (plans, `/to-tickets`,
or a `/blacksmith-orchestrate` invocation builder) close the loop. The
pipeline reads: **blueprint** (design it) → **forge** (ship one task) →
**blacksmith-orchestrate** (ship many).

## Blueprint flags

| Flag | Effect |
|---|---|
| `fresh` | Force a full design re-harvest, ignoring the `.brainstorm/` cache |
| `terminal` | Skip the browser; run every round in the terminal fallback |
| `resume` | Continue from an existing ledger: restart the server, re-push the last unresolved screen |
```

- [ ] **Step 2: Write the failing docs-test block**

Append to `tests/docs_test.sh`, before its final summary/exit lines (mirror how the blacksmith block ends). Written BEFORE the README edit lands it would fail; with Step 1 done it should pass immediately — run once with Step 1 stashed (`git stash -- README.md`) to see it fail if strict TDD sequencing is wanted, then unstash.

```sh
# --- blueprint: skeleton, machinery, flag parity, recipes ---
BLU="$ROOT/skills/blueprint"
assert_nonempty "$(ls "$BLU/SKILL.md" 2>/dev/null)" "blueprint: SKILL.md exists"

_blu_flags=$(flag_names "$BLU/references/flags.md" '^## Flags')
_blu_skill=$(flag_names "$BLU/SKILL.md" '^## Parameters')
_blu_readme=$(flag_names "$ROOT/README.md" '^## Blueprint flags')
assert_nonempty "$_blu_flags"  "blueprint: flags.md flag table is non-empty"
assert_nonempty "$_blu_skill"  "blueprint: SKILL.md flag table is non-empty"
assert_nonempty "$_blu_readme" "blueprint: README flag table is non-empty"
assert_eq "$_blu_flags" "$_blu_skill"  "blueprint: flags.md and SKILL.md flag tables agree"
assert_eq "$_blu_flags" "$_blu_readme" "blueprint: flags.md and README flag tables agree"

# flags.md and anti-patterns.md are excluded from the recipe rule, same
# convention as blacksmith: a flag matrix and an anti-pattern list are not
# behaviors verified by running something.
_blu_norecipe=$(find "$BLU/references" -maxdepth 1 -name '*.md' -type f | sort | while read -r _f; do
  case "$_f" in
    */flags.md|*/anti-patterns.md) continue ;;
  esac
  grep -q 'Manual verification recipe' "$_f" || printf '%s\n' "$_f"
done)
assert_eq "$_blu_norecipe" "" \
  "every blueprint/references/*.md (except flags.md, anti-patterns.md) has a Manual verification recipe"

# Shipped machinery: both scripts must parse; the frame must carry the
# placeholder serve.mjs substitutes fragments into.
assert_eq "$(node --check "$BLU/scripts/serve.mjs" 2>&1)" "" "blueprint: serve.mjs parses"
assert_eq "$(node --check "$BLU/scripts/composer.js" 2>&1)" "" "blueprint: composer.js parses"
assert_nonempty "$(grep -l 'BLUEPRINT:CONTENT' "$BLU/scripts/frame.html" 2>/dev/null)" \
  "blueprint: frame.html carries the content placeholder"
```

- [ ] **Step 3: Run both suites**

Run: `sh tests/docs_test.sh | grep FAIL; sh tests/install_test.sh | grep FAIL`
Expected: no FAIL lines from either; `docs_test.sh` output now includes the blueprint PASS lines.

- [ ] **Step 4: Commit**

```bash
git add tests/docs_test.sh README.md
git commit -m "test(blueprint): docs invariants + README section with flag table

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Full verification + manual companion recipe

**Files:**
- Modify: none expected (fix-forward if verification finds drift)

**Interfaces:**
- Consumes: everything above.
- Produces: a verified branch ready for PR.

- [ ] **Step 1: Run all three suites**

```bash
sh tests/install_test.sh | tail -3
sh tests/docs_test.sh   | tail -3
sh tests/blueprint_test.sh | tail -3
```
Expected: zero FAILs in each, all exit 0.

- [ ] **Step 2: Manual end-to-end recipe (human-verifiable)**

```bash
TMPD=$(mktemp -d)
mkdir -p "$TMPD/.brainstorm/screens"
printf '<div data-screen="demo"><section data-question="q1" data-label="Tray"><div data-choice="a">A card</div><div data-choice="b">B card</div></section><div data-region="demo.row">a mockup row</div></div>' > "$TMPD/.brainstorm/screens/demo.html"
node skills/blueprint/scripts/serve.mjs --project-dir "$TMPD" --open
```

In the opened tab: click "A card" (outlined, tray says `1 selections`);
alt-click the mockup row and enter a note (dashed outline, `1 nits`); click
**Copy response** and paste — must read:

```
[blueprint:demo]
1) Tray → A
Nit on demo.row: <your note>
```

Ctrl-C the server; `.brainstorm/server-info` in `$TMPD` must be gone. Remove `$TMPD`.

- [ ] **Step 3: Verify the branch is clean and push-ready**

```bash
git status --short   # expect empty
git log --oneline main..HEAD   # expect the spec commit + Tasks 1–6 commits
```

Do NOT push or open a PR — that is the user's call after review.
