#!/bin/bash
# Parse extension footer: 256 bytes metadata + 256 bytes signature

set -e

if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/common.sh"
fi

readonly FOOTER_SIZE=512
readonly SIGNATURE_SIZE=256
readonly METADATA_SIZE=256
readonly FIELD_SIZE=32

read_footer_field() {
    local extfile="$1" field_offset="$2"
    local filesize=$(get_file_size "$extfile")
    local offset=$((filesize - FOOTER_SIZE + field_offset))
    dd if="$extfile" bs=1 skip=$offset count=$FIELD_SIZE 2>/dev/null | tr -d '\0'
}

read_footer_bytes() {
    local extfile="$1" field_offset="$2" count="$3"
    local filesize=$(get_file_size "$extfile")
    local offset=$((filesize - FOOTER_SIZE + field_offset))
    dd if="$extfile" bs=1 skip=$offset count=$count 2>/dev/null
}

get_magic() { read_footer_field "$1" 0; }
get_platform() { read_footer_field "$1" 32; }
get_duckdb_version() { read_footer_field "$1" 64; }
get_extension_version() { read_footer_field "$1" 96; }
get_abi_type() { read_footer_field "$1" 128; }
get_signature() { read_footer_bytes "$1" $METADATA_SIZE $SIGNATURE_SIZE; }

has_signature() {
    local sig_hex=$(get_signature "$1" | xxd -p | tr -d '\n')
    local zeros=$(printf '%0512d' 0)
    [[ "$sig_hex" != "$zeros" ]]
}

get_signature_hex() { get_signature "$1" | xxd -p -c 256; }

parse_metadata() {
    local extfile="$1" format="${2:-text}"

    validate_extension "$extfile" || return $?

    local magic=$(get_magic "$extfile")
    local platform=$(get_platform "$extfile")
    local duckdb_version=$(get_duckdb_version "$extfile")
    local ext_version=$(get_extension_version "$extfile")
    local abi_type=$(get_abi_type "$extfile")
    local filesize=$(get_file_size "$extfile")
    local has_sig="false"
    has_signature "$extfile" && has_sig="true"

    if [[ "$format" == "json" ]]; then
        cat << EOF
{"file":"$extfile","size":$filesize,"magic":"$magic","platform":"$platform","duckdb_version":"$duckdb_version","extension_version":"$ext_version","abi_type":"$abi_type","has_signature":$has_sig}
EOF
    else
        echo "Extension: $extfile"
        echo "Size:      $filesize bytes"
        echo "Platform:  $platform"
        echo "DuckDB:    $duckdb_version"
        echo "ABI:       $abi_type"
        echo "Version:   $ext_version"
        echo "Signed:    $has_sig"
    fi
}

parse_footer_main() {
    local extfile="" format="text" field=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) format="json"; shift ;;
            --field) field="$2"; shift 2 ;;
            -h|--help)
                echo "Usage: parse_footer.sh [--json] [--field FIELD] <extension_file>"
                echo "Fields: magic, platform, duckdb_version, extension_version, abi_type, signature"
                exit 0 ;;
            -*) error "Unknown option: $1"; exit $EXIT_INVALID_ARGS ;;
            *) extfile="$1"; shift ;;
        esac
    done

    [[ -z "$extfile" ]] && { error "Extension file required"; exit $EXIT_INVALID_ARGS; }
    validate_file_exists "$extfile" "Extension file" || exit $EXIT_FILE_NOT_FOUND

    if [[ -n "$field" ]]; then
        case "$field" in
            magic) get_magic "$extfile" ;;
            platform) get_platform "$extfile" ;;
            duckdb_version) get_duckdb_version "$extfile" ;;
            extension_version) get_extension_version "$extfile" ;;
            abi_type) get_abi_type "$extfile" ;;
            signature) get_signature_hex "$extfile" ;;
            *) error "Unknown field: $field"; exit $EXIT_INVALID_ARGS ;;
        esac
    else
        parse_metadata "$extfile" "$format"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_footer_main "$@"
fi
