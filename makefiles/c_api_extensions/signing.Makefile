# Reusable makefile for signing C API based extensions
#
# Inputs (from base.Makefile):
#   EXTENSION_NAME         : name of the extension (lower case)
#   EXTENSION_BUILD_PATH   : build output path
#   EXTENSION_FILENAME     : extension filename with .duckdb_extension suffix
#
# Environment Variables:
#   DUCKDB_SIGN_KEY        : path to private key file (.pem) for signing
#   DUCKDB_SIGN_KEY_PUB    : path to public key file (.pub) for verification

.PHONY: sign_debug sign_release sign debug_signed release_signed verify_debug verify_release info_debug info_release keygen

#############################################
### Extension Signing Configuration
#############################################

# Path to signing scripts (relative to extension-ci-tools)
SIGNING_SCRIPTS_DIR ?= $(dir $(lastword $(MAKEFILE_LIST)))../../extension_signing

# Resolve to absolute path
SIGNING_SCRIPTS_DIR := $(abspath $(SIGNING_SCRIPTS_DIR))

#############################################
### Extension Signing Targets
#############################################

# Sign extension with private key
# Requires DUCKDB_SIGN_KEY environment variable
# Usage: make sign_debug DUCKDB_SIGN_KEY=/path/to/key.pem
# Or:    DUCKDB_SIGN_KEY=/path/to/key.pem make sign_debug

sign_debug: build_extension_with_metadata_debug
ifndef DUCKDB_SIGN_KEY
	$(error DUCKDB_SIGN_KEY is not set. Set it to the path of your private key file (.pem))
endif
	@echo "Signing debug extension..."
	$(SIGNING_SCRIPTS_DIR)/trexsql-sign.sh sign -k $(DUCKDB_SIGN_KEY) $(EXTENSION_BUILD_PATH)/debug/$(EXTENSION_FILENAME)
	@cp $(EXTENSION_BUILD_PATH)/debug/$(EXTENSION_FILENAME) $(EXTENSION_BUILD_PATH)/debug/extension/$(EXTENSION_NAME)/$(EXTENSION_FILENAME)

sign_release: build_extension_with_metadata_release
ifndef DUCKDB_SIGN_KEY
	$(error DUCKDB_SIGN_KEY is not set. Set it to the path of your private key file (.pem))
endif
	@echo "Signing release extension..."
	$(SIGNING_SCRIPTS_DIR)/trexsql-sign.sh sign -k $(DUCKDB_SIGN_KEY) $(EXTENSION_BUILD_PATH)/release/$(EXTENSION_FILENAME)
	@cp $(EXTENSION_BUILD_PATH)/release/$(EXTENSION_FILENAME) $(EXTENSION_BUILD_PATH)/release/extension/$(EXTENSION_NAME)/$(EXTENSION_FILENAME)

# Convenience targets that build and sign in one step
debug_signed: sign_debug
release_signed: sign_release

# Sign both debug and release
sign: sign_debug sign_release

#############################################
### Extension Verification Targets
#############################################

verify_debug:
ifndef DUCKDB_SIGN_KEY_PUB
	$(error DUCKDB_SIGN_KEY_PUB is not set. Set it to the path of your public key file (.pub))
endif
	$(SIGNING_SCRIPTS_DIR)/trexsql-sign.sh verify -k $(DUCKDB_SIGN_KEY_PUB) $(EXTENSION_BUILD_PATH)/debug/$(EXTENSION_FILENAME)

verify_release:
ifndef DUCKDB_SIGN_KEY_PUB
	$(error DUCKDB_SIGN_KEY_PUB is not set. Set it to the path of your public key file (.pub))
endif
	$(SIGNING_SCRIPTS_DIR)/trexsql-sign.sh verify -k $(DUCKDB_SIGN_KEY_PUB) $(EXTENSION_BUILD_PATH)/release/$(EXTENSION_FILENAME)

#############################################
### Extension Info Targets
#############################################

info_debug:
	$(SIGNING_SCRIPTS_DIR)/trexsql-sign.sh info $(EXTENSION_BUILD_PATH)/debug/$(EXTENSION_FILENAME)

info_release:
	$(SIGNING_SCRIPTS_DIR)/trexsql-sign.sh info $(EXTENSION_BUILD_PATH)/release/$(EXTENSION_FILENAME)

#############################################
### Key Generation
#############################################

# Generate signing key pair in the current directory
keygen:
	$(SIGNING_SCRIPTS_DIR)/trexsql-sign.sh keygen -o ./signing_key
