#!/bin/bash
# Two-level SHA256 hash: hash 1MB chunks, then hash the concatenated hashes

set -e

if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/common.sh"
fi

readonly CHUNK_SIZE=$((1024 * 1024))
readonly SIGNATURE_SIZE=256

# Compute two-level hash (excludes last 256 bytes for signature)
compute_extension_hash() {
    local extfile="$1" outfile="${2:-}"

    validate_file_exists "$extfile" "Extension file" || return $EXIT_FILE_NOT_FOUND

    local filesize=$(get_file_size "$extfile")
    local content_size=$((filesize - SIGNATURE_SIZE))

    [[ $content_size -le 0 ]] && {
        error "File too small" "" "Expected > $SIGNATURE_SIZE bytes"
        return $EXIT_INVALID_EXTENSION
    }

    local tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    local hash_concat="${tmpdir}/hash_concat"
    : > "$hash_concat"

    local offset=0
    while [[ $offset -lt $content_size ]]; do
        local chunk_bytes=$CHUNK_SIZE
        local remaining=$((content_size - offset))
        [[ $remaining -lt $CHUNK_SIZE ]] && chunk_bytes=$remaining

        dd if="$extfile" bs=1 skip=$offset count=$chunk_bytes 2>/dev/null | \
            openssl dgst -binary -sha256 >> "$hash_concat"

        offset=$((offset + chunk_bytes))
    done

    if [[ -n "$outfile" ]]; then
        openssl dgst -binary -sha256 "$hash_concat" > "$outfile"
    else
        openssl dgst -binary -sha256 "$hash_concat" | xxd -p -c 32
    fi
}

hash_main() {
    local extfile="" outfile=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output) outfile="$2"; shift 2 ;;
            -h|--help)
                echo "Usage: hash.sh [-o FILE] <extension_file>"
                echo "Compute two-level SHA256 hash of extension"
                exit 0 ;;
            -*) error "Unknown option: $1"; exit $EXIT_INVALID_ARGS ;;
            *) extfile="$1"; shift ;;
        esac
    done

    [[ -z "$extfile" ]] && { error "Extension file required"; exit $EXIT_INVALID_ARGS; }
    compute_extension_hash "$extfile" "$outfile"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    hash_main "$@"
fi
