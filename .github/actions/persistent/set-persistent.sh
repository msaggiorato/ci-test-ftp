#!/bin/bash -e
PERSISTENT_PATH="$GITHUB_WORKSPACE/${PERSISTENTFS_INPUT_BRANCH}"
VAR="$(echo "$1" | awk '{print toupper($0)}')"
VAL="$(echo "$2" | head -1)" # Only support one line
mkdir -p "${PERSISTENT_PATH}"
FILE="$(echo "$VAR" | awk '{print tolower($0)}')"
echo "${VAL}" > "${PERSISTENT_PATH}/${FILE}"

ENV_VAR="PERSISTENT_${VAR}"

sed -i "/^$ENV_VAR=/d" "$GITHUB_ENV"
echo "$ENV_VAR=$VAL" >> "$GITHUB_ENV"

