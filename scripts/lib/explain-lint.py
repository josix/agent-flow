#!/usr/bin/env python3
"""
explain-lint.py — Author guardrail for /explain fragments.

Usage:
  python3 scripts/lib/explain-lint.py [--strict] [--no-lint] <fragment.html>...

Enforces 11 rules: forbidden classes/JS/onclick (1-2), undefined classes/CSS
vars (3-4), aria-describedby integrity (5), language-* allow-list (6),
diagram-first ordering (7), duplicate onclick check (8), and three
warning-only readability rules -- no visual element in a screen (9), overlong
paragraphs (10), and unfilled __PLACEHOLDER__ tokens (11).

Exit codes:
  0  — lint passed (or --no-lint)
  1  — forbidden classes found, or (with --strict) any warnings present
"""

import os
import pathlib
import re
import sys

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


def _check_forbidden_classes(used_classes, filename):
    """Rule 2: forbidden classes are hard errors."""
    forbidden = 0
    for cls in sorted(used_classes):
        if cls in FORBIDDEN_CLASSES:
            print(f'ERROR: forbidden class .{cls} in {filename}')
            forbidden += 1
    return forbidden


def _check_onclick_handlers(content, filename):
    """Rule 3: any onclick is forbidden; naming a FORBIDDEN_JS handler is a
    hard error, any other non-empty onclick is a warning."""
    warnings = []
    forbidden = 0
    for val in re.findall(r'onclick="([^"]*)"', content):
        val = val.strip()
        if not val:
            continue
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
    return warnings, forbidden


def _check_undefined_classes(used_classes, defined_classes, filename):
    """Rule 4: warn on undefined classes (not forbidden, just absent from
    styles.css). `language-*` tokens are owned by Prism (rule 7 vets the
    allow-list); skip them here so the styles.css check doesn't double-flag."""
    warnings = []
    for cls in sorted(used_classes):
        if cls.startswith('language-'):
            continue
        if cls not in FORBIDDEN_CLASSES and cls not in defined_classes:
            msg = f'WARN: class .{cls} used in {filename} not in styles.css'
            print(msg)
            warnings.append(msg)
    return warnings


def _check_undefined_css_vars(content, defined_css_vars, filename):
    """Rule 5: check undefined CSS variables."""
    warnings = []
    for var in sorted(extract_css_vars(content)):
        if var not in defined_css_vars:
            msg = f'WARN: undefined CSS var {var} in {filename}'
            print(msg)
            warnings.append(msg)
    return warnings


def _check_aria_describedby(content, filename):
    """Rule 6: aria-describedby targets must exist in the same file."""
    warnings = []
    for tip_id in re.findall(r'aria-describedby="([^"]*)"', content):
        if tip_id and not re.search(r'id="' + re.escape(tip_id) + r'"', content):
            msg = f'WARN: aria-describedby="{tip_id}" has no matching id in {filename}'
            print(msg)
            warnings.append(msg)
    return warnings


def _check_language_allowlist(content, filename):
    """Rule 7: check Prism language classes against allow-list."""
    warnings = []
    for lang in re.findall(r'class="language-([\w-]+)"', content):
        if lang not in ALLOWED_LANGUAGES:
            msg = f'WARN: language-{lang} not in allow-list in {filename}'
            print(msg)
            warnings.append(msg)
    return warnings


def _check_diagram_first(screen_blocks, filename):
    """Rule 8: inside each <section class="screen">, if a <pre class="mermaid">
    exists, it must be the first non-whitespace element inside
    <div class="screen__body">."""
    warnings = []
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
    return warnings


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

    forbidden += _check_forbidden_classes(used_classes, filename)

    onclick_warnings, onclick_forbidden = _check_onclick_handlers(content, filename)
    warnings.extend(onclick_warnings)
    forbidden += onclick_forbidden

    warnings.extend(_check_undefined_classes(used_classes, defined_classes, filename))
    warnings.extend(_check_undefined_css_vars(content, defined_css_vars, filename))
    warnings.extend(_check_aria_describedby(content, filename))
    warnings.extend(_check_language_allowlist(content, filename))

    screen_blocks = re.findall(
        r'<section class="screen">.*?</section>', content, re.S)
    warnings.extend(_check_diagram_first(screen_blocks, filename))

    # 9-11: readability rules, extracted to keep this function's branching
    # shallow (see _check_visual_elements / _check_paragraph_length /
    # _check_placeholders below).
    warnings.extend(_check_visual_elements(screen_blocks, filename))
    warnings.extend(_check_paragraph_length(screen_blocks, filename))
    warnings.extend(_check_placeholders(content, filename))

    return warnings, forbidden


