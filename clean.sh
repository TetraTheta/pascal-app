#!/usr/bin/env bash

cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1

if [[ -d .dist ]]; then
  echo "Deleting .dist"
  rm -rf -- .dist
fi

while IFS= read -r -d '' path; do
  echo "Deleting $path"
  rm -rf -- "$path"
done < <(find . -path './.git' -prune -o -type d \( -name backup -o -name lib -o -name libdsgn \) -prune -print0)

while IFS= read -r -d '' path; do
  echo "Deleting $path"
  rm -f -- "$path"
done < <(find . -path './.git' -prune -o -type f \( -iname '*.compiled' -o -iname '*.dbg' -o -iname '*.exe' -o -iname '*.o' -o -iname '*.ppu' -o -iname '*.res' -o -iname '*.rst' -o -iname '*.obj' -o -iname '*.a' \) -print0)

if [[ -f file-optimizer/FileOptimizer.ini ]]; then
  echo "Deleting file-optimizer/FileOptimizer.ini"
  rm -f -- file-optimizer/FileOptimizer.ini
fi

while IFS= read -r -d '' path; do
  [[ "$path" == . ]] && continue
  if rmdir -- "$path" 2>/dev/null; then
    echo "Deleting $path"
  fi
done < <(find . -path './.git' -prune -o -type d -print0 | sort -zr)

read -r -n 1 -s -p "Press any key to continue..."
echo
