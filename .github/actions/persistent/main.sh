#!/bin/bash -e
DEPLOY_BRANCH="${INPUT_BRANCH}"
PERSISTENT_PATH="${GITHUB_WORKSPACE}/${DEPLOY_BRANCH}"

if [ ! -d "$PERSISTENT_PATH" ]; then
	echo "PERSISTENTFS_INPUT_BRANCH=${INPUT_BRANCH}" >> "$GITHUB_ENV"
	export PERSISTENTFS_INPUT_BRANCH="${INPUT_BRANCH}"

	REPO_SSH_URL="https://${GITHUB_ACTOR}:${INPUT_TOKEN}@github.com/${GITHUB_REPOSITORY}"

	echo "$REPO_SSH_URL"
	# Making the directory we're going to sync the build into
	git init --quiet "${PERSISTENT_PATH}"
	cd "${PERSISTENT_PATH}"
	git remote add origin "${REPO_SSH_URL}"
	if [[ 0 = $(git ls-remote --heads origin "${DEPLOY_BRANCH}" | wc -l) ]]; then
		echo -e "\nCreating a ${DEPLOY_BRANCH} branch..."
		git checkout --quiet --orphan "${DEPLOY_BRANCH}"
	else
		echo "Using existing ${DEPLOY_BRANCH} branch"
		git fetch origin "${DEPLOY_BRANCH}" --depth=1
		git checkout --quiet "${DEPLOY_BRANCH}"
	fi
fi

maybe_output() {
	if [ -n "$2" ]; then
		echo "::set-output name=value::$1"
	fi
}

expose() {
	ENV_VAR="PERSISTENT_${1}"
	declare -x "$ENV_VAR=${2}"
	sed -i "/^$ENV_VAR=/d" "$GITHUB_ENV"
	echo "$ENV_VAR=${2}" >> "$GITHUB_ENV"
}

get_value() {
	FILE="$(echo "$1" | awk '{print tolower($0)}')"
	if [ -f "${PERSISTENT_PATH}/${FILE}" ]; then
		VAR="$(echo "$1" | awk '{print toupper($0)}')"
		VAL=$(head -1 "$FILE") # Only support one line

		expose "$VAR" "$VAL"
		maybe_output "$VAL" "$3"
	else
		maybe_output "$2" "$3"
	fi
}

set_value() {
	FILE="$(echo "$1" | awk '{print tolower($0)}')"
	VAR="$(echo "$1" | awk '{print toupper($0)}')"
	VAL="$(echo "$2" | head -1)" # Only support one line
	echo "${VAL}" > "${PERSISTENT_PATH}/${FILE}"

	expose "$VAR" "$VAL"
	maybe_output "$VAL" "$3"
}

if [ -n "${INPUT_GET}" ]; then
	get_value "${INPUT_GET}" "${INPUT_DEFAULT}" 1
elif [ -n "${INPUT_SET}"  ]; then
	set_value "${INPUT_SET}" "${INPUT_VALUE}" 1
else
	cd "${PERSISTENT_PATH}"
	shopt -s nullglob
	for FILE in *; do
		get_value "$FILE"
	done
fi
