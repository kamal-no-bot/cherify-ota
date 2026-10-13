#!/bin/bash
# Publish a new Cherify build to the OTA page.
# Usage: ./update-ipa.sh /path/to/Cherify.ipa
set -e
cd "$(dirname "$0")"

IPA="$1"
if [ ! -f "$IPA" ]; then
  echo "Usage: ./update-ipa.sh /path/to/Cherify.ipa"
  exit 1
fi

cp "$IPA" Cherify.ipa

# Read version and build number out of the new IPA
TMP=$(mktemp -d)
unzip -q -o Cherify.ipa "Payload/*.app/Info.plist" -d "$TMP"
PLIST=$(ls "$TMP"/Payload/*.app/Info.plist)
VER=$(plutil -extract CFBundleShortVersionString raw "$PLIST")
BUILD=$(plutil -extract CFBundleVersion raw "$PLIST")
rm -rf "$TMP"
SIZE_MB=$(du -m Cherify.ipa | cut -f1)

# Stamp the new version into the manifest and the install page
plutil -replace items.0.metadata.bundle-version -string "$VER" manifest.plist
sed -i '' -E "s|Version [^<]* MB|Version $VER (Build $BUILD) \&middot; $SIZE_MB MB|" index.html

# This repo keeps ONE commit, never a history. Every IPA ever committed stays
# in the object store for ever at about 70 MB a piece, so a commit per build
# grows the clone without limit (it reached 1.3 GB once). Amending the single
# commit and replacing the branch keeps the repo the size of one build.
git add -A
git commit -q --amend -m "Cherify v$VER (build $BUILD)"
git push --force-with-lease origin HEAD:main

# Drop the superseded IPA from the local object store as well
git reflog expire --expire=now --expire-unreachable=now --all
git gc --prune=now --quiet

echo ""
echo "Pushed v$VER (build $BUILD). GitHub Pages updates in about a minute."
echo "Client link is unchanged: https://kamal-no-bot.github.io/cherify-ota/"
