#!/bin/bash
# Verify extension signature against public key

set -e

if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/common.sh"
fi
source "${SCRIPT_DIR}/hash.sh"
source "${SCRIPT_DIR}/parse_footer.sh"

verify_help() {
    cat << EOF
Usage: trexsql-sign.sh verify [OPTIONS] <extension_file>

Verify extension signature.

Options:
  -k, --key FILE    Public key (PEM format) [required]
  -q, --quiet       Suppress output
  -v, --verbose     Verbose output
  -h, --help        Show help

Exit codes:
  0   Signature valid
  10  Signature invalid
EOF
}

verify_extension() {
    local extfile="$1" keyfile="$2"

    validate_extension "$extfile" || return $?
    validate_public_key "$keyfile" || return $?

    has_signature "$extfile" || {
        error "Extension not signed" "" "Sign with: trexsql-sign.sh sign -k <key.pem> <extension>"
        return $EXIT_SIGNATURE_INVALID
    }

    local tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    local hash_file="${tmpdir}/hash.bin"
    local sig_file="${tmpdir}/signature.bin"

    compute_extension_hash "$extfile" "$hash_file" || return $EXIT_INVALID_EXTENSION
    get_signature "$extfile" > "$sig_file"

    if openssl pkeyutl -verify -in "$hash_file" -sigfile "$sig_file" -pubin -inkey "$keyfile" -pkeyopt digest:sha256 2>/dev/null; then
        success "Signature valid"
        info "  Platform: $(get_platform "$extfile")"
        return 0
    else
        error "Signature invalid"
        return $EXIT_SIGNATURE_INVALID
    fi
}

verify_main() {
    local extfile="" keyfile=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -k|--key) keyfile="$2"; shift 2 ;;
            -h|--help) verify_help; exit 0 ;;
            -q|--quiet) QUIET=1; shift ;;
            -v|--verbose) VERBOSE=1; shift ;;
            -*) error "Unknown option: $1"; exit $EXIT_INVALID_ARGS ;;
            *) extfile="$1"; shift ;;
        esac
    done

    [[ -z "$extfile" ]] && { error "Extension file required"; exit $EXIT_INVALID_ARGS; }
    [[ -z "$keyfile" ]] && { error "Public key required (-k)"; exit $EXIT_INVALID_ARGS; }

    verify_extension "$extfile" "$keyfile"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    verify_main "$@"
fi
