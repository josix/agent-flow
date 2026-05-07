(function () {
  'use strict';

  // ── Prism integration ─────────────────────────────────────────────────
  // Prism's autoloader fetches grammars asynchronously. If we wrap lines on
  // DOMContentLoaded, an autoloader callback that lands later will overwrite
  // <pre>.innerHTML and destroy the .line spans. Subscribe to Prism's per-
  // element 'complete' hook so wrapping always runs AFTER Prism finishes
  // (sync OR async), and let wrapPreLines be idempotent. Hook is registered
  // synchronously here so it catches Prism's own DOMContentLoaded pass too.
  if (window.Prism && window.Prism.hooks && typeof window.Prism.hooks.add === 'function') {
    window.Prism.hooks.add('complete', function (env) {
      if (!env || !env.element || typeof env.element.closest !== 'function') return;
      var panel = env.element.closest('.translator__code, .translation-code');
      if (panel) {
        wrapPreLines(panel);
        // After wrap, .line spans exist — wire scroll-sync if the parent translator is around
        var translator = panel.closest('[data-translator]');
        if (translator) {
          var englishPanel = translator.querySelector('.translator__english, .translation-english');
          if (englishPanel) attachScrollSync(panel, englishPanel);
        }
      }
    });
  }

  /* ── Translator dual-pane (Task 8) ──────────────────────────────────── */
  function initTranslators() {
    var translators = document.querySelectorAll('[data-translator]');
    translators.forEach(function (translator) {
      var toggle = translator.querySelector('.translator__toggle, .translator-toggle');
      var codePanel = translator.querySelector('.translator__code, .translation-code');
      var englishPanel = translator.querySelector('.translator__english, .translation-english');
      if (!toggle || !codePanel || !englishPanel) return;

      // English visible by default (fixes the hide-by-default bug).
      toggle.textContent = 'Hide English';

      // For language-classed code, the Prism 'complete' hook above wraps the
      // panel after highlighting (handles autoloader's async grammar fetch).
      // For unhighlighted code, wrap immediately so hover-anchors work right
      // away. wrapPreLines is idempotent either way.
      var code = codePanel.querySelector('pre code');
      var hasLang = !!(code && code.className && /\blanguage-[\w-]+/.test(code.className));
      if (!hasLang || !window.Prism) {
        wrapPreLines(codePanel);
      }

      // Anchor hover: English <li data-anchor="3-5"> highlights matching .line spans.
      var anchorItems = englishPanel.querySelectorAll('[data-anchor]');
      anchorItems.forEach(function (item) {
        var range = parseRange(item.dataset.anchor);
        item.addEventListener('mouseenter', function () { setHighlight(codePanel, range, true); });
        item.addEventListener('focus',      function () { setHighlight(codePanel, range, true); });
        item.addEventListener('mouseleave', function () { setHighlight(codePanel, range, false); });
        item.addEventListener('blur',       function () { setHighlight(codePanel, range, false); });
      });

      attachReverseHover(codePanel, englishPanel);
      attachPin(englishPanel, codePanel);
      // Pre-highlight first bullet for discoverability
      var firstAnchor = englishPanel.querySelector('[data-anchor]');
      if (firstAnchor) {
        firstAnchor.classList.add('is-highlighted');
        // Don't pre-highlight code-side lines yet (they may not exist if Prism is async).
        // Just mark the first bullet so the user sees the affordance.
      }
      attachScrollSync(codePanel, englishPanel);

      toggle.addEventListener('click', function () {
        var hidden = englishPanel.hidden || englishPanel.style.display === 'none';
        if (hidden) {
          englishPanel.hidden = false;
          englishPanel.style.display = '';
          toggle.textContent = 'Hide English';
        } else {
          englishPanel.hidden = true;
          toggle.textContent = 'Show English';
        }
      });
    });
  }

  function wrapPreLines(panel) {
    var pre = panel.querySelector('pre');
    if (!pre) return;
    // Idempotency guard: skip if we've already wrapped this panel. Prism's
    // 'complete' hook can fire more than once per element (e.g. on re-
    // highlight); each invocation must be a no-op after the first.
    if (pre.querySelector('.line')) return;
    // After Prism runs, the <pre> typically contains a <code> element holding
    // a mix of TextNodes and ELEMENT_NODE token spans. Without a language
    // class, it's a single TextNode (or a <code> wrapping one). Descend into
    // <code> if present, else operate on <pre> directly.
    var source = pre.querySelector('code') || pre;
    var children = Array.prototype.slice.call(source.childNodes);

    var lines = [[]];
    function pushNode(node) { lines[lines.length - 1].push(node); }
    function newline() { lines.push([]); }

    for (var i = 0; i < children.length; i++) {
      var node = children[i];
      if (node.nodeType === 3 /* TEXT_NODE */) {
        var parts = node.nodeValue.split('\n');
        for (var p = 0; p < parts.length; p++) {
          if (p > 0) newline();
          if (parts[p].length > 0) {
            pushNode(document.createTextNode(parts[p]));
          }
        }
      } else if (node.nodeType === 1 /* ELEMENT_NODE */) {
        // Token spans typically don't contain '\n' (Prism splits them), but
        // be defensive: if textContent contains a newline, fall back to
        // recursive split.
        if (node.textContent.indexOf('\n') === -1) {
          pushNode(node.cloneNode(true));
        } else {
          // Rare path: clone and split by walking the element's own text.
          var elText = node.textContent.split('\n');
          for (var e = 0; e < elText.length; e++) {
            if (e > 0) newline();
            if (elText[e].length > 0) {
              var clone = node.cloneNode(false);
              clone.textContent = elText[e];
              pushNode(clone);
            }
          }
        }
      }
    }

    // Drop a trailing empty line caused by content ending in '\n'.
    if (lines.length > 0 && lines[lines.length - 1].length === 0) lines.pop();

    // Build replacement
    var frag = document.createDocumentFragment();
    for (var l = 0; l < lines.length; l++) {
      var span = document.createElement('span');
      span.className = 'line';
      span.dataset.line = String(l + 1);
      for (var n = 0; n < lines[l].length; n++) {
        span.appendChild(lines[l][n]);
      }
      frag.appendChild(span);
      if (l < lines.length - 1) {
        frag.appendChild(document.createTextNode('\n'));
      }
    }

    // Wipe original contents and install wrapped lines
    while (source.firstChild) source.removeChild(source.firstChild);
    source.appendChild(frag);
  }

  function parseRange(anchor) {
    if (!anchor) return { from: 0, to: 0 };
    var parts = anchor.split('-');
    var from = parseInt(parts[0], 10);
    var to = parts.length > 1 ? parseInt(parts[1], 10) : from;
    return { from: from, to: to };
  }

  function setHighlight(codePanel, range, on) {
    var spans = codePanel.querySelectorAll('.line');
    spans.forEach(function (span) {
      var n = parseInt(span.dataset.line, 10);
      if (n >= range.from && n <= range.to) {
        if (on) span.classList.add('is-highlighted');
        else     span.classList.remove('is-highlighted');
      }
    });
  }

  function clearAllHighlights(codePanel, englishPanel) {
    var lines = codePanel.querySelectorAll('.line');
    lines.forEach(function (s) { s.classList.remove('is-highlighted'); });
    var items = englishPanel.querySelectorAll('[data-anchor]');
    items.forEach(function (li) { li.classList.remove('is-highlighted'); });
  }

  function attachReverseHover(codePanel, englishPanel) {
    if (codePanel.dataset.reverseHoverBound === '1') return;  // idempotent
    codePanel.dataset.reverseHoverBound = '1';

    codePanel.addEventListener('mouseover', function (e) {
      var line = e.target && e.target.closest && e.target.closest('.line');
      if (!line || !codePanel.contains(line)) return;
      if (englishPanel.querySelector('.is-pinned')) return;  // pin wins
      var n = parseInt(line.dataset.line, 10);
      if (!n) return;
      // Highlight matching <li>s
      var items = englishPanel.querySelectorAll('[data-anchor]');
      for (var i = 0; i < items.length; i++) {
        var range = parseRange(items[i].dataset.anchor);
        if (n >= range.from && n <= range.to) {
          items[i].classList.add('is-highlighted');
        } else {
          items[i].classList.remove('is-highlighted');
        }
      }
      // Also light just this single line on the code side
      setHighlight(codePanel, { from: n, to: n }, true);
    });

    codePanel.addEventListener('mouseleave', function () {
      if (englishPanel.querySelector('.is-pinned')) return;
      clearAllHighlights(codePanel, englishPanel);
    });
  }

  function attachPin(englishPanel, codePanel) {
    if (englishPanel.dataset.pinBound === '1') return;
    englishPanel.dataset.pinBound = '1';

    // Make every clickable bullet keyboard-operable: button-like role,
    // tabbable, and pin state announced via aria-pressed.
    var bullets = englishPanel.querySelectorAll('li[data-anchor]');
    bullets.forEach(function (li) {
      li.setAttribute('role', 'button');
      li.setAttribute('tabindex', '0');
      li.setAttribute('aria-pressed', 'false');
    });

    function togglePin(li) {
      var range = parseRange(li.dataset.anchor);
      var currentlyPinned = englishPanel.querySelector('.is-pinned');
      if (currentlyPinned === li) {
        li.classList.remove('is-pinned', 'is-highlighted');
        li.setAttribute('aria-pressed', 'false');
        setHighlight(codePanel, range, false);
        return;
      }
      if (currentlyPinned) {
        var prevRange = parseRange(currentlyPinned.dataset.anchor);
        currentlyPinned.classList.remove('is-pinned', 'is-highlighted');
        currentlyPinned.setAttribute('aria-pressed', 'false');
        setHighlight(codePanel, prevRange, false);
      }
      clearAllHighlights(codePanel, englishPanel);  // clear any hover state
      li.classList.add('is-pinned', 'is-highlighted');
      li.setAttribute('aria-pressed', 'true');
      setHighlight(codePanel, range, true);
    }

    englishPanel.addEventListener('click', function (e) {
      if (e.detail > 1) return;  // ignore double/triple clicks (text selection)
      if (e.target.closest('a, button, .term-trigger')) return;
      var li = e.target.closest('li[data-anchor]');
      if (!li) return;  // click outside a bullet — preserve text selection freedom
      togglePin(li);
    });

    englishPanel.addEventListener('keydown', function (e) {
      if (e.key !== 'Enter' && e.key !== ' ' && e.key !== 'Spacebar') return;
      var li = e.target && e.target.closest && e.target.closest('li[data-anchor]');
      if (!li) return;
      if (e.target.closest('a, button, .term-trigger')) return;
      e.preventDefault();  // stop Space from scrolling the page
      togglePin(li);
    });
  }

  function attachScrollSync(codePanel, englishPanel) {
    if (codePanel.dataset.scrollSyncBound === '1') return;
    if (typeof IntersectionObserver === 'undefined') return;
    var spans = codePanel.querySelectorAll('.line');
    if (spans.length === 0) return;  // wrapPreLines hasn't run yet; will be called again later
    codePanel.dataset.scrollSyncBound = '1';

    var observer = new IntersectionObserver(function (entries) {
      if (englishPanel.querySelector('.is-pinned')) return;
      entries.forEach(function (entry) {
        if (!entry.isIntersecting || entry.intersectionRatio < 0.5) return;
        var n = parseInt(entry.target.dataset.line, 10);
        if (!n) return;
        var items = englishPanel.querySelectorAll('[data-anchor]');
        items.forEach(function (li) {
          var r = parseRange(li.dataset.anchor);
          li.classList.toggle('is-highlighted', n >= r.from && n <= r.to);
        });
      });
    }, { threshold: 0.5, root: codePanel });

    spans.forEach(function (s) { observer.observe(s); });
  }

  /* ── Quiz primitive (Task 6) ─────────────────────────────────────────── */
  function initQuizzes() {
    var quizzes = document.querySelectorAll('[data-quiz]');
    quizzes.forEach(function (container) {
      var feedback = container.querySelector('.quiz-feedback');
      if (feedback) {
        feedback.setAttribute('aria-live', 'polite');
      }

      container.addEventListener('change', function (e) {
        var input = e.target;
        if (!input || input.type !== 'radio') return;
        var feedback = container.querySelector('.quiz-feedback');
        if (!feedback) return;

        var correct = String(container.dataset.correct);
        var chosen  = String(input.value);

        if (chosen === correct) {
          var msg = container.dataset.feedbackCorrect || 'Correct!';
          feedback.textContent = msg;
          feedback.dataset.state = 'correct';
        } else {
          var key = 'feedbackIncorrect' + chosen;
          var fallback = container.dataset.feedbackIncorrect || 'Not quite — try again.';
          var msg = container.dataset[key] || fallback;
          feedback.textContent = msg;
          feedback.dataset.state = 'incorrect';
        }
      });
    });
  }

  /* ── Tooltip primitive (Task 7) ──────────────────────────────────────── */
  function initTooltips() {
    var triggers = document.querySelectorAll('.term-trigger');
    var activeTooltip = null;

    triggers.forEach(function (trigger) {
      var tipId = trigger.getAttribute('aria-describedby');
      if (!tipId) return;
      var tip = document.getElementById(tipId);
      if (!tip) return;

      function show() {
        if (activeTooltip && activeTooltip !== tip) {
          activeTooltip.hidden = true;
        }
        tip.hidden = false;
        activeTooltip = tip;
        positionTooltip(trigger, tip);
      }

      function hide() {
        tip.hidden = true;
        if (activeTooltip === tip) activeTooltip = null;
      }

      trigger.addEventListener('mouseenter', show);
      trigger.addEventListener('focus',      show);
      trigger.addEventListener('mouseleave', hide);
      trigger.addEventListener('blur',       hide);
    });

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && activeTooltip) {
        activeTooltip.hidden = true;
        activeTooltip = null;
      }
    });
  }

  function positionTooltip(trigger, tip) {
    var rect = trigger.getBoundingClientRect();
    tip.style.position = 'fixed';
    tip.style.left = (rect.left + rect.width / 2) + 'px';
    tip.style.top  = (rect.top - 8) + 'px';
    tip.style.transform = 'translate(-50%, -100%)';
  }

  /* ── TOC + progress (Task 10) ────────────────────────────────────────── */
  function initToc() {
    var screens = document.querySelectorAll('.screen');
    var nav = document.querySelector('.screen-toc');
    if (!nav || screens.length === 0) return;

    nav.hidden = false;

    var ol = document.createElement('ol');
    screens.forEach(function (screen, i) {
      if (!screen.id) screen.id = 'screen-' + (i + 1);
      var title = screen.querySelector('.screen__title');
      var label = title ? title.textContent : ('Screen ' + (i + 1));
      var li = document.createElement('li');
      var a  = document.createElement('a');
      a.href = '#' + screen.id;
      a.textContent = label;
      a.title = label;
      li.appendChild(a);
      ol.appendChild(li);
    });

    nav.appendChild(ol);

    if ('IntersectionObserver' in window) {
      var items = ol.querySelectorAll('li');
      var observer = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.intersectionRatio < 0.5) return;
          var id = entry.target.id;
          items.forEach(function (li) {
            var href = li.querySelector('a').getAttribute('href');
            li.classList.toggle('is-active', href === '#' + id);
          });
        });
      }, { threshold: 0.5 });

      screens.forEach(function (screen) { observer.observe(screen); });
    }
  }

  /* ── File-ref click-to-copy (Task 13) ────────────────────────────────── */
  function initFileRefs() {
    var pattern = /\b([\w.\/-]+\.(?:py|ts|tsx|js|md|sh|html|css|json|yaml|yml)):(\d+)(?:-\d+)?\b/g;
    var zones = document.querySelectorAll('.screen__body, .references');

    zones.forEach(function (zone) {
      walkTextNodes(zone, function (node) {
        var text = node.nodeValue;
        if (!pattern.test(text)) return;
        pattern.lastIndex = 0;

        var frag = document.createDocumentFragment();
        var last = 0;
        var m;
        while ((m = pattern.exec(text)) !== null) {
          if (m.index > last) {
            frag.appendChild(document.createTextNode(text.slice(last, m.index)));
          }
          var btn = document.createElement('button');
          btn.className = 'file-ref';
          btn.type = 'button';
          btn.dataset.ref = m[0];
          btn.textContent = m[0];
          btn.addEventListener('click', copyFileRef);
          frag.appendChild(btn);
          last = m.index + m[0].length;
        }
        if (last < text.length) {
          frag.appendChild(document.createTextNode(text.slice(last)));
        }
        node.parentNode.replaceChild(frag, node);
      });
    });
  }

  function walkTextNodes(root, cb) {
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null, false);
    var nodes = [];
    var node;
    while ((node = walker.nextNode())) nodes.push(node);
    nodes.forEach(cb);
  }

  function copyFileRef(e) {
    var btn = e.currentTarget;
    var ref = btn.dataset.ref;
    var pill = document.createElement('div');
    pill.className = 'copied-pill';
    pill.textContent = 'Copied: ' + ref;
    document.body.appendChild(pill);
    setTimeout(function () {
      if (pill.parentNode) pill.parentNode.removeChild(pill);
    }, 1400);

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(ref).catch(function () { fallbackCopy(ref); });
    } else {
      fallbackCopy(ref);
    }
  }

  function fallbackCopy(text) {
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.focus();
    ta.select();
    try { document.execCommand('copy'); } catch (e) { /* silent */ }
    document.body.removeChild(ta);
  }

  /* ── Boot ────────────────────────────────────────────────────────────── */
  function init() {
    initTranslators();
    initQuizzes();
    initTooltips();
    initToc();
    initFileRefs();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
}());
