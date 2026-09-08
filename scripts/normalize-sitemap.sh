#!/usr/bin/env bash
set -euo pipefail

sitemap="_site/sitemap.xml"

if [[ ! -f "$sitemap" ]]; then
  echo "Expected sitemap not found: $sitemap" >&2
  exit 1
fi

# Match Quarto's clean canonical URLs for directory index pages.
perl -0pi -e 's{/index\.html</loc>}{/</loc>}g' "$sitemap"
