#!/usr/bin/env bash

status=0
trap 'exit "$status"' EXIT

echo "Syncing submodule URLs..."
git submodule sync --recursive || status=$?

if [ "$status" -eq 0 ]; then
  echo "Updating submodules to the latest remote commits..."
  git submodule update --init --recursive --remote --force || status=$?
fi

if [ "$status" -eq 0 ]; then
  echo "Submodules are up to date."
else
  echo "Failed to update submodules. Exit code: $status"
fi

read -r -n 1 -s -p "Press any key to continue..."
echo
