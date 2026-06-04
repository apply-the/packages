#!/bin/sh
set -e

KEY_URL="https://apply-the.github.io/packages/apt/gpg.key"
REPO_URL="https://apply-the.github.io/packages/apt"
KEYRING_PATH="/usr/share/keyrings/apply-the-archive-keyring.gpg"
LIST_PATH="/etc/apt/sources.list.d/apply-the.list"

echo "Setting up Apply The APT repository..."

# Download and install the public key
curl -fsSL "$KEY_URL" | sudo gpg --dearmor -o "$KEYRING_PATH"

# Add the repository to sources.list.d
echo "deb [signed-by=$KEYRING_PATH] $REPO_URL stable main" | sudo tee "$LIST_PATH" > /dev/null

echo "Updating APT..."
sudo apt update

# Install packages if arguments are provided
if [ $# -gt 0 ]; then
  echo "Installing packages: $@"
  sudo apt install -y "$@"
fi

echo "Apply The repository configured successfully."
