#!/bin/bash
set -euo pipefail

if [ -z "${APT_GPG_PRIVATE_KEY:-}" ]; then
  echo "Error: APT_GPG_PRIVATE_KEY environment variable is not set."
  exit 1
fi

echo "Importing GPG private key..."
echo "$APT_GPG_PRIVATE_KEY" | gpg --batch --import

echo "GPG key imported successfully."
