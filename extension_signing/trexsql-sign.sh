#!/bin/bash
# TrexSQL extension signing tool

set -e

readonly VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common.sh"

show_version() {
    echo "trexsql-sign.sh version $VERSION"
}

show_help() {
    cat << EOF
TrexSQL Extension Signing Tool v$VERSION

Usage: trexsql-sign.sh <command> [options]

Commands:
  keygen    Generate RSA-2048 key pair
  sign      Sign extension with private key
  verify    Verify extension signature
  info      Display extension metadata

Options:
  -h, --help      Show help
  -V, --version   Show version
  -q, --quiet     Suppress output
  -v, --verbose   Verbose output

Examples:
  trexsql-sign.sh keygen -o ~/my_signing_key
  trexsql-sign.sh sign -k ~/my_signing_key.pem extension.duckdb_extension
  trexsql-sign.sh verify -k ~/my_signing_key.pub extension.duckdb_extension
EOF
}

main() {
    case "${1:-}" in
        -h|--help) show_help; exit 0 ;;
        -V|--version) show_version; exit 0 ;;
    esac

    local command="${1:-}"
    [[ -z "$command" ]] && { error "No command specified" "" "Run 'trexsql-sign.sh --help'"; exit $EXIT_INVALID_ARGS; }
    shift

    check_dependencies || exit $EXIT_INVALID_ARGS

    case "$command" in
        keygen) source "${SCRIPT_DIR}/keygen.sh"; keygen_main "$@" ;;
        sign) source "${SCRIPT_DIR}/sign.sh"; sign_main "$@" ;;
        verify) source "${SCRIPT_DIR}/verify.sh"; verify_main "$@" ;;
        info) source "${SCRIPT_DIR}/info.sh"; info_main "$@" ;;
        *) error "Unknown command: $command" "" "Run 'trexsql-sign.sh --help'"; exit $EXIT_INVALID_ARGS ;;
    esac
}

main "$@"
