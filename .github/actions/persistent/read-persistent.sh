#!/bin/bash -e
PERSISTENT_PATH="$GITHUB_WORKSPACE/deployment-info"
mkdir -p "${PERSISTENT_PATH}"
cd "${PERSISTENT_PATH}"

shopt -s nullglob

for FILE in *; do
	VAR="$(echo "$FILE" | awk '{print toupper($0)}')"
	ENV_VAR="PERSISTENT_${VAR}"
	VAL=$(head -1 "$FILE") # Only support one line
	echo "$ENV_VAR=$VAL" >> "$GITHUB_ENV"
done
