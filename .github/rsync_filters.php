#!/usr/bin/env php
<?php

/**
 * Parses composer.json to figure out the directories controlled by wp-packagist.
 * Then, parses .gitignore and attempts to create rules based on the contents of it, 
 * for each one of the composer controlled directories. 
 * 
 * Since .gitignore doesn't work the same way as Rsync filters, this process is not fail-proof, 
 * and some repo structures may cause issues.
 * 
 * Should work for our usual structure in VIP, but is still a WIP.
 */

$project_path         = dirname( __FILE__ ) . '/../';
$composer_config_path = $project_path . 'composer.json';
$gitignore_path       = $project_path . '.gitignore';

$default_composer_paths = array(
	'wp-content/client-mu-plugins/',
	'wp-content/plugins/',
	'wp-content/themes/',
);

$config_json = file_get_contents( $composer_config_path );
$gitignore   = file_get_contents( $gitignore_path );
$rsync_rules = array();

if ( ! $config_json ) {
	exit( 'Unable to open file ($composer_config_path)' );
}

if ( ! $gitignore ) {
	exit( 'Unable to open file ($gitignore_path)' );
}

foreach ( get_composer_paths( $config_json ) as $path ) {
	$rules = get_matching_rules( $path );

	foreach ( $rules as $rule ) {
		$rsync_rules[] = parse_rule( $rule[0], ! isset( $rule[1] ) || '!' !== $rule[1] );
	}
}

$rsync_rules = array_filter( $rsync_rules );

usort(
	$rsync_rules,
	function ( $a, $b ) {
		return $a['specificity'] < $b['specificity'] ? 1 : -1;
	}
);

$rsync_rules = array_column( $rsync_rules, 'rule' );

echo implode( PHP_EOL, $rsync_rules ) . PHP_EOL;

/* That's all, Runtime stops here, only callables from here on. */

function parse_rule( $rule, $exclude ) {

	global $project_path;

	$rule = trim( $rule );
	$rule = str_replace( '!', '', $rule );

	$specificity = get_rule_specificity( $rule );

	if ( preg_match( '/[^\/]\*/', $rule ) ) { // match ending in *, but not /*
		$is_dir = true; // we assume
	} else {
		$rule   = rtrim( rtrim( $rule, '*' ), '/' );
		$is_dir = is_dir( $project_path . $rule );
	}

	if ( ! $is_dir ) {
		return null;
	}

	$rule = $rule . ( $exclude ? '/**' : '/***' );
	$rule = ( $exclude ? '- ' : '+ ' ) . $rule;

	return array(
		'specificity' => $specificity,
		'rule'        => $rule,
	);
}

function get_composer_paths( $config_json ) {
	$composer_config = json_decode( $config_json, true );

	if ( isset( $composer_config['extra'], $composer_config['extra']['installer-paths'] ) ) {
		$keys = array_keys( $composer_config['extra']['installer-paths'] );

		$keys = array_map(
			function ( $path ) {
				return str_replace( '{$name}/', '', $path );
			},
			$keys
		);

		return $keys;
	}

	global $default_composer_paths;
	return $default_composer_paths;
}

function get_matching_rules( $path ) {
	global $gitignore;

	$regex = '/^(!|\/)?' . str_replace( '/', '\/', preg_quote( $path ) ) . '.*\n/m';
	preg_match_all( $regex, $gitignore, $matches, PREG_SET_ORDER );

	return $matches;
}

function get_rule_specificity( $rule ) {

	$score = 0;
	$parts = explode( '/', $rule );

	foreach ( $parts as $part ) {

		if ( empty( $part ) ) {
			continue;
		}

		if ( false !== strpos( $part, '*' ) ) {
			$part = str_replace( '*', '', $part ); // Remove all asterisks;
			// If part was only asterisks, add 5, if there were more chars, add 10
			$score = $score + ( empty( $part ) ? 5 : 10 );
		} else {
			// No asterisks
			$score = $score + 20;
		}
	}

	return $score;
}

die();
