#!/bin/sh
# Puts the wake shim on PATH and writes the worker's systemd user unit when it is missing or outdated.
# Never overwrites a wake that did not come from this plugin.
dir="${WAKE_BIN_DIR:-$HOME/.local/bin}"
dest="$dir/wake"
if [ -e "$dest" ] && ! grep -q "herdr-wake plugin" "$dest"; then
  echo "herdr-wake: $dest exists and is not this plugin's shim; left it alone" >&2
  exit 1
fi
root=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$dir" && sed "s|^fallback=\$|fallback='$root'|" "$root/bin/wake" > "$dest" && chmod +x "$dest" || exit 1
echo "herdr-wake: installed $dest"
case ":$PATH:" in *":$dir:"*) ;; *) echo "herdr-wake: add $dir to PATH" ;; esac
python3 -I "$root/wake" install-unit
