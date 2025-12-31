#!/bin/bash
# Sign .trex extensions if DUCKDB_EXTENSION_SIGNING_KEY is set
# Usage: source this script or call it at the end of build.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sign_extensions() {
    local search_dir="${1:-.}"

    if [[ -z "$DUCKDB_EXTENSION_SIGNING_KEY" ]]; then
        echo "DUCKDB_EXTENSION_SIGNING_KEY not set, skipping signing"
        return 0
    fi

    echo "Signing extensions..."
    local key_file=$(mktemp)
    echo "$DUCKDB_EXTENSION_SIGNING_KEY" > "$key_file"
    chmod 600 "$key_file"

    find "$search_dir" -maxdepth 1 \( -name "*.duckdb_extension" -o -name "*.trex" \) -type f | while read ext; do
        echo "Signing: $ext"
        "$SCRIPT_DIR/trexsql-sign.sh" sign -k "$key_file" "$ext"
    done

    rm -f "$key_file"
    echo "Signing complete"
}

# If script is executed directly (not sourced), run sign_extensions
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    sign_extensions "$@"
fi
