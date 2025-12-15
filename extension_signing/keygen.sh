#!/bin/bash
# Generate RSA-2048 key pair for extension signing

set -e

if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/common.sh"
fi

keygen_help() {
    cat << EOF
Usage: trexsql-sign.sh keygen [OPTIONS]

Generate RSA-2048 key pair.

Options:
  -o, --output PATH   Output path (default: ./signing_key)
  -f, --force         Overwrite existing files
  -h, --help          Show help

Output:
  <path>.pem   Private key (keep secret!)
  <path>.pub   Public key
EOF
}

generate_keypair() {
    local output_base="$1" force="${2:-0}"
    local private_key="${output_base}.pem"
    local public_key="${output_base}.pub"

    [[ -f "$private_key" && $force -eq 0 ]] && {
        error "File exists: $private_key" "" "Use --force to overwrite"
        return 2
    }

    local output_dir=$(dirname "$output_base")
    [[ -d "$output_dir" ]] || mkdir -p "$output_dir"

    info "Generating RSA-2048 key pair..."

    openssl genrsa -out "$private_key" 2048 2>/dev/null || {
        error "Key generation failed"
        return $EXIT_KEY_GEN_FAILED
    }
    chmod 600 "$private_key"

    openssl rsa -in "$private_key" -pubout -out "$public_key" 2>/dev/null || {
        error "Public key extraction failed"
        rm -f "$private_key"
        return $EXIT_KEY_GEN_FAILED
    }

    success "Generated key pair:"
    info "  Private: $private_key"
    info "  Public:  $public_key"
    warn "Keep private key secure!"
}

keygen_main() {
    local output_base="./signing_key" force=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output) output_base="$2"; shift 2 ;;
            -f|--force) force=1; shift ;;
            -h|--help) keygen_help; exit 0 ;;
            -q|--quiet) QUIET=1; shift ;;
            -v|--verbose) VERBOSE=1; shift ;;
            -*) error "Unknown option: $1"; exit $EXIT_INVALID_ARGS ;;
            *) output_base="$1"; shift ;;
        esac
    done

    generate_keypair "$output_base" "$force"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    keygen_main "$@"
fi
