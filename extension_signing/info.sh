#!/bin/bash
# Display extension metadata and signature status

set -e

if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/common.sh"
fi
source "${SCRIPT_DIR}/parse_footer.sh"

info_help() {
    cat << EOF
Usage: trexsql-sign.sh info [OPTIONS] <extension_file>

Display extension metadata.

Options:
  --json      JSON output
  -h, --help  Show help
EOF
}

info_main() {
    local extfile="" format="text"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) format="json"; shift ;;
            -h|--help) info_help; exit 0 ;;
            -q|--quiet) QUIET=1; shift ;;
            -v|--verbose) VERBOSE=1; shift ;;
            -*) error "Unknown option: $1"; exit $EXIT_INVALID_ARGS ;;
            *) extfile="$1"; shift ;;
        esac
    done

    [[ -z "$extfile" ]] && { error "Extension file required"; exit $EXIT_INVALID_ARGS; }

    parse_metadata "$extfile" "$format"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    info_main "$@"
fi
