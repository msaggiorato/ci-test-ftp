#!/bin/bash
if [ -n "$PERSISTENTFS_CLOSED" ]; then
	echo "Already pushed"
	exit 0
fi
echo "PERSISTENTFS_CLOSED=1" >> "$GITHUB_ENV"
DEPLOY_BRANCH="${INPUT_BRANCH}"
COMMIT_AUTHOR_NAME="github-actions"
COMMIT_AUTHOR_EMAIL="github-actions@github.com"
cd "${GITHUB_WORKSPACE}/${DEPLOY_BRANCH}"

git add -A .

if [ -z "$(git status --porcelain)" ]; then
	echo "NOTICE: No changes to deploy"
	exit 0
fi

# Maybe recreate branch. We don't need history of changes
if [[ -n $( git show-ref --heads | sed "#refs/heads/$DEPLOY_BRANCH\$#d" ) ]]; then
	git checkout --quiet --orphan "${DEPLOY_BRANCH}-temp"
	git branch -D "${DEPLOY_BRANCH}"
	git checkout --quiet --orphan "${DEPLOY_BRANCH}"
fi

# Add all changes again
git add -A .

export GIT_COMMITTER_NAME="${COMMIT_AUTHOR_NAME}"
export GIT_COMMITTER_EMAIL="${COMMIT_AUTHOR_EMAIL}"

# Commit it.
# Set the Author to the commit (expected to be a client dev) and the committer
# will be set to the default Git user for this system
git commit --author="${COMMIT_AUTHOR_NAME} <${COMMIT_AUTHOR_EMAIL}>" -m "Persistent FS changes"

# Push it (push it real good).
git push --force origin "${DEPLOY_BRANCH}"
