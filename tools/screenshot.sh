#!/usr/bin/env bash
# Render a text diagram to PNG with Playwright's headless Chromium.
# usage: screenshot.sh diagram.txt out.png [width] [height]
set -euo pipefail
in=$1; out=$2; w=${3:-900}; h=${4:-500}
shell=$(ls ~/.cache/ms-playwright/chromium_headless_shell-*/chrome-linux/headless_shell | tail -1)
html=$(mktemp --suffix=.html)
{
    echo '<html><body style="margin:8px;background:#fff">'
    echo '<pre style="font:16px/1.0 '"'DejaVu Sans Mono'"',monospace">'
    sed 's/&/\&amp;/g;s/</\&lt;/g' "$in"
    echo '</pre></body></html>'
} > "$html"
"$shell" --no-sandbox --hide-scrollbars --window-size="$w,$h" --screenshot="$(realpath -m "$out")" "file://$html" 2>/dev/null
rm -f "$html"
