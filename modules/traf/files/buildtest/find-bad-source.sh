#!/bin/bash
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

egrepcmd="egrep -rnH -e'<<<<<<<.*HEAD|>>>>>>>>.*HEAD'"

usage()
{
  cat <<==EOF==

Usage: $(basename $0) [-q] [<commit-id> ]

 <commit-id>	If omitted, use origin/\${ghprbTargetBranch}..\${ghprbActualCommit}.

 -d <dir>	Directory to check (default: ".")

 -q		Quiet mode.  Do not report all examined files
		and the context for the found lines.

Search source files for bad strings using this command:

	$egrepcmd

This should be run at the top level of a git repo.

==EOF==
  exit $1
}

CTR=0
DELETED=0
MAXINGREP=5000
fList=
VERBOSE=y
WDIR="."
TMPFILE=/tmp/ChangedFilesToScan.$$

while [[ $# -gt 0 ]]; do
	ANARG=$1
	case $1 in
  -h|-help|--h|--help)
		usage 0
		;;
  -q|--quiet)	VERBOSE=
		;;
  -d)		WDIR="$2"
                shift 1
		;;
  -*|--*)	echo "ERROR: Unrecognized option : $ANARG" >&2
		usage 1
		;;
  *)		break
		;;
	esac
	shift 1
done
COMMIT=$1
if [[ -z "$COMMIT" ]]; then
  COMMIT="origin/${ghprbTargetBranch}..${ghprbActualCommit}"
fi

source /usr/local/bin/traf-functions.sh
log_banner

cd "$WDIR"

listcmd="git show --pretty=format:%n --name-status $COMMIT"
echo "File list command: $listcmd"
$listcmd | sort -u > $TMPFILE

while read fStatus fName; do
  if [[ -n "$fName" ]]; then
    if [[ "$fStatus" == "D" ]]; then
      DELETED=$(( DELETED + 1 ))
      continue
    fi
    CTR=$(( CTR + 1 ))
    if [[ $CTR -le $MAXINGREP ]]; then
      fList="$fList $fName"
    fi
  fi
done < $TMPFILE
rm -f $TMPFILE

LISTLEN=$(echo "$fList" | wc -w)
if [[ $LISTLEN -eq 0 ]]; then
  echo "No files to examine."
  echo "Number of deleted files = $DELETED"
  exit 0
elif [[ $LISTLEN -ne $CTR ]]; then
  echo "Number of files exceeds limit, searching only first $MAXINGREP files"
fi

echo "Number of files to examine = $LISTLEN"
if [[ -n "$VERBOSE" ]]; then
  echo "Files to examine:"
  echo "$fList" | fmt -w1
  echo
fi

echo "Search command: $egrepcmd"
echo

# Find lines, but ignore this script
LINESSEEN=$(eval $egrepcmd $fList 2>/dev/null | grep -v $(basename $0) | wc -l)
if [[ $LINESSEEN -gt 0 ]]; then
  FILESSEEN=$(eval $egrepcmd $fList 2>/dev/null | grep -v $(basename $0) | cut -f1 -d: | sort -u)
  FILESCOUNT=$(echo $FILESSEEN | wc -w)
  echo "ERROR: Found pattern which should not be in source, in $LINESSEEN lines(s) in $FILESCOUNT file(s)."
  echo
  echo "File(s) with bad pattern ="
  echo $FILESSEEN | fmt -w1
  if [[ -n "$VERBOSE" ]]; then
    echo
    echo "Lines with context are:"
    echo
    eval $egrepcmd -C 4 $fList 2>/dev/null
  fi
  exit 2
else
  echo "Success! Found no bad lines."
fi
