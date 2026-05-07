#!/usr/bin/env python3
"""
explain-lint.py — Author guardrail for /explain fragments.

Usage:
  python3 scripts/lib/explain-lint.py [--strict] [--no-lint] <fragment.html>...

Exit codes:
  0  — lint passed (or --no-lint)
  1  — forbidden classes found, or (with --strict) any warnings present
"""

import re
import sys
import os
import pathlib

# ── Prism language allow-list ────────────────────────────────────────────────
ALLOWED_LANGUAGES = {'bash', 'yaml', 'json', 'javascript', 'typescript',
                     'python', 'html', 'css', 'markdown'}

# ── Forbidden class / attribute tokens ──────────────────────────────────────
FORBIDDEN_CLASSES = {
    'chat-window',
    'chat-message',
    'chat-bubble',
    'chat-typing',
    'chat-progress',
    'chat-next-btn',
    'chat-all-btn',
    'chat-reset-btn',
}

FORBIDDEN_JS = {
    'selectOption',
    'checkQuiz',
    'resetQuiz',
}


def extract_defined_classes(css_text):
    """Return set of class names defined in a CSS file."""
    return set(re.findall(r'\.([\w-]+)', css_text))


def extract_defined_js_names(js_text):
    """Return set of function names / identifiers defined at top level in JS."""
    # Pick up function declarations and var/let/const assignments of functions
    names = set()
    for m in re.finditer(r'function\s+([\w]+)\s*\(', js_text):
        names.add(m.group(1))
    for m in re.finditer(r'(?:var|let|const)\s+([\w]+)\s*=', js_text):
        names.add(m.group(1))
    return names


def extract_css_vars(text):
    """Return all --var-name references used in a file."""
    return set(re.findall(r'var\((--[\w-]+)\)', text))


def lint_fragment(path, defined_classes, defined_css_vars, strict):
    """Lint one fragment. Returns (warnings, forbidden_count)."""
    warnings = []
    forbidden = 0

    try:
        content = pathlib.Path(path).read_text(encoding='utf-8')
    except OSError as e:
        print(f'ERROR: cannot read {path}: {e}', file=sys.stderr)
        return warnings, forbidden

    filename = os.path.basename(path)

    # 1. Collect all class tokens used in the fragment
    used_classes = set()
    for attr_val in re.findall(r'class="([^"]*)"', content):
        for token in attr_val.split():
            used_classes.add(token)

    # 2. Check forbidden classes
    for cls in sorted(used_classes):
        if cls in FORBIDDEN_CLASSES:
            print(f'ERROR: forbidden class .{cls} in {filename}')
            forbidden += 1

    # 3. Check for forbidden inline JS handlers
    onclick_matches = re.findall(r'onclick="([^"]*)"', content)
    for val in onclick_matches:
        val = val.strip()
        if val:
            matched_forbidden = False
            for name in FORBIDDEN_JS:
                if name in val:
                    print(f'ERROR: forbidden handler {name}() in onclick attr in {filename}')
                    forbidden += 1
                    matched_forbidden = True
            if not matched_forbidden:
                # Any non-empty onclick is forbidden per contract
                print(f'WARN: non-empty onclick="{val[:40]}" in {filename} — use event listeners instead')
                warnings.append(f'onclick in {filename}')

    # 4. Warn on undefined classes (not forbidden, just absent from styles.css).
    #    `language-*` tokens are owned by Prism (rule 7 vets the allow-list);
    #    skip them here so the styles.css check doesn't double-flag.
    for cls in sorted(used_classes):
        if cls.startswith('language-'):
            continue
        if cls not in FORBIDDEN_CLASSES and cls not in defined_classes:
            msg = f'WARN: class .{cls} used in {filename} not in styles.css'
            print(msg)
            warnings.append(msg)

    # 5. Check undefined CSS variables
    used_vars = extract_css_vars(content)
    for var in sorted(used_vars):
        if var not in defined_css_vars:
            msg = f'WARN: undefined CSS var {var} in {filename}'
            print(msg)
            warnings.append(msg)

    # 6. Check aria-describedby targets exist in same file
    for tip_id in re.findall(r'aria-describedby="([^"]*)"', content):
        if tip_id and not re.search(r'id="' + re.escape(tip_id) + r'"', content):
            msg = f'WARN: aria-describedby="{tip_id}" has no matching id in {filename}'
            print(msg)
            warnings.append(msg)

    # 7. Check Prism language classes against allow-list
    for lang in re.findall(r'class="language-([\w-]+)"', content):
        if lang not in ALLOWED_LANGUAGES:
            msg = f'WARN: language-{lang} not in allow-list in {filename}'
            print(msg)
            warnings.append(msg)

    # 8. Diagram-first check: inside each <section class="screen">, if a
    #    <pre class="mermaid"> exists, it must be the first non-whitespace
    #    element inside <div class="screen__body">.
    screen_blocks = re.findall(
        r'<section class="screen">.*?</section>', content, re.S)
    for screen_idx, screen in enumerate(screen_blocks, start=1):
        if 'class="mermaid"' not in screen:
            continue
        body_m = re.search(r'<div class="screen__body">(.*)', screen, re.S)
        if not body_m:
            continue
        body_content = body_m.group(1).strip()
        first_tag_m = re.match(r'\s*<([^\s>]+)([^>]*)>', body_content)
        if not first_tag_m:
            continue
        first_tag_full = first_tag_m.group(0)
        if 'class="mermaid"' not in first_tag_full:
            msg = (f'WARN: diagram-first violation in screen {screen_idx}'
                   f' of {filename} (first element: {first_tag_full[:60]})')
            print(msg)
            warnings.append(msg)

    return warnings, forbidden