def _check_visual_elements(screen_blocks, filename):
    """Rule 9: every screen should carry at least one visual primitive, not just text."""
    warnings = []
    visual_markers = ('class="mermaid"', 'data-translator', 'callout',
                       'step-cards', 'badge-list', 'icon-rows',
                       'quiz-container', '<pre', '<table')
    for screen_idx, screen in enumerate(screen_blocks, start=1):
        if not any(marker in screen for marker in visual_markers):
            msg = f'WARN: screen {screen_idx} of {filename} has no visual element'
            print(msg)
            warnings.append(msg)
    return warnings


def _check_paragraph_length(screen_blocks, filename):
    """Rule 10: flag paragraphs over 600 characters (character count, not
    words, so it works for CJK too)."""
    warnings = []
    for screen_idx, screen in enumerate(screen_blocks, start=1):
        for p_content in re.findall(r'<p[^>]*>(.*?)</p>', screen, re.S):
            stripped = re.sub(r'<[^>]+>', '', p_content)
            stripped = re.sub(r'\s+', ' ', stripped).strip()
            if len(stripped) > 600:
                msg = (f'WARN: paragraph over 600 characters in screen '
                       f'{screen_idx} of {filename}')
                print(msg)
                warnings.append(msg)
    return warnings


def _check_placeholders(content, filename):
    """Rule 11: flag any leftover __PLACEHOLDER__ token. Lowercase dunders
    such as __init__ in code are not flagged (uppercase-only)."""
    warnings = []
    for tok in sorted(set(re.findall(r'__[A-Z][A-Z0-9_]*__', content))):
        msg = f'WARN: unfilled placeholder {tok} in {filename}'
        print(msg)
        warnings.append(msg)
    return warnings


def _load_style_definitions(templates_dir):
    """Read styles.css and return (defined_classes, defined_css_vars)."""
    css_path = templates_dir / 'styles.css'
    if not css_path.exists():
        print(f'WARN: styles.css not found at {css_path}', file=sys.stderr)
        return set(), set()

    css_text = css_path.read_text(encoding='utf-8')
    defined_classes = extract_defined_classes(css_text)
    # Extract all --var-name tokens declared in :root (or anywhere in CSS)
    defined_css_vars = set(re.findall(r'(--[\w-]+)\s*:', css_text))
    return defined_classes, defined_css_vars


def _check_main_js_regression(templates_dir):
    """Check that FORBIDDEN_JS names are not defined in main.js (regression
    guard). Returns the forbidden count."""
    js_path = templates_dir / 'main.js'
    if not js_path.exists():
        print(f'WARN: main.js not found at {js_path}', file=sys.stderr)
        return 0

    js_text = js_path.read_text(encoding='utf-8')
    forbidden = 0
    for name in sorted(FORBIDDEN_JS):
        pattern = rf'\b(?:function\s+{name}|{name}\s*=|{name}\s*:)'
        if re.search(pattern, js_text):
            print(f'ERROR: forbidden JS handler {name} defined in templates/explain/main.js')
            forbidden += 1
    return forbidden


def _parse_args(argv):
    """Split argv into (fragment_paths, strict, no_lint)."""
    strict = '--strict' in argv
    no_lint = '--no-lint' in argv
    paths = [a for a in argv if a not in ('--strict', '--no-lint')]
    return paths, strict, no_lint


def main():
    paths, strict, no_lint = _parse_args(sys.argv[1:])

    if no_lint:
        print('lint: skipped (--no-lint)')
        sys.exit(0)

    if not paths:
        print('explain-lint.py: no fragment files provided', file=sys.stderr)
        sys.exit(0)

    # Resolve template paths relative to repo root (script may be called from
    # any working directory; we derive the root from this file's location).
    script_dir = pathlib.Path(__file__).resolve().parent  # scripts/lib/
    repo_root = script_dir.parent.parent                  # agent-flow/
    templates_dir = repo_root / 'templates' / 'explain'

    defined_classes, defined_css_vars = _load_style_definitions(templates_dir)

    total_warnings = []
    total_forbidden = _check_main_js_regression(templates_dir)

    for path in paths:
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
