#!/usr/bin/perl
# @@@ START COPYRIGHT @@@
#
# (C) Copyright 2014 Hewlett-Packard Development Company, L.P.
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
#
# This script parses the output from Puppet's call to rsync to figure out
# which .gz were updated and then untars those files only.
#

use strict;
use warnings;

use Getopt::Long;

# Default values of the 2 command line arguments
my $rsync_out = "/opt/traf/build-tool-gz/rsync.out";
my $top_dir = "/opt/traf";
my @array;
my @filename;
my $tar_cmd;
my $status;

&Getopt::Long::Configure('bundling');
&usage if !&GetOptions(
    'file|f=s' => \$rsync_out,
    'directory|d=s' => \$top_dir,
);

print "Opening $rsync_out\n";
open(LOG, "$rsync_out") or die "Error opening rsync log file: $rsync_out $!\n";

print "Top level directory to work on is $top_dir\n";

chdir($top_dir) or die "Error: Cannot change directories to $top_dir\n";

while (<LOG>) {
   # Example rsync output lines, we only want the ones with 'recv' and a tar.gz file
   # In this example that's the one with bison_3_linux.tar.gz
   # 2014/01/26 16:57:45 [20660] receiving file list
   # 2014/01/26 16:57:45 [20660] ./
   # 2014/01/26 16:57:45 [20662] recv --- ./
   # 2014/01/26 16:57:45 [20662] recv --- bison_3_linux.tar.gz
   # 2014/01/26 16:57:45 [20662] sent 33 bytes  received 972.51K bytes  1.95M bytes/sec
   # 2014/01/26 16:57:45 [20662] total size is 546.22M  speedup is 561.64

   # TODO: combine next to 'if' statements into one with proper search string
   if ($_ =~ m/ recv --- /) {
      if ($_ =~ m/tar.gz$/) {
        @array = split /\s*---\s*/, $_;
        # need to remove eol char from $array[1]
        @filename = split /$/, $array[1];
        print "Received $filename[0] which now needs to be un-tar'd\n";
        $tar_cmd = "/bin/tar -C tools -xvzf $filename[0]";
        # $status = system($tar_cmd) or die("Failed to run \"$tar_cmd\": $!");
        system($tar_cmd) == 0
          or die "system $tar_cmd failed: $?";
      }
   }
}
close LOG;


sub usage
{
    die <<EOT;
USAGE: $0 -f <filename> -d <directory>

  where:
    <filename>    is the name of the rsync log output with log format expected to be:
                    --log-file-format="%o --- %n"
                  Fully qualify the name.
    <directory>   is the name of the directory which contains the directory of tool tarballs that
                  might need to be untar'd and the directory where the build tools are installed.
                  For example: /opt/traf which contains both build-tool-gz/ and tools/.
EOT
}
