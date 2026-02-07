#!/bin/bash
#
# Claude Code Plugin Reinstallation Script
# =========================================
# This script reinstalls all user-scope plugins to local project scope.
# Use when plugins show as "disabled" despite being installed.
#
# Usage:
#   ./scripts/reinstall-plugins.sh              # Install to local scope
#   ./scripts/reinstall-plugins.sh --enable-all # Just add enabledPlugins to settings
#   ./scripts/reinstall-plugins.sh --list       # List all plugins
#   ./scripts/reinstall-plugins.sh --dry-run    # Show commands without executing
#
# Created: 2026-02-03
#

set -euo pipefail

# Configuration
CLAUDE_HOME="${HOME}/.claude"
PLUGINS_DIR="${CLAUDE_HOME}/plugins"
INSTALLED_PLUGINS="${PLUGINS_DIR}/installed_plugins.json"
SETTINGS_FILE="${CLAUDE_HOME}/settings.json"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_SETTINGS="${PROJECT_DIR}/.claude/settings.local.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Arguments
MODE="${1:-install}"
DRY_RUN=false

if [[ "$MODE" == "--dry-run" ]]; then
    DRY_RUN=true
    MODE="install"
fi

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed. Install with: brew install jq"
        exit 1
    fi

    if ! command -v claude &> /dev/null; then
        log_error "claude CLI not found in PATH"
        exit 1
    fi

    if [[ ! -f "$INSTALLED_PLUGINS" ]]; then
        log_error "installed_plugins.json not found at $INSTALLED_PLUGINS"
        exit 1
    fi
}

# List all plugins
list_plugins() {
    log_info "Listing all installed plugins..."
    echo ""

    local plugins
    plugins=$(jq -r '.plugins | to_entries[] | "\(.key)\t\(.value[0].scope)\t\(.value[0].version)"' "$INSTALLED_PLUGINS" 2>/dev/null)

    printf "%-50s %-10s %s\n" "PLUGIN@MARKETPLACE" "SCOPE" "VERSION"
    printf "%-50s %-10s %s\n" "-----------------" "-----" "-------"

    local user_count=0
    local project_count=0
    local local_count=0

    while IFS=$'\t' read -r name scope version; do
        printf "%-50s %-10s %s\n" "$name" "$scope" "$version"
        case "$scope" in
            user) ((user_count++)) ;;
            project) ((project_count++)) ;;
            local) ((local_count++)) ;;
        esac
    done <<< "$plugins"

    echo ""
    log_info "Summary: ${user_count} user, ${project_count} project, ${local_count} local scope plugins"
}

# Generate enabledPlugins setting for all plugins
enable_all_plugins() {
    log_info "Generating enabledPlugins configuration..."

    # Extract all plugin names
    local plugins
    plugins=$(jq -r '.plugins | keys[]' "$INSTALLED_PLUGINS" 2>/dev/null)

    # Build enabledPlugins object
    local enabled_json="{"
    local first=true

    while read -r plugin; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            enabled_json+=","
        fi
        enabled_json+="\"${plugin}\": true"
    done <<< "$plugins"

    enabled_json+="}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would update settings.json with enabledPlugins:"
        echo "$enabled_json" | jq '.'
        return
    fi

    # Read current settings
    local current_settings
    if [[ -f "$SETTINGS_FILE" ]]; then
        current_settings=$(cat "$SETTINGS_FILE")
    else
        current_settings="{}"
    fi

    # Merge enabledPlugins into settings
    local new_settings
    new_settings=$(echo "$current_settings" | jq --argjson enabled "$enabled_json" '. + {enabledPlugins: $enabled}')

    # Backup and write
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    echo "$new_settings" > "$SETTINGS_FILE"

    log_success "Updated $SETTINGS_FILE with enabledPlugins for $(echo "$plugins" | wc -l | tr -d ' ') plugins"
    log_warn "Restart Claude Code for changes to take effect"
}

# Get priority plugins (most critical ones)
get_priority_plugins() {
    cat << 'EOF'
oh-my-claudecode@omc
superpowers@claude-plugins-official
claude-mem@thedotmack
swift-lsp@claude-plugins-official
typescript-lsp@claude-plugins-official
pyright-lsp@claude-plugins-official
rust-analyzer-lsp@claude-plugins-official
planning-with-files@planning-with-files
compound-engineering@every-marketplace
axiom@axiom-marketplace
swift-concurrency@swift-concurrency-agent-skill
iOS-APP-developer@daymade-skills
frontend-design@claude-plugins-official
code-review@claude-plugins-official
plugin-dev@claude-plugins-official
EOF
}

