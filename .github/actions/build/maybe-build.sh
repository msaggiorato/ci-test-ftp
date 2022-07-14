#!/bin/bash -e
# Build
cd "$BUILD_DIR";
if [ -f "$BUILD_DIR/.github/build-for-deployment.sh" ]; then
	echo "Running code specific build script"
	bash "$BUILD_DIR/.github/build-for-deployment.sh"
else
	echo "Running default build script"
	build-for-deployment.sh
fi

# Cleanup
rmFind() {
	find "${1}" -type d -name "${2}" | while read DIR_TO_REMOVE; do
	echo "Removing ${DIR_TO_REMOVE}"
	rm -rf "${DIR_TO_REMOVE}"
	done
}
rmFind "$BUILD_DIR" ".git"
rmFind "$BUILD_DIR" ".github"
rmFind "$BUILD_DIR" "node_modules"
rm -rf "${GITHUB_WORKSPACE}/$BUILD_DIR/vendor"
