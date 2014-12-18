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

source /usr/local/bin/traf-functions.sh
log_banner

rc=0   #so far, so good

text_pat='ASCII|UTF-|FORTRAN|empty|very short file \(no magic\)|Deleted|text|symbolic link'
image_pat='image|icon|data|PC bitmap'
size_limit=80000  #image file limit in bytes
TMPFILE=/tmp/BinaryCheckFileList.$$

listcmd="git show --pretty=format:%n --name-status HEAD"

echo "File list command: $listcmd"
$listcmd > $TMPFILE

echo "'file' command reports:"
while read fStatus fName
do
  if [[ -n "$fName" ]]; then
    if [[ "$fStatus" == "D" ]]; then
      ftype="Deleted"
    else
      ftype=$(file -b "$fName")
    fi
    echo "$fName : $ftype"

    # Image file
    if [[ "$ftype" =~ $image_pat ]]
    then
      fsize=$(stat -c %s "$fName")
      if [[ $fsize -gt $size_limit ]]
      then
        echo "  ERROR: Image/data file size $fsize bytes greater than $size_limit"
	rc=1
      else
        echo "  Image/data file size $fsize bytes okay"
      fi
    elif [[ ! ("$ftype" =~ $text_pat) ]]
    then
      echo "  ERROR: Unknown file type not allowed"
      rc=1
    fi
  fi
done < $TMPFILE

rm -f $TMPFILE

exit $rc
