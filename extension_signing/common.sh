#!/bin/bash
# Shared utilities for extension signing

set -e

readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_ARGS=1
readonly EXIT_FILE_NOT_FOUND=2
readonly EXIT_INVALID_KEY=3
readonly EXIT_SIGNING_FAILED=4
readonly EXIT_INVALID_EXTENSION=5
readonly EXIT_KEY_GEN_FAILED=3
readonly EXIT_SIGNATURE_INVALID=10

# Extension footer constants
readonly FOOTER_SIZE=512
readonly SIGNATURE_SIZE=256
readonly METADATA_SIZE=256
readonly FIELD_SIZE=32
readonly CHUNK_SIZE=$((1024 * 1024))

# Metadata field offsets within the 512-byte footer
# Fields are written in order: unused(0,32,64), abi(96), ext_ver(128), duckdb_ver(160), platform(192), magic(224)
readonly OFFSET_ABI_TYPE=96
readonly OFFSET_EXT_VERSION=128
readonly OFFSET_DUCKDB_VERSION=160
readonly OFFSET_PLATFORM=192
readonly OFFSET_MAGIC=224
readonly OFFSET_SIGNATURE=256

if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' NC=''
fi

VERBOSE=0
QUIET=0

error() {
    [[ $QUIET -eq 0 ]] || return
    echo -e "${RED}Error: $1${NC}" >&2
    [[ -n "$2" ]] && echo "Details: $2" >&2
    [[ -n "$3" ]] && echo "Hint: $3" >&2
}

warn() { [[ $QUIET -eq 0 ]] && echo -e "${YELLOW}Warning: $1${NC}" >&2; }
success() { [[ $QUIET -eq 0 ]] && echo -e "${GREEN}$1${NC}"; }
info() { [[ $QUIET -eq 0 ]] && echo "$1"; }
verbose() { [[ $VERBOSE -eq 1 && $QUIET -eq 0 ]] && echo "[verbose] $1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

check_dependencies() {
    local missing=()
    command_exists openssl || missing+=("openssl")
    command_exists xxd || missing+=("xxd")
    [[ ${#missing[@]} -eq 0 ]] && return 0
    error "Missing dependencies: ${missing[*]}" "" "Install with: apt install ${missing[*]}"
    return 1
}

validate_file_exists() {
    [[ -f "$1" ]] && return 0
    error "${2:-File} not found" "$1 does not exist"
    return 1
}

validate_public_key() {
    validate_file_exists "$1" "Public key file" || return $EXIT_FILE_NOT_FOUND
    grep -q "^-----BEGIN PUBLIC KEY-----" "$1" || {
        error "Invalid public key format" "$1" "Expected PEM format"
        return $EXIT_INVALID_KEY
    }
    openssl rsa -pubin -in "$1" -noout 2>/dev/null || {
        error "Invalid RSA public key" "$1" "Run: trexsql-sign.sh keygen"
        return $EXIT_INVALID_KEY
    }
}

validate_private_key() {
    validate_file_exists "$1" "Private key file" || return $EXIT_FILE_NOT_FOUND
    grep -qE "^-----BEGIN (RSA )?PRIVATE KEY-----" "$1" || {
        error "Invalid private key format" "$1" "Expected PEM format"
        return $EXIT_INVALID_KEY
    }
    openssl rsa -in "$1" -noout 2>/dev/null || {
        error "Invalid RSA private key" "$1" "Run: trexsql-sign.sh keygen"
        return $EXIT_INVALID_KEY
    }
}

validate_extension() {
    validate_file_exists "$1" "Extension file" || return $EXIT_FILE_NOT_FOUND
    local filesize
    filesize=$(get_file_size "$1")
    [[ $filesize -lt 512 ]] && {
        error "Invalid extension" "$1 too small" "Expected >= 512 bytes"
        return $EXIT_INVALID_EXTENSION
    }
    # Check magic byte '4' (0x34) at correct offset within footer
    local magic=$(dd if="$1" bs=1 skip=$((filesize - FOOTER_SIZE + OFFSET_MAGIC)) count=1 2>/dev/null | xxd -p)
    [[ "$magic" == "34" ]] || {
        error "Invalid extension" "Magic mismatch (got: $magic)" "Not a valid .duckdb_extension"
        return $EXIT_INVALID_EXTENSION
    }
}

get_file_size() {
    stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null
}
