#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
rm -f wishly-extension.zip
zip -r wishly-extension.zip manifest.json popup.html popup.css popup.js
echo "wishly-extension.zip pronto"
