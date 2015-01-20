#!/bin/bash -x
# @@@ START COPYRIGHT @@@
#
# (C) Copyright 2015 Hewlett-Packard Development Company, L.P.
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

backupDir="/var/backups/wiki_backups"
wikiDir="/srv/mediawiki"

if [ ! -d $backupDir ]; then mkdir $backupDir; fi
cd $wikiDir

# create temporary tarball
tar cfz $backupDir/tmp.wiki.tgz w
md5sum $backupDir/tmp.wiki.tgz > $backupDir/tmp.wiki.md5
diff -q $backupDir/wiki.md5 $backupDir/tmp.wiki.md5 2>/dev/null

# if there is a difference in the md5sum of the tarball
# archive the old one if it exists, rename temporary files
# then upload tar file to object storage
if [ $? -ne 0 ]
then
  if [ -f $backupDir/wiki.tgz ]
  then
    cur_date=$(date +%Y%m%d)
    mv $backupDir/wiki.md5 $backupDir/wiki.md5.$cur_date
    mv $backupDir/wiki.tgz $backupDir/wiki.tgz.$cur_date
  fi

  mv $backupDir/tmp.wiki.md5 $backupDir/wiki.md5
  mv $backupDir/tmp.wiki.tgz $backupDir/wiki.tgz
  backupToObjectStorage.sh upload $backupDir/wiki.tgz

# if there is no difference in the md5sum of the tarball
# then remove all temporary files
else
  rm $backupDir/tmp.wiki.tgz
  rm $backupDir/tmp.wiki.md5
fi
