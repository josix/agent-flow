#!/usr/bin/env bash
#
# bump-version.sh - Bump semantic version, update plugin files, and generate changelog
#
set -euo pipefail

# Trap cleanup for temp files
TEMP_FILES=()
cleanup() {
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        for temp_file in "${TEMP_FILES[@]}"; do
            [[ -f "$temp_file" ]] && rm -f "$temp_file"
        done
    fi
}
trap cleanup EXIT

# Resolve plugin root directory
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Default variables
BUMP_TYPE="patch"
COMMIT_CHANGES=false
DRY_RUN=false

# Print usage information
print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Bump semantic version, update plugin files, and generate changelog entries.

OPTIONS:
    --major         Bump major version (X+1.0.0)
    --minor         Bump minor version (X.Y+1.0)
    --patch         Bump patch version (X.Y.Z+1) [DEFAULT]
    --commit        Git commit and tag after bumping
    --dry-run       Show what would happen without modifying files
    -h, --help      Show this help message

EXAMPLES:
    $(basename "$0") --patch                 # Bump patch version (1.0.0 -> 1.0.1)
    $(basename "$0") --minor --commit        # Bump minor and commit (1.0.0 -> 1.1.0)
    $(basename "$0") --major --dry-run       # Preview major bump (1.0.0 -> 2.0.0)

FILES UPDATED:
    - .claude-plugin/plugin.json             # "version" field
    - docs/index.md                          # **Version** line
    - CHANGELOG.md                           # New version section

CHANGELOG GENERATION:
    - Finds commits since last tag (or all commits if no tags)
    - Categorizes by conventional commit type (feat, fix, other)
    - Generates dated changelog section with grouped changes
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --major)
            BUMP_TYPE="major"
            shift
            ;;
        --minor)
            BUMP_TYPE="minor"
            shift
            ;;
        --patch)
            BUMP_TYPE="patch"
            shift
            ;;
        --commit)
            COMMIT_CHANGES=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            print_usage
            exit 1
            ;;
    esac
done

# Dependency checks
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed" >&2
    echo "Install with: brew install jq" >&2
    exit 1
fi

if ! command -v git &>/dev/null; then
    echo "Error: git is required but not installed" >&2
    exit 1
fi

# Read current version from plugin.json
PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
if [[ ! -f "$PLUGIN_JSON" ]]; then
    echo "Error: plugin.json not found at $PLUGIN_JSON" >&2
    exit 1
fi

CURRENT_VERSION=$(jq -r '.version' "$PLUGIN_JSON")
if [[ -z "$CURRENT_VERSION" || "$CURRENT_VERSION" == "null" ]]; then
    echo "Error: Could not read version from plugin.json" >&2
    exit 1
fi

# Validate version format (X.Y.Z)
if ! [[ "$CURRENT_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "Error: Invalid version format: $CURRENT_VERSION (expected X.Y.Z)" >&2
    exit 1
fi

# Split version components
MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"

# Compute new version based on bump type
case "$BUMP_TYPE" in
    major)
        NEW_VERSION="$((MAJOR + 1)).0.0"
        ;;
    minor)
        NEW_VERSION="$MAJOR.$((MINOR + 1)).0"
        ;;
    patch)
        NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
        ;;
esac

echo "Version bump: $CURRENT_VERSION -> $NEW_VERSION ($BUMP_TYPE)"

# Dry-run gate
if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo "DRY RUN - No files will be modified"
    echo ""
    echo "Would update:"
    echo "  - $PLUGIN_JSON"
    echo "  - $PLUGIN_ROOT/docs/index.md"
    echo "  - $PLUGIN_ROOT/CHANGELOG.md"
    if [[ "$COMMIT_CHANGES" == true ]]; then
        echo ""
        echo "Would create git commit and tag: v$NEW_VERSION"
    fi
    exit 0
fi

# Update plugin.json using jq + temp file (atomic write)
echo "Updating $PLUGIN_JSON..."
TEMP_PLUGIN_JSON=$(mktemp)
TEMP_FILES+=("$TEMP_PLUGIN_JSON")
jq --arg version "$NEW_VERSION" '.version = $version' "$PLUGIN_JSON" > "$TEMP_PLUGIN_JSON"
mv "$TEMP_PLUGIN_JSON" "$PLUGIN_JSON"

# Update docs/index.md using temp file approach
INDEX_MD="$PLUGIN_ROOT/docs/index.md"
if [[ -f "$INDEX_MD" ]]; then
    echo "Updating $INDEX_MD..."
    TEMP_INDEX_MD=$(mktemp)
    TEMP_FILES+=("$TEMP_INDEX_MD")
    sed "s/^\*\*Version\*\*: .*/\*\*Version\*\*: $NEW_VERSION/" "$INDEX_MD" > "$TEMP_INDEX_MD"
    mv "$TEMP_INDEX_MD" "$INDEX_MD"
else
    echo "Warning: docs/index.md not found, skipping" >&2
fi

# Generate changelog entry from git log
echo "Generating changelog entry..."

# Find last git tag
LAST_TAG=$(git -C "$PLUGIN_ROOT" tag --sort=-v:refversion | head -n1 || echo "")

# Get commits since last tag (or all commits if no tags)
if [[ -z "$LAST_TAG" ]]; then
    COMMITS=$(git -C "$PLUGIN_ROOT" log --format="%s" 2>/dev/null || echo "")
