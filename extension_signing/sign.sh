#!/bin/bash
# Sign extension with private key using two-level hash algorithm

set -e

if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/common.sh"
fi
source "${SCRIPT_DIR}/hash.sh"
source "${SCRIPT_DIR}/parse_footer.sh"
source "${SCRIPT_DIR}/write_footer.sh"

sign_help() {
    cat << EOF
Usage: trexsql-sign.sh sign [OPTIONS] <extension_file>

Sign extension with private key.

Options:
  -k, --key FILE    Private key (PEM format) [required]
  -o, --output FILE Output path (default: in-place)
  -q, --quiet       Suppress output
  -v, --verbose     Verbose output
  -h, --help        Show help

Environment:
  DUCKDB_SIGN_KEY   Default private key path
EOF
}

sign_extension() {
    local extfile="$1" keyfile="$2" outfile="${3:-$1}"

    validate_extension "$extfile" || return $?
    validate_private_key "$keyfile" || return $?

    local tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    local hash_file="${tmpdir}/hash.bin"
    local sig_file="${tmpdir}/signature.bin"

    info "Computing extension hash..."
    compute_extension_hash "$extfile" "$hash_file" || {
        error "Failed to compute hash"
        return $EXIT_SIGNING_FAILED
    }

    info "Signing..."
    openssl pkeyutl -sign -in "$hash_file" -inkey "$keyfile" -out "$sig_file" -pkeyopt digest:sha256 2>/dev/null || {
        error "Signing failed" "OpenSSL error" "Verify key is RSA-2048"
        return $EXIT_SIGNING_FAILED
    }

    local sigsize=$(get_file_size "$sig_file")
    [[ $sigsize -eq 256 ]] || {
        error "Invalid signature size" "Got $sigsize bytes, expected 256" "Key must be RSA-2048"
        return $EXIT_SIGNING_FAILED
    }

    [[ "$outfile" != "$extfile" ]] && cp "$extfile" "$outfile"
    write_signature "$outfile" "$sig_file" || {
        error "Failed to write signature"
        return $EXIT_SIGNING_FAILED
    }

    success "Extension signed successfully"
    info "  Output: $outfile"
    info "  Platform: $(get_platform "$outfile")"
}

sign_main() {
    local extfile="" keyfile="${DUCKDB_SIGN_KEY:-}" outfile=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -k|--key) keyfile="$2"; shift 2 ;;
            -o|--output) outfile="$2"; shift 2 ;;
            -h|--help) sign_help; exit 0 ;;
            -q|--quiet) QUIET=1; shift ;;
            -v|--verbose) VERBOSE=1; shift ;;
            -*) error "Unknown option: $1"; exit $EXIT_INVALID_ARGS ;;
            *) extfile="$1"; shift ;;
        esac
    done

    [[ -z "$extfile" ]] && { error "Extension file required"; exit $EXIT_INVALID_ARGS; }
    [[ -z "$keyfile" ]] && { error "Private key required (-k or DUCKDB_SIGN_KEY)"; exit $EXIT_INVALID_ARGS; }

    sign_extension "$extfile" "$keyfile" "${outfile:-$extfile}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    sign_main "$@"
fi
