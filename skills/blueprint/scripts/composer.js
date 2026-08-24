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
