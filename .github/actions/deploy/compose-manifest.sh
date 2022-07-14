#!/bin/bash -e
SOURCE_DIR="${1:-source}"
TARGET_DIR="${2:-target}"
TMP_FILE="$(mktemp)"
DETAILS_FILE="${3:-${TMP_FILE}}"

rm -f "${DETAILS_FILE}"
touch "${DETAILS_FILE}"

ls -al "${SOURCE_DIR}"

echo " "
echo " "
echo " "

ls -al "${TARGET_DIR}"

echo " "
echo " "
echo " "

rsync --dry-run -rci "${TARGET_DIR}/" "${SOURCE_DIR}/" | cut -d" " -f2- | xargs -I{} echo "+ {}" | sed '/\/$/d' >> "${DETAILS_FILE}"
rsync --dry-run -rci --delete --existing --ignore-existing "${TARGET_DIR}/" "${SOURCE_DIR}/" | cut -d" " -f2- | xargs -I{} echo "- {}" | sed '/\/$/d' >> "${DETAILS_FILE}"

if [ -s "${DETAILS_FILE}" ]; then
	cat "${DETAILS_FILE}"
	echo "::set-output name=is-empty::false"
else
	echo "::set-output name=is-empty::true"
fi

