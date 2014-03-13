<?php
/**
 * Vector extension
 * 
 * @file
 * @ingroup Extensions
 * 
 * @author Trevor Parscal <trevor@wikimedia.org>
 * @author Roan Kattouw <roan.kattouw@gmail.com>
 * @author Nimish Gautam <nimish@wikimedia.org>
 * @author Adam Miller <amiller@wikimedia.org>
 * @license GPL v2 or later
 * @version 0.3.0
 */

/* Configuration */

// Each module may be configured individually to be globally on/off or user preference based
$wgVectorFeatures = array(
	'collapsiblenav' => array( 'global' => true, 'user' => true ),
	'collapsibletabs' => array( 'global' => true, 'user' => false ),
	// The follwing are experimental and likely unstable - use at your own risk
	'expandablesearch' => array( 'global' => false, 'user' => false ),
	'footercleanup' => array( 'global' => false, 'user' => false ),
	'sectioneditlinks' => array( 'global' => false, 'user' => false ),
);

// The Vector skin has a basic version of simple search, which is a prerequisite for the enhanced one
$wgDefaultUserOptions['vector-simplesearch'] = 1;

// Enable bucket testing for new version of collapsible nav
$wgCollapsibleNavBucketTest = false;
// Force the new version
$wgCollapsibleNavForceNewVersion = false;

// Enable bucket testing for new version of section edit links
$wgVectorSectionEditLinksBucketTest = false;
// Percentage of users who's use of section edit links will be tracked - half of which will see the
// new section edit links - default 5%
$wgVectorSectionEditLinksLotteryOdds = 5;
// Version number of the current experiment - Buckets from previous experiments will be overwritten
// with new values when this is incremented, so as to allow accurate re-distribution. When changing
// the lottery odds, this needs to change too, or you will have inaccurate data.
$wgVectorSectionEditLinksExperiment = 0;

/* Setup */

$wgExtensionCredits['other'][] = array(
	'path' => __FILE__,
	'name' => 'Vector',
	'author' => array( 'Trevor Parscal', 'Roan Kattouw', 'Nimish Gautam', 'Adam Miller' ),
	'version' => '0.3.0',
	'url' => 'https://www.mediawiki.org/wiki/Extension:Vector',
	'descriptionmsg' => 'vector-desc',
);
$wgAutoloadClasses['VectorHooks'] = dirname( __FILE__ ) . '/Vector.hooks.php';
$wgExtensionMessagesFiles['Vector'] = dirname( __FILE__ ) . '/Vector.i18n.php';
$wgHooks['BeforePageDisplay'][] = 'VectorHooks::beforePageDisplay';
$wgHooks['GetPreferences'][] = 'VectorHooks::getPreferences';
$wgHooks['ResourceLoaderGetConfigVars'][] = 'VectorHooks::resourceLoaderGetConfigVars';
$wgHooks['MakeGlobalVariablesScript'][] = 'VectorHooks::makeGlobalVariablesScript';

$vectorResourceTemplate = array(
	'localBasePath' => dirname( __FILE__ ) . '/modules',
	'remoteExtPath' => 'Vector/modules',
	'group' => 'ext.vector',
);
$wgResourceModules += array(
	// TODO this module should be merged with ext.vector.collapsibleTabs
	'jquery.collapsibleTabs' => $vectorResourceTemplate + array(
		'scripts' => 'jquery.collapsibleTabs.js',
		'dependencies' => 'jquery.delayedBind',
	),
	'ext.vector.collapsibleNav' => $vectorResourceTemplate + array(
		'scripts' => 'ext.vector.collapsibleNav.js',
		'styles' => 'ext.vector.collapsibleNav.css',
		'messages' => array(
			'vector-collapsiblenav-more',
		),
		'dependencies' => array(
			'mediawiki.util',
			'jquery.client',
			'jquery.cookie',
			'jquery.tabIndex',
		),
	),
	'ext.vector.collapsibleTabs' => $vectorResourceTemplate + array(
		'scripts' => 'ext.vector.collapsibleTabs.js',
		'dependencies' => array(
			'jquery.collapsibleTabs',
			'jquery.delayedBind',
		),
	),
	'ext.vector.expandableSearch' => $vectorResourceTemplate + array(
		'scripts' => 'ext.vector.expandableSearch.js',
		'styles' => 'ext.vector.expandableSearch.css',
		'dependencies' => array(
			'jquery.client',
			'jquery.expandableField',
			'jquery.delayedBind',
		),
	),
	'ext.vector.footerCleanup' => $vectorResourceTemplate + array(
		'scripts' => array(
			'jquery.footerCollapsibleList.js',
			'ext.vector.footerCleanup.js',
		),
		'styles' => 'ext.vector.footerCleanup.css',
		'messages' => array (
			'vector-footercleanup-transclusion',
			'vector-footercleanup-templates',
			'vector-footercleanup-categories',
		),
		'dependencies' => array(
			// The message require plural support at javascript.
			'mediawiki.jqueryMsg',
			'jquery.cookie'
		),
		'position' => 'top',
	),
	'ext.vector.sectionEditLinks' => $vectorResourceTemplate + array(
		'scripts' => 'ext.vector.sectionEditLinks.js',
		'styles' => 'ext.vector.sectionEditLinks.css',
		'dependencies' => array(
			'jquery.cookie',
		),
	),
);

