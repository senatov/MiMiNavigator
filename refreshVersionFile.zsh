#!/bin/zsh
set -euo pipefail

DEBUG=false

if [[ "${1:-}" == "-X" ]]; then
  DEBUG=true
fi

VERSION=$(date +"%y.%m.%d.%H%M")
echo "$VERSION" > .version

if $DEBUG; then
  echo "📦 Wrote version to .version: $VERSION"
else
  echo "✅ Updated version: $VERSION"
fi