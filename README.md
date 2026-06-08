# Apply The Packages

This repository hosts the static APT repository for Apply The CLI packages, including `boundline` and `canon`.

The repository is published through GitHub Pages and served from:

```text
https://apply-the.github.io/packages/apt
```

## Installation

### Configure the repository only

```bash
curl -fsSL https://apply-the.github.io/packages/install.sh | sh
```

### Configure the repository and install `boundline`

```bash
curl -fsSL https://apply-the.github.io/packages/install.sh | sh -s -- boundline
```

### Configure the repository and install `canon`

```bash
curl -fsSL https://apply-the.github.io/packages/install.sh | sh -s -- canon
```

### Manual setup

```bash
curl -fsSL https://apply-the.github.io/packages/apt/gpg.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/apply-the-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/apply-the-archive-keyring.gpg] https://apply-the.github.io/packages/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/apply-the.list

sudo apt update
sudo apt install boundline
```

To install `canon`:

```bash
sudo apt install canon
```

## Repository Layout

```text
apt/
├── gpg.key
├── dists/
│   └── stable/
│       ├── InRelease
│       ├── Release
│       ├── Release.gpg
│       └── main/
│           ├── binary-amd64/
│           │   ├── Packages
│           │   └── Packages.gz
│           └── binary-arm64/
│               ├── Packages
│               └── Packages.gz
└── pool/
    └── main/
        ├── b/
        │   └── boundline/
        └── c/
            └── canon/
```

APT clients do not install packages directly from `.deb` files in `apt/pool/`.

APT reads the signed repository metadata under:

```text
apt/dists/stable/
```

The `pool/` directory stores package files. The `dists/` directory tells APT which packages exist, where they are, which architectures are available, and which checksums are expected.

## Maintainer Guide

### Publishing model

`apply-the/packages` is the only repository responsible for publishing the APT repository.

Producer repositories such as `apply-the/boundline` and `apply-the/canon` must not rebuild, sign, or push APT metadata directly.

The intended publishing flow is:

```text
boundline/canon release workflow
→ build .deb assets
→ attach .deb files to the producer GitHub Release
→ trigger repository_dispatch on apply-the/packages

apply-the/packages
→ download incoming .deb files
→ copy them into apt/pool
→ rebuild APT metadata
→ sign Release metadata
→ validate repository structure
→ commit apt/pool, apt/dists, and apt/gpg.key
→ deploy through GitHub Pages
```

This keeps the GPG signing key only in the `apply-the/packages` repository.

### Rebuild APT metadata

Whenever `.deb` files are added, removed, or replaced under `apt/pool/`, the APT metadata must be rebuilt and signed.

Use the manual GitHub Actions workflow:

```text
Actions -> Rebuild APT Repository -> Run workflow
```

Or run locally:

```bash
export APT_GPG_PRIVATE_KEY="$(cat /path/to/apt-repo-private.asc)"
export APT_GPG_PASSPHRASE="..."

./scripts/rebuild-apt-repo.sh
./scripts/validate-apt-repo.sh
```

Then commit the generated metadata:

```bash
git add apt/pool apt/dists apt/gpg.key
git commit -m "Rebuild APT repository metadata"
git push
```

### Required GitHub Secrets

The `apply-the/packages` repository requires these GitHub Actions secrets:

| Secret | Purpose |
|---|---|
| `APT_GPG_PUBLIC_KEY` | Public signing key written to `apt/gpg.key` |
| `APT_GPG_PRIVATE_KEY` | Armored private key used to sign APT `Release` metadata |
| `APT_GPG_PASSPHRASE` | Passphrase for the private key |

Producer repositories require a token that can dispatch publication requests to `apply-the/packages`:

| Repository | Secret | Purpose |
|---|---|---|
| `apply-the/boundline` | `PACKAGES_REPO_TOKEN` | Calls `repository_dispatch` on `apply-the/packages` |
| `apply-the/canon` | `PACKAGES_REPO_TOKEN` | Calls `repository_dispatch` on `apply-the/packages` |

The token must be allowed to call:

```text
POST /repos/apply-the/packages/dispatches
```

### Required GitHub Pages Setting

Set GitHub Pages to deploy from GitHub Actions:

```text
Settings -> Pages -> Build and deployment -> Source: GitHub Actions
```

### Release Publishing Contract

A valid APT publication updates both package files and repository metadata.

A valid publication may change:

```text
apt/pool/**/*.deb
apt/dists/stable/**
apt/gpg.key
```

A repository state with `.deb` files but missing any of the following is invalid:

```text
apt/dists/stable/main/binary-amd64/Packages.gz
apt/dists/stable/main/binary-arm64/Packages.gz
apt/dists/stable/Release
apt/dists/stable/Release.gpg
apt/dists/stable/InRelease
apt/gpg.key
```

`validate-apt-repo.sh` intentionally fails in that state.

## Validation

Run:

```bash
./scripts/validate-apt-repo.sh
```

The validation supports two modes:

```text
BOOTSTRAP mode:
  no .deb files are present
  metadata checks are relaxed

RELEASE mode:
  .deb files are present
  signed APT metadata is required
```

If packages are present, validation requires:

```text
apt/gpg.key
apt/dists/stable/main/binary-amd64/Packages.gz
apt/dists/stable/main/binary-arm64/Packages.gz
apt/dists/stable/Release
apt/dists/stable/Release.gpg
apt/dists/stable/InRelease
```

## GitHub Actions

### `Validate APT Repository`

Runs on push and pull request.

It checks:

```text
script syntax
APT repository structure
signed-by usage in install.sh
absence of committed private keys
```

### `Rebuild APT Repository`

Runs manually or through `repository_dispatch`.

It:

```text
downloads incoming .deb files when triggered by producer repositories
writes apt/gpg.key from APT_GPG_PUBLIC_KEY
rebuilds Packages and Packages.gz
generates Release
signs Release.gpg and InRelease
validates the repository
commits generated APT metadata
```

### `Deploy to GitHub Pages`

Runs after changes land on `main`.

It validates the repository and publishes only the prepared static site contents:

```text
apt/
install.sh
README.md
```

## Troubleshooting

### `Packages.gz is missing`

This means `.deb` files exist under `apt/pool/`, but APT metadata has not been rebuilt.

Run:

```text
Actions -> Rebuild APT Repository -> Run workflow
```

### `Release.gpg` or `InRelease` is missing

This means metadata was generated but not signed.

Check that these secrets exist in `apply-the/packages`:

```text
APT_GPG_PRIVATE_KEY
APT_GPG_PASSPHRASE
```

### `apt/gpg.key is missing`

Check that `APT_GPG_PUBLIC_KEY` exists and that the rebuild workflow writes it to:

```text
apt/gpg.key
```

### `sudo apt update` cannot verify signatures

Reinstall the repository key:

```bash
curl -fsSL https://apply-the.github.io/packages/apt/gpg.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/apply-the-archive-keyring.gpg

sudo apt update
```

### Package not found

Check that the package appears in the relevant package index:

```bash
curl -fsSL https://apply-the.github.io/packages/apt/dists/stable/main/binary-amd64/Packages.gz \
  | gunzip \
  | grep -A20 '^Package: boundline'
```

For `canon`:

```bash
curl -fsSL https://apply-the.github.io/packages/apt/dists/stable/main/binary-amd64/Packages.gz \
  | gunzip \
  | grep -A20 '^Package: canon'
```

## Security Notes

Never commit private key material.

The following file must never be committed:

```text
apt-repo-private.asc
```

The validation script also checks for committed private key material.

Only the public key belongs in the repository or generated Pages site:

```text
apt/gpg.key
```