# Install plugins to local scope
install_local() {
    log_info "Installing plugins to local scope for project: $PROJECT_DIR"

    # Ensure .claude directory exists
    mkdir -p "${PROJECT_DIR}/.claude"

    # Get all user-scope plugins
    local plugins
    plugins=$(jq -r '.plugins | to_entries[] | select(.value[0].scope == "user") | .key' "$INSTALLED_PLUGINS" 2>/dev/null)

    local total
    total=$(echo "$plugins" | wc -l | tr -d ' ')
    local count=0
    local success=0
    local failed=0

    log_info "Found $total user-scope plugins to install"
    echo ""

    while read -r plugin; do
        ((count++))

        # Extract marketplace name
        local marketplace
        marketplace=$(echo "$plugin" | cut -d'@' -f2)
        local plugin_name
        plugin_name=$(echo "$plugin" | cut -d'@' -f1)

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[$count/$total] Would install: $plugin"
            continue
        fi

        echo -n "[$count/$total] Installing $plugin... "

        if claude plugin install "$plugin_name" --marketplace "$marketplace" --scope local 2>/dev/null; then
            echo -e "${GREEN}OK${NC}"
            ((success++))
        else
            echo -e "${RED}FAILED${NC}"
            ((failed++))
        fi

        # Small delay to avoid rate limiting
        sleep 0.2

    done <<< "$plugins"

    echo ""
    if [[ "$DRY_RUN" == "false" ]]; then
        log_success "Installation complete: $success succeeded, $failed failed"
        log_warn "Restart Claude Code for changes to take effect"
    fi
}

# Install priority plugins only
install_priority() {
    log_info "Installing priority plugins to local scope..."

    mkdir -p "${PROJECT_DIR}/.claude"

    local plugins
    plugins=$(get_priority_plugins)

    local total
    total=$(echo "$plugins" | wc -l | tr -d ' ')
    local count=0

    while read -r plugin; do
        [[ -z "$plugin" ]] && continue
        ((count++))

        local marketplace
        marketplace=$(echo "$plugin" | cut -d'@' -f2)
        local plugin_name
        plugin_name=$(echo "$plugin" | cut -d'@' -f1)

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[$count/$total] Would install: $plugin"
            continue
        fi

        echo -n "[$count/$total] Installing $plugin... "

        if claude plugin install "$plugin_name" --marketplace "$marketplace" --scope local 2>/dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FAILED${NC}"
        fi

        sleep 0.2

    done <<< "$plugins"

    echo ""
    log_success "Priority plugin installation complete"
}

# Generate commands for manual execution
generate_commands() {
    log_info "Generating installation commands..."
    echo ""
    echo "# Copy and paste these commands to install plugins:"
    echo ""

    local plugins
    plugins=$(jq -r '.plugins | to_entries[] | select(.value[0].scope == "user") | .key' "$INSTALLED_PLUGINS" 2>/dev/null)

    while read -r plugin; do
        local marketplace
        marketplace=$(echo "$plugin" | cut -d'@' -f2)
        local plugin_name
        plugin_name=$(echo "$plugin" | cut -d'@' -f1)

        echo "claude plugin install '$plugin_name' --marketplace '$marketplace' --scope local"
    done <<< "$plugins"
}

# Main
main() {
    check_prerequisites

    echo ""
    echo "========================================"
    echo "  Claude Code Plugin Reinstallation"
    echo "========================================"
    echo ""

    case "$MODE" in
        --list)
            list_plugins
            ;;
        --enable-all)
            enable_all_plugins
            ;;
        --generate)
            generate_commands
            ;;
        --priority)
            install_priority
            ;;
        install|--install)
            install_local
            ;;
        *)
            echo "Usage: $0 [--list|--enable-all|--generate|--priority|--dry-run]"
            echo ""
            echo "Options:"
            echo "  (no args)     Install all user-scope plugins to local scope"
            echo "  --list        List all installed plugins"
            echo "  --enable-all  Add enabledPlugins to settings.json (quick fix)"
            echo "  --generate    Generate installation commands for manual use"
            echo "  --priority    Install only priority/essential plugins"
            echo "  --dry-run     Show what would be done without executing"
            exit 1
            ;;
    esac
}

main "$@"
