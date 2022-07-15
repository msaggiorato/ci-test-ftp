#!/bin/bash -e
if [ -f 'composer.json' ]; then
	echo "--------------------------------------------------"
	echo "Setup authentication for out Satispress instance"
	if [ -n "${INPUT_SATIS_KEY}" ]; then
		composer config http-basic.packages.saucal.com "${INPUT_SATIS_KEY}" satispress
	fi

	# As we are on the deploy branch, plugins should exist. Run composer install to update dependencies as needed.
	echo "--------------------------------------------------"
	echo "Running composer install"
	composer install --no-dev
fi

if [ -f 'package.json' ]; then
	echo "--------------------------------------------------"
	echo "List the state of node modules"
	npm list
	echo "--------------------------------------------------"
	echo "Installing node dependencies"
	npm ci
	echo "--------------------------------------------------"
	echo "Running node build (if present)"
	npm run build --if-present
	echo "--------------------------------------------------"
	echo "Running node test (if present)"
	npm run test --if-present
fi