else
    COMMITS=$(git -C "$PLUGIN_ROOT" log --format="%s" "$LAST_TAG..HEAD" 2>/dev/null || echo "")
fi

# Categorize commits
ADDED_ITEMS=()
FIXED_ITEMS=()
CHANGED_ITEMS=()

while IFS= read -r commit_msg; do
    [[ -z "$commit_msg" ]] && continue

    # Check for conventional commit prefixes
    if [[ "$commit_msg" =~ ^feat:\ (.+)$ ]] || [[ "$commit_msg" =~ ^feat\(.+\):\ (.+)$ ]]; then
        ADDED_ITEMS+=("${BASH_REMATCH[1]}")
    elif [[ "$commit_msg" =~ ^fix:\ (.+)$ ]] || [[ "$commit_msg" =~ ^fix\(.+\):\ (.+)$ ]]; then
        FIXED_ITEMS+=("${BASH_REMATCH[1]}")
    else
        # Strip any conventional commit prefix for "Changed" category
        if [[ "$commit_msg" =~ ^[a-z]+(\(.+\))?:\ (.+)$ ]]; then
            CHANGED_ITEMS+=("${BASH_REMATCH[2]}")
        else
            CHANGED_ITEMS+=("$commit_msg")
        fi
    fi
done <<< "$COMMITS"

# Build changelog section
CHANGELOG_DATE=$(date +%Y-%m-%d)
CHANGELOG_SECTION="## [$NEW_VERSION] - $CHANGELOG_DATE"

# Add categorized items
if [[ ${#ADDED_ITEMS[@]} -gt 0 ]]; then
    CHANGELOG_SECTION+="\n\n### Added\n"
    for item in "${ADDED_ITEMS[@]}"; do
        CHANGELOG_SECTION+="\n- $item"
    done
fi

if [[ ${#FIXED_ITEMS[@]} -gt 0 ]]; then
    CHANGELOG_SECTION+="\n\n### Fixed\n"
    for item in "${FIXED_ITEMS[@]}"; do
        CHANGELOG_SECTION+="\n- $item"
    done
fi

if [[ ${#CHANGED_ITEMS[@]} -gt 0 ]]; then
    CHANGELOG_SECTION+="\n\n### Changed\n"
    for item in "${CHANGED_ITEMS[@]}"; do
        CHANGELOG_SECTION+="\n- $item"
    done
fi

# Handle CHANGELOG.md creation or update
CHANGELOG_MD="$PLUGIN_ROOT/CHANGELOG.md"

if [[ ! -f "$CHANGELOG_MD" ]]; then
    # Create new CHANGELOG.md with standard header
    echo "Creating $CHANGELOG_MD..."
    cat > "$CHANGELOG_MD" <<'CHANGELOG_HEADER'
# Changelog

All notable changes to the Agent Flow plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

CHANGELOG_HEADER
    echo -e "\n$CHANGELOG_SECTION" >> "$CHANGELOG_MD"
else
    # Prepend new section after the header (after line 6)
    echo "Updating $CHANGELOG_MD..."
    TEMP_CHANGELOG=$(mktemp)
    TEMP_FILES+=("$TEMP_CHANGELOG")

    # Read first 6 lines (header), insert new section, then append rest
    head -n 6 "$CHANGELOG_MD" > "$TEMP_CHANGELOG"
    echo "" >> "$TEMP_CHANGELOG"
    echo -e "$CHANGELOG_SECTION" >> "$TEMP_CHANGELOG"
    echo "" >> "$TEMP_CHANGELOG"
    tail -n +7 "$CHANGELOG_MD" >> "$TEMP_CHANGELOG"

    mv "$TEMP_CHANGELOG" "$CHANGELOG_MD"
fi

# Optional commit + tag
if [[ "$COMMIT_CHANGES" == true ]]; then
    echo "Creating git commit and tag..."

    FILES_TO_ADD=("$PLUGIN_JSON" "$CHANGELOG_MD")
    COMMIT_DETAILS="- Update plugin.json version\n- Generate changelog entry"
    if [[ -f "$INDEX_MD" ]]; then
        FILES_TO_ADD+=("$INDEX_MD")
        COMMIT_DETAILS="- Update plugin.json version\n- Update docs/index.md version\n- Generate changelog entry"
    fi
    git -C "$PLUGIN_ROOT" add "${FILES_TO_ADD[@]}"

    git -C "$PLUGIN_ROOT" commit -m "$(cat <<EOF
chore: bump version to $NEW_VERSION

$(echo -e "$COMMIT_DETAILS")

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"

    git -C "$PLUGIN_ROOT" tag "v$NEW_VERSION"

    echo "Created commit and tag: v$NEW_VERSION"
fi

# Print summary
echo ""
echo "Summary:"
echo "  Version: $CURRENT_VERSION -> $NEW_VERSION"
echo "  Files updated:"
echo "    - .claude-plugin/plugin.json"
[[ -f "$INDEX_MD" ]] && echo "    - docs/index.md"
echo "    - CHANGELOG.md"
if [[ "$COMMIT_CHANGES" == true ]]; then
    echo "  Git: Committed and tagged as v$NEW_VERSION"
fi
echo ""
echo "Version bump complete!"
