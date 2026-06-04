#!/bin/bash
set -euo pipefail

# Ensure we are in the repository root
cd "$(dirname "$0")/.."

echo "Rebuilding APT repository metadata..."

has_debs=0
if find apt/pool -name "*.deb" | grep -q .; then
  has_debs=1
fi

# Generate Packages and Packages.gz
cd apt
echo "Processing amd64 packages..."
dpkg-scanpackages --arch amd64 pool/ > dists/stable/main/binary-amd64/Packages
gzip -9ck dists/stable/main/binary-amd64/Packages > dists/stable/main/binary-amd64/Packages.gz

echo "Processing arm64 packages..."
dpkg-scanpackages --arch arm64 pool/ > dists/stable/main/binary-arm64/Packages
gzip -9ck dists/stable/main/binary-arm64/Packages > dists/stable/main/binary-arm64/Packages.gz

echo "Generating Release file..."
cd dists/stable

cat <<EOF > Release
Origin: Apply The
Label: Apply The Packages
Suite: stable
Codename: stable
Version: 1.0
Architectures: amd64 arm64
Components: main
Description: Apply The open-source CLI packages
Date: $(date -Ru)
EOF

# Compute checksums
for hash in MD5Sum SHA1 SHA256; do
  echo "${hash}:" >> Release
  for file in $(find main -type f | LC_ALL=C sort); do
    size=$(stat -c%s "$file")
    case "$hash" in
      MD5Sum) sum=$(md5sum "$file" | cut -d' ' -f1) ;;
      SHA1) sum=$(sha1sum "$file" | cut -d' ' -f1) ;;
      SHA256) sum=$(sha256sum "$file" | cut -d' ' -f1) ;;
    esac
    echo " ${sum} ${size} ${file}" >> Release
  done
done

echo "Release file generated."

cd ../../../

# Check if we should sign
if [ "$has_debs" -eq 1 ]; then
  if [ -n "${APT_GPG_PRIVATE_KEY:-}" ] && [ -n "${APT_GPG_PASSPHRASE:-}" ]; then
    echo "Signing Release file..."
    
    rm -f apt/dists/stable/InRelease apt/dists/stable/Release.gpg
    
    echo "$APT_GPG_PRIVATE_KEY" | gpg --batch --import

    gpg --batch --yes --pinentry-mode loopback --passphrase "$APT_GPG_PASSPHRASE" \
        --clearsign -o apt/dists/stable/InRelease apt/dists/stable/Release
    
    gpg --batch --yes --pinentry-mode loopback --passphrase "$APT_GPG_PASSPHRASE" \
        -abs -o apt/dists/stable/Release.gpg apt/dists/stable/Release
        
    echo "Metadata signed successfully."
  else
    echo "Error: Packages are present but APT_GPG_PRIVATE_KEY or APT_GPG_PASSPHRASE is not set."
    echo "Cannot sign metadata. Failing."
    exit 1
  fi
else
  echo "Warning: No packages found. Running in bootstrap mode."
  echo "Metadata generated but NOT signed."
fi
