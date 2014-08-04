#!/usr/bin/perl
# @@@ START COPYRIGHT @@@
#
# (C) Copyright 2011-2014 Hewlett-Packard Development Company, L.P.
#
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
# @@@ END COPYRIGHT @@@

use strict;
use File::Find;
use File::Basename;
use Getopt::Long;

my $defaultDir = "/home/jenkins/workspace";

sub Usage {

my $scriptName = basename($0);
print STDERR <<EOF

Find core files in the specified directories.

Usage : $scriptName  [ --help               ]
                           [ --xml                ]
                           [ --0                  ]
                           [ --aliasname <alias>  ]
                           [ --aliasshort <short> ]
                           [ --debug              ]
                           [ <dir> ... ]

       <dir> ...               Find core files within these directories.
                               If no directories are supplied, then search $defaultDir

       --xml                   Generate XML output, otherwise just list the files

       --0                     If true AND --xml is not used, then output chr(0) instead of "\\n"

       --aliasname <alias>     Report system is <alias> instead of hostname

       --aliasshort <short>    Report short system is <short> instead of hostname -s

       --debug                 Output debugging information on STDERR

       --help                  Emit this help text and exit

The core file names are made with /proc/sys/kernel/core_pattern.
This script looks for files made when core_pattern is  core.%h.%p.%e

EOF
;
}

my $aliasName = '';     # Use this instead of hostname
my $aliasShort = '';    # Use this instead of hostname -s
my $realHostName = '';	# Hostname without alias

my $debugFlag = 0;      # Output extra debugging information on STDERR
my $zeroFlag = 0;       # if true AND xmlFlag is off, then output chr(0) instead of "\n"
my $xmlFlag = 0;        # if true, generate XML output, otherwise just list the files
my $helpFlag = 0;
my $_nl="\n";
my $status = GetOptions(
        'aliasname=s'   => \$aliasName,
        'aliasshort=s'  => \$aliasShort,
        'debug!'        => \$debugFlag,
        'xml!'          => \$xmlFlag,
        'help!'         => \$helpFlag,
        '0!'            => \$zeroFlag,
);

(&Usage(), exit(0)) if $helpFlag;

$_nl=chr(0) if ($zeroFlag && ! $xmlFlag);

if ( $debugFlag ) {
	print STDERR "Debugging on\n";
}

$::gCurrentDirectoryForFind = '';

#
# Turn off buffering - increases possibility that, if we stop because of a timeout,
# the resulting XML will be relatively easily repaired ;;
#  just close every open element in reverse order
#
my $tmpfh;
   $tmpfh = select(STDERR) ; $| = 1 ; select($tmpfh);
   $tmpfh = select(STDOUT) ; $| = 1 ; select($tmpfh);

my %FileList;
my @SubdirList;

