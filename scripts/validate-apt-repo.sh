#!/bin/bash
set -euo pipefail

# Ensure we are in the repository root
cd "$(dirname "$0")/.."

echo "Validating APT repository structure..."

has_errors=0

# 1. Expected directories exist
dirs=(
  "apt/pool/main/b/boundline"
  "apt/pool/main/c/canon"
  "apt/dists/stable/main/binary-amd64"
  "apt/dists/stable/main/binary-arm64"
)

for dir in "${dirs[@]}"; do
  if [ ! -d "$dir" ]; then
    echo "Error: Directory $dir is missing."
    has_errors=1
  fi
done

# Check if we have .deb files (release mode)
has_debs=0
if find apt/pool -name "*.deb" | grep -q .; then
  has_debs=1
fi

if [ "$has_debs" -eq 1 ]; then
  echo "Mode: RELEASE (packages found)"
else
  echo "Mode: BOOTSTRAP (no packages found)"
fi

# 2. apt/gpg.key exists
if [ ! -f "apt/gpg.key" ]; then
  if [ "$has_debs" -eq 1 ]; then
    echo "Error: apt/gpg.key is missing but packages are present."
    has_errors=1
  else
    echo "Warning: apt/gpg.key is missing (acceptable in bootstrap mode)."
  fi
fi

# 3. Package metadata exists when .deb files are present
if [ "$has_debs" -eq 1 ]; then
  # Packages.gz exists for each architecture
  for arch in amd64 arm64; do
    if [ ! -f "apt/dists/stable/main/binary-${arch}/Packages.gz" ]; then
      echo "Error: apt/dists/stable/main/binary-${arch}/Packages.gz is missing."
      has_errors=1
    fi
  done
  
  # Release, Release.gpg, and InRelease exist
  for file in Release Release.gpg InRelease; do
    if [ ! -f "apt/dists/stable/$file" ]; then
      echo "Error: apt/dists/stable/$file is missing."
      has_errors=1
    fi
  done
else
  echo "Info: Skipping metadata checks since no .deb files are present."
fi

# 4. No private key files are committed
if find . -name "apt-repo-private.asc" | grep -q .; then
  echo "Error: Private key file 'apt-repo-private.asc' found in the repository."
  has_errors=1
fi

# Extra check for any typical private key patterns
if grep -r "BEGIN PGP PRIVATE KEY"" BLOCK" apt/ scripts/ .github/ install.sh README.md 2>/dev/null; then
  echo "Error: PGP private key material found committed in files."
  has_errors=1
fi

# 5. install.sh uses signed-by and does not use apt-key
if grep -q "apt-key" install.sh; then
  echo "Error: install.sh uses deprecated apt-key."
  has_errors=1
fi

if ! grep -q "signed-by" install.sh; then
  echo "Error: install.sh does not use signed-by in the sources.list entry."
  has_errors=1
fi

if [ "$has_errors" -eq 1 ]; then
  echo "Validation failed."
  exit 1
fi

echo "Validation passed."
