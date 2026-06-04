# Apply The Packages

This repository serves as the static APT package repository for Apply The open-source CLI packages, primarily `boundline` and `canon`. It is hosted on GitHub Pages at `https://apply-the.github.io/packages/apt`.

> [!NOTE]
> **Bootstrap Mode**: This repository is currently in bootstrap mode. There are no `.deb` files yet. Running `sudo apt install boundline` will work only after the first package release publishes `.deb` files and rebuilds the APT metadata.

## User Installation

You can configure the APT repository manually or use our provided install script.

### Using the Install Script

To configure the repository:
```bash
curl -fsSL https://apply-the.github.io/packages/install.sh | sh
```

To configure the repository and install `boundline`:
```bash
curl -fsSL https://apply-the.github.io/packages/install.sh | sh -s -- boundline
```

To configure the repository and install both `boundline` and `canon`:
```bash
curl -fsSL https://apply-the.github.io/packages/install.sh | sh -s -- boundline canon
```

### Manual Installation

To install the Apply The APT repository manually, run:

```bash
curl -fsSL https://apply-the.github.io/packages/apt/gpg.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/apply-the-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/apply-the-archive-keyring.gpg] https://apply-the.github.io/packages/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/apply-the.list

sudo apt update
sudo apt install boundline
```

And for `canon`:
```bash
sudo apt install canon
```

## Maintainer Guide

### Generating Metadata Approach

This repository uses `dpkg-scanpackages` and a script to manually generate the `Release` file, followed by standard GPG signing. This method was chosen because it is simple, fully transparent, and heavily integrates with GitHub Actions without the need for complex, stateful tools like `reprepro`.

### Publishing Packages

The release workflows in the `boundline` and `canon` repositories should automatically push `.deb` files here. They need to:
1. Checkout this repository.
2. Copy the `.deb` files into the appropriate pool directory:
   - `apt/pool/main/b/boundline/`
   - `apt/pool/main/c/canon/`
3. Run `./scripts/rebuild-apt-repo.sh` to generate the new metadata.
4. Commit the changes and push to `main`. 
5. The GitHub Pages workflow in this repository will automatically deploy the updated repository.

### Rebuilding metadata locally

To rebuild the APT metadata manually:
```bash
./scripts/rebuild-apt-repo.sh
```
*Note: If packages are present, you will need the GPG key available and the `APT_GPG_PRIVATE_KEY` and `APT_GPG_PASSPHRASE` environment variables set to sign the new metadata.*

### Validating the repository locally

To validate the structure and configuration of the repository, run:
```bash
./scripts/validate-apt-repo.sh
```

### GPG Key Management

The repository requires a GPG key for signing metadata. The public key is expected at `apt/gpg.key`.

#### Generating a new key
To rotate or generate a new key locally:
```bash
gpg --full-generate-key
# Select RSA and RSA, 4096 bits, no expiration (or as required)
# Note the generated <KEY_ID>

# Export the public key
gpg --armor --export <KEY_ID> > apt/gpg.key

# Export the private key
gpg --armor --export-secret-keys <KEY_ID> > apt-repo-private.asc
```

#### Important: Private Key Storage
> [!CAUTION]
> The `apt-repo-private.asc` file **must never be committed** to this repository. It should be securely stored or immediately discarded after adding it to GitHub Secrets.

The private key must be added as a GitHub Secret named `APT_GPG_PRIVATE_KEY` for use in CI workflows.

### Required GitHub Settings

To enable automated deployment, ensure the following GitHub settings are configured:

1. **GitHub Pages Deployment Source**:
   `Settings -> Pages -> Build and deployment -> Source: GitHub Actions`

2. **GitHub Actions Permissions**:
   `Settings -> Actions -> General -> Workflow permissions -> Read and write permissions`

### Required GitHub Secrets

The following GitHub Action repository secrets must be set:

| Secret Name | Description |
|---|---|
| `APT_GPG_PRIVATE_KEY` | The armored GPG private key used for signing APT metadata. |
| `APT_GPG_PASSPHRASE` | The passphrase for the GPG private key. |
