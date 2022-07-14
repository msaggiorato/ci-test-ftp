#!/bin/bash -e
#
# Deploy your branch on VIP Go.
#

set -e # Change to `set -ex` to debug commands.

BUILD_JOB_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
echo "DEBUG: BUILD_JOB_URL: '${BUILD_JOB_URL}'"

BRANCH="${GITHUB_REF_NAME}" # The branch or tag name that triggered the workflow run. For example, feature-branch-1.

SRC_DIR="${GITHUB_WORKSPACE:-$PWD}"
BUILD_DIR="${RUNNER_TEMP}/vip-go-build-$(date +%s)"  # RUNNER_TEMP

echo "DEBUG: SRC_DIR: '${SRC_DIR}'"
echo "DEBUG: BUILD_DIR: '${BUILD_DIR}'"

REMOTE_REPO=${target_repo}
REPO_SSH_URL="https://saucal-bot:${repo_token}@github.com/${REMOTE_REPO}"
COMMIT_SHA=${GITHUB_SHA}

branchmapping=remote_branch_${BRANCH//[\/\-]/_}
DEPLOY_BRANCH=${!branchmapping:-$BRANCH}

cd $SRC_DIR
COMMIT_AUTHOR_NAME="$( git log --format=%an -n 1 ${COMMIT_SHA} )"
COMMIT_AUTHOR_EMAIL="$( git log --format=%ae -n 1 ${COMMIT_SHA} )"
COMMIT_COMMITTER_NAME="$( git log --format=%cn -n 1 ${COMMIT_SHA} )"
COMMIT_COMMITTER_EMAIL="$( git log --format=%ce -n 1 ${COMMIT_SHA} )"

echo "DEBUG: REPO_SSH_URL: '${REPO_SSH_URL}'"

echo "--------------------------------------------------"
echo "Running some checks"
# ---------------

if [[ -z "${BRANCH}" ]]; then
	echo "ERROR: No branch specified!"
	echo "This variable should be set by someone?, if you consistently experience errors please check with WordPress.com VIP support."
	exit 1
fi

if [[ -d "$BUILD_DIR" ]]; then
	echo "ERROR: ${BUILD_DIR} already exists."
	echo "This should not happen, if you consistently experience errors please check with WordPress.com VIP support."
	exit 1
fi

echo "--------------------------------------------------"
echo "Everything seems OK, getting the built repo sorted"

echo "--------------------------------------------------"
echo "Deploying ${BRANCH} to ${DEPLOY_BRANCH}"

# Making the directory we're going to sync the build into
git init "${BUILD_DIR}"
cd "${BUILD_DIR}"
git remote add origin "${REPO_SSH_URL}"
if [[ 0 = $(git ls-remote --heads origin "${DEPLOY_BRANCH}" | wc -l) ]]; then
	echo -e "\nCreating a ${DEPLOY_BRANCH} branch..."
	git checkout --quiet --orphan "${DEPLOY_BRANCH}"
else
	echo "Using existing ${DEPLOY_BRANCH} branch"
	git fetch origin "${DEPLOY_BRANCH}" --depth=1
	git checkout --quiet "${DEPLOY_BRANCH}"
fi

# Expand all submodules
git submodule update --init --recursive;

echo "--------------------------------------------------"
echo "Copying the files over"

if ! command -v 'rsync'; then
	APT_GET_PREFIX=''
	if command -v 'sudo'; then
		APT_GET_PREFIX='sudo'
	fi

	$APT_GET_PREFIX apt-get update
	$APT_GET_PREFIX apt-get install -q -y rsync
fi

echo "--------------------------------------------------"
echo "Syncing files... quietly"

# Parse composer.json & .gitignore in order to create filter rules for rsync, 
# in order to avoid modifying composer controlled packages
$SRC_DIR/.github/rsync_filters.php > rsync_filters.txt
echo "Using the following filters for rsync:"
cat rsync_filters.txt

rsync --delete -a "${SRC_DIR}/" "${BUILD_DIR}" --exclude='.git/' --exclude='node_modules/' --exclude='/vendor/' --filter="merge rsync_filters.txt"

echo "--------------------------------------------------"
echo "Setup authentication for out Satispress instance"
composer config http-basic.packages.saucal.com ${satis_key} satispress

# As we are on the deploy branch, plugins should exist. Run composer install to update dependencies as needed.
echo "--------------------------------------------------"
echo "Running composer install"
composer install --no-dev

echo "--------------------------------------------------"
echo "Handling gitignore overrides"
# To allow commiting built files in the build branch (which are typically ignored)
# -------------------
BUILD_DEPLOYIGNORE_PATH="${BUILD_DIR}/.deployignore"
if [ -f $BUILD_DEPLOYIGNORE_PATH ]; then
	BUILD_GITIGNORE_PATH="${BUILD_DIR}/.gitignore"

	if [ -f $BUILD_GITIGNORE_PATH ]; then
		rm $BUILD_GITIGNORE_PATH
	fi

	echo "-- found .deployignore; emptying all gitignore files"
	find $BUILD_DIR -type f -name '.gitignore' | while read GITIGNORE_FILE; do
		echo "# Emptied by vip-go-build; '.deployignore' exists and used as global .gitignore. See https://wp.me/p9nvA-89A" > $GITIGNORE_FILE
		echo "${GITIGNORE_FILE}"
	done

       	echo "-- using .deployignore as global .gitignore"
	mv $BUILD_DEPLOYIGNORE_PATH $BUILD_GITIGNORE_PATH 
fi

echo "--------------------------------------------------"
echo "Make up the commit, commit, and push"
# ------------------------------------

# Set Git committer
git config user.name "${COMMIT_COMMITTER_NAME}"
git config user.email "${COMMIT_COMMITTER_EMAIL}"

# Add changed files, delete deleted, etc, etc, you know the drill
git add -A .

if [ -z "$(git status --porcelain)" ]; then
	echo "NOTICE: No changes to deploy"
	exit 0
fi

# Commit it.
MESSAGE=$( printf 'Build changes from %s\n\n%s' "${COMMIT_SHA}" "${BUILD_JOB_URL}" )
# Set the Author to the commit (expected to be a client dev) and the committer
# will be set to the default Git user for this system
git commit --author="${COMMIT_AUTHOR_NAME} <${COMMIT_AUTHOR_EMAIL}>" -m "${MESSAGE}"

# Push it (push it real good).
git push origin "${DEPLOY_BRANCH}"