def main():
    args = sys.argv[1:]
    strict = '--strict' in args
    no_lint = '--no-lint' in args

    if no_lint:
        print('lint: skipped (--no-lint)')
        sys.exit(0)

    args = [a for a in args if a not in ('--strict', '--no-lint')]

    if not args:
        print('explain-lint.py: no fragment files provided', file=sys.stderr)
        sys.exit(0)

    # Resolve template paths relative to repo root (script may be called from
    # any working directory; we derive the root from this file's location).
    script_dir = pathlib.Path(__file__).resolve().parent  # scripts/lib/
    repo_root = script_dir.parent.parent                  # agent-flow/
    templates_dir = repo_root / 'templates' / 'explain'

    css_path = templates_dir / 'styles.css'
    js_path  = templates_dir / 'main.js'

    defined_classes = set()
    defined_css_vars = set()

    if css_path.exists():
        css_text = css_path.read_text(encoding='utf-8')
        defined_classes = extract_defined_classes(css_text)
        # Extract all --var-name tokens declared in :root (or anywhere in CSS)
        defined_css_vars = set(re.findall(r'(--[\w-]+)\s*:', css_text))
    else:
        print(f'WARN: styles.css not found at {css_path}', file=sys.stderr)

    total_warnings = []
    total_forbidden = 0

    # Check that FORBIDDEN_JS names are not defined in main.js (regression guard).
    if js_path.exists():
        js_text = js_path.read_text(encoding='utf-8')
        for name in sorted(FORBIDDEN_JS):
            pattern = rf'\b(?:function\s+{name}|{name}\s*=|{name}\s*:)'
            if re.search(pattern, js_text):
                print(f'ERROR: forbidden JS handler {name} defined in templates/explain/main.js')
                total_forbidden += 1
    else:
        print(f'WARN: main.js not found at {js_path}', file=sys.stderr)

    for path in args:
        w, f = lint_fragment(path, defined_classes, defined_css_vars, strict)
        total_warnings.extend(w)
        total_forbidden += f

    n_warn = len(total_warnings)
    print(f'lint: {n_warn} warning{"s" if n_warn != 1 else ""}, {total_forbidden} forbidden')

    if total_forbidden > 0:
        sys.exit(1)
    if strict and n_warn > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == '__main__':
    main()
