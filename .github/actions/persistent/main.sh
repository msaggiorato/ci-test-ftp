#!/bin/bash -e
DEPLOY_BRANCH="${INPUT_BRANCH}"
echo "PERSISTENTFS_INPUT_BRANCH=${INPUT_BRANCH}" >> "$GITHUB_ENV"
export PERSISTENTFS_INPUT_BRANCH="${INPUT_BRANCH}"
PERSISTENT_PATH="${GITHUB_WORKSPACE}/${DEPLOY_BRANCH}"

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

read-persistent.sh