sub commonPrefix
{
my @buffer = ();
	return '' unless @_ > 1;
	my $minString = undef;
	map { $minString = $_ unless defined($minString); $minString = $_ if length($_) < length($minString); $_ } ( @_ );
	my @letters = split(//, $minString);
	foreach my $l (@letters)
	{
		my $t = join('',@buffer, $l);
		foreach my $s (@_) {
			return join('', @buffer) unless $s =~ /^\Q${t}\E/;
		}
		push @buffer, $l;
	}
	return join('', @buffer);
}
sub commonSuffix
{
	return '' unless @_ > 1;
	return join('', reverse split(//, &commonPrefix(map { join('', reverse split(//, $_)); } (@_)) ));
}
sub showDir
{
my $Dir = $_[0];

	my $escapedSpaces = $Dir;
	   while ( $escapedSpaces =~ s/(\s)/\\$1/g ){};
	my $lsld = qx(ls -ld $escapedSpaces);
	chomp($lsld);

	my @Files = ();
	if (exists $FileList{$Dir} ){
		@Files = @{$FileList{$Dir}};
	}

	if (! $xmlFlag) {
		foreach my $aFile ( sort @Files) {
			print $aFile . $_nl;
		}
		return;
	}

	my %subdirGroups = ();
	map { push @{$subdirGroups{dirname($_)}}, basename($_); } (sort @Files);

	print	'<dir name="' . $Dir . '" searchdir="' . $::gCurrentDirectoryForFind . '">'               . "\n";
	print	'<lsld><![CDATA[' . $lsld . ']]></lsld>'                                                  . "\n";
	print	'<files count="' . scalar @Files . '" subdircount="' . (scalar keys %subdirGroups) . '">' . "\n";

	foreach my $subdirGroup ( sort keys %subdirGroups ) {

		my @SubdirFiles = @{$subdirGroups{$subdirGroup}};

		print	'<subdir>'                                                           . "\n";
		print	'<subdirpath><![CDATA[' . $subdirGroup . ']]></subdirpath>'          . "\n";
		my ($commonPrefix, $commonSuffix) = ( &commonPrefix(@SubdirFiles), &commonSuffix(@SubdirFiles));
		print	'<subfiles '       .
			'count="'          . scalar @SubdirFiles .
			'" commonPrefix="' . $commonPrefix .
			'" commonSuffix="' . $commonSuffix .
			'" items="'        . join(",", map { s/^\Q${commonPrefix}\E(.*)\Q${commonSuffix}\E$/$1/; while(s/([^\\]),/$1\\,/g){}; $_; } (@SubdirFiles) ) .
			'"/>' . "\n";
		print	'</subdir>'                                                          . "\n";
	}

	print	'</files>'                                                    . "\n";
	print	'</dir>'                                                      . "\n";
	$|=1;
}

sub wanted_normal_nochdir
{
	if( -d ) {
		if ( m{/\.svn$} ) {
			$File::Find::prune = 1;
		} else {
			if (m{^\Q$::gCurrentDirectoryForFind\E$}) {
				my $A = $::gCurrentDirectoryForFind;
				if ( ! exists($FileList{$A}) ) {
					push @SubdirList, $A;
					@{$FileList{$A}} = ();
				}
			}
		}
	}
	# 0  /  1 /  2 /    3   /   4  /...
	#    /home/user/instance/SUBDIR/SUBPATH
	# Search for files made when /proc/sys/kernel/core_pattern  is  core.%h.%p.%e
	elsif( -f && m{/core\.$realHostName\.\d+\.[^/]+$} )
	{
		my $A = $::gCurrentDirectoryForFind;
		my $B = $_;
		if( $B =~ m{^\Q$::gCurrentDirectoryForFind\E/(.+)} )
		{
			push @{$FileList{$A}}, $1;
		} else {
			print STDERR "WARNING: $0 : Illogical file fed to wanted function. Ignoring '$B'!";
		}
	}
}

sub main
{
	my $hostname;
	my $hostnameshort;
	$realHostName = qx(hostname -f);
	$hostname = $realHostName         if ! $aliasName;
	$hostname = $aliasName            if   $aliasName;
	$hostnameshort = qx(hostname -s)  if ! $aliasShort;
	$hostnameshort = $aliasShort      if   $aliasShort;
	chomp($realHostName);
	chomp($hostname);
	chomp($hostnameshort);
	my @dirsList;
	my @inDirs = @_;

	if ( ! scalar @_ ) {
		print STDERR "Empty input, using $defaultDir\n" if $debugFlag;
		@inDirs = $defaultDir;
	}
	foreach my $aDir (sort @inDirs) {
		if ( -d $aDir)
		{
			print STDERR "Found a directory : $aDir\n"	if $debugFlag ;
			if ($aDir =~ m!/$!) {
				print STDERR "Removing trailing slashes : $aDir\n"	if $debugFlag ;
				$aDir =~ s!/+$!!;
			}
			push @dirsList, $aDir;
		} else {
			print STDERR "Not a directory : $aDir\n"	if $debugFlag ;
		}
	}

	if ($xmlFlag) {
		print '<machine>' . "\n";
		print '<hostname><![CDATA[' . $hostname . ']]></hostname>' . "\n";
		print '<searchdirs><![CDATA[' . join(' ', @dirsList) . ']]></searchdirs>' . "\n";
		print '<searchpattern><![CDATA[core.' . $realHostName . q{.*} . ']]></searchpattern>' . "\n";
		print '<dirs>' . "\n";
	}

	foreach $::gCurrentDirectoryForFind (@dirsList) {

		print STDERR "Searching $::gCurrentDirectoryForFind\n"	if $debugFlag ;
		@SubdirList = ();
		%FileList   = ();
		find( {
			'wanted'	=>	\&wanted_normal_nochdir,
			'no_chdir'	=>	1,
			}, $::gCurrentDirectoryForFind
		);
		foreach my $Dir ( sort @SubdirList ) {
			&showDir( $Dir );
		}
	}
	print '</dirs>' . "\n"     if $xmlFlag;
	print '</machine>' . "\n"  if $xmlFlag;
}

&main( @ARGV );
