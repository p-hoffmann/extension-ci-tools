#!/bin/bash
# Write 256-byte signature to extension footer

set -e

if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/common.sh"
fi

readonly SIGNATURE_SIZE=256

write_signature() {
    local extfile="$1" sigfile="$2"

    validate_file_exists "$extfile" "Extension file" || return $EXIT_FILE_NOT_FOUND
    validate_file_exists "$sigfile" "Signature file" || return $EXIT_FILE_NOT_FOUND

    local sigsize=$(get_file_size "$sigfile")
    [[ $sigsize -eq $SIGNATURE_SIZE ]] || {
        error "Invalid signature size" "Expected $SIGNATURE_SIZE, got $sigsize"
        return $EXIT_INVALID_EXTENSION
    }

    local filesize=$(get_file_size "$extfile")
    local sig_offset=$((filesize - SIGNATURE_SIZE))

    dd if="$sigfile" of="$extfile" bs=1 seek=$sig_offset conv=notrunc 2>/dev/null
}

write_signature_stdin() {
    local extfile="$1"
    validate_file_exists "$extfile" "Extension file" || return $EXIT_FILE_NOT_FOUND

    local tmpfile=$(mktemp)
    trap "rm -f '$tmpfile'" EXIT

    dd of="$tmpfile" bs=$SIGNATURE_SIZE count=1 2>/dev/null
    local sigsize=$(get_file_size "$tmpfile")
    [[ $sigsize -eq $SIGNATURE_SIZE ]] || {
        error "Invalid signature from stdin" "Expected $SIGNATURE_SIZE bytes"
        return $EXIT_INVALID_EXTENSION
    }

    write_signature "$extfile" "$tmpfile"
}

clear_signature() {
    local extfile="$1"
    validate_file_exists "$extfile" "Extension file" || return $EXIT_FILE_NOT_FOUND

    local filesize=$(get_file_size "$extfile")
    local sig_offset=$((filesize - SIGNATURE_SIZE))
    dd if=/dev/zero of="$extfile" bs=1 seek=$sig_offset count=$SIGNATURE_SIZE conv=notrunc 2>/dev/null
}

write_footer_main() {
    local extfile="" sigfile="" output="" clear=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--signature) sigfile="$2"; shift 2 ;;
            -o|--output) output="$2"; shift 2 ;;
            --clear) clear=1; shift ;;
            --stdin) sigfile="-"; shift ;;
            -h|--help)
                echo "Usage: write_footer.sh [-s FILE|--stdin|--clear] [-o OUTPUT] <extension_file>"
                exit 0 ;;
            -*) error "Unknown option: $1"; exit $EXIT_INVALID_ARGS ;;
            *) extfile="$1"; shift ;;
        esac
    done

    [[ -z "$extfile" ]] && { error "Extension file required"; exit $EXIT_INVALID_ARGS; }

    if [[ $clear -eq 1 ]]; then
        [[ -n "$output" ]] && cp "$extfile" "$output" && extfile="$output"
        clear_signature "$extfile"
    elif [[ -n "$sigfile" ]]; then
        [[ -n "$output" ]] && cp "$extfile" "$output" && extfile="$output"
        if [[ "$sigfile" == "-" ]]; then
            write_signature_stdin "$extfile"
        else
            write_signature "$extfile" "$sigfile"
        fi
    else
        error "Specify -s/--signature, --stdin, or --clear"
        exit $EXIT_INVALID_ARGS
    fi

    info "Done"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    write_footer_main "$@"
fi
