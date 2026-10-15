---
layout: default
title: Installation — unleash
---

# Installation

## Homebrew (easiest)

```bash
brew tap mateussiqueira/unleash
brew install unleash
```

Or in one step:
```bash
brew install mateussiqueira/unleash/unleash
```

## Direct download

```bash
REPO=ejams1/unleash      # swap for mateussiqueira/unleash once upstream has these fixes
mkdir -p ~/unleash
curl -fsSL "https://raw.githubusercontent.com/$REPO/main/unleash-standalone.sh" \
  -o ~/unleash/unleash-standalone.sh
chmod +x ~/unleash/unleash-standalone.sh
sudo ~/unleash/unleash-standalone.sh init
```

## From a USB drive (for Recovery mode)

1. Format a USB/SSD as **FAT32**, **APFS**, or **exFAT**
2. Copy the whole `unleash` folder to the drive — or put `unleash-standalone.sh` in a folder of its own (e.g. `YourDrive/unleash/`). Backups are written one level above the script, so a file sitting at the drive root would target `/Volumes/.unleash-backup`
3. Boot to Recovery and run from `/Volumes/YourDrive/unleash`

## Via curl in Recovery (needs internet)

The Recovery Terminal is already root, so no `sudo` here. Download **into a
folder**: `backup` writes to the folder *above* the script, and a loose file in
`/tmp` would try to write to `/`, which is read-only in Recovery.

```bash
REPO=ejams1/unleash      # swap for mateussiqueira/unleash once upstream has these fixes
mkdir -p /tmp/unleash
curl -fsSL "https://raw.githubusercontent.com/$REPO/main/unleash-standalone.sh" \
  -o /tmp/unleash/unleash-standalone.sh
chmod +x /tmp/unleash/unleash-standalone.sh
cd /tmp/unleash

./unleash-standalone.sh version
./unleash-standalone.sh doctor            # script path, modules, Recovery status
./unleash-standalone.sh check             # pre-format safety report
./unleash-standalone.sh test all          # dry run: writes nothing
./unleash-standalone.sh backup            # saved to /tmp/.unleash-backup
./unleash-standalone.sh suppress          # or: bypass (creates an admin user)
```

`/tmp` is a RAM disk in Recovery: copy `/tmp/.unleash-backup` to a USB drive
before rebooting if you want `restore` to still find it later.

## Building from source

```bash
git clone https://github.com/mateussiqueira/unleash.git
cd unleash
bash examples/build-standalone.sh
# writes unleash-standalone.sh (single file, all modules inlined)
```

## Verifying the installation

```bash
./unleash version
# → unleash v2.0.0

./unleash doctor
# Runs pre-flight diagnostics
```
