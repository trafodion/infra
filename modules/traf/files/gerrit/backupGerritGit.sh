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

backupDir="/var/backups/gerrit-git"
gerritGitDir="/home/gerrit2/review_site/git"
gerritGitBackupDir="/home/gerrit2/review_site/git.backup"
gerritUser="gerrit2"

if [ ! -d $backupDir ]; then mkdir $backupDir; fi

# clone all Git repos in $gerritGitDir
if [ -d $gerritGitBackupDir ]; then rm -rf $gerritGitBackupDir; fi

sudo -u $gerritUser mkdir $gerritGitBackupDir
cd $gerritGitBackupDir
sudo -u $gerritUser mkdir trafodion
echo "Cloning All-Projects.git ..."
sudo -u $gerritUser git clone --mirror $gerritGitDir/All-Projects.git
if [ $? -ne 0 ]
then 
    echo "ERROR: Could not clone $gerritGitDir/All-Projects.git. Please check the backup job."
    exit 1
fi

cd trafodion
for i in `ls $gerritGitDir/trafodion`
do
    echo "Cloning $i ..."
    sudo -u $gerritUser git clone --mirror $gerritGitDir/trafodion/$i
    if [ $? -ne 0 ]
    then 
        echo "ERROR: Could not clone $gerritGitDir/trafodion/$i. Please check the backup job."
        exit 1
    fi
done

# create temporary tarball
tar cfz $backupDir/tmp.gerrit-git.tgz $gerritGitBackupDir
tarRes=$?
fSize=$(stat -c%s "$backupDir/tmp.gerrit-git.tgz")
if [ $tarRes -eq 0 -a $fSize -ne 0 ]
then
    md5sum $backupDir/tmp.gerrit-git.tgz > $backupDir/tmp.gerrit-git.md5
    diff -q $backupDir/gerrit-git.md5 $backupDir/tmp.gerrit-git.md5 2>/dev/null

    # if there is a difference in the md5sum of the tarball
    # archive the old one if it exists, rename temporary files
    # then upload tar file to object storage
    if [ $? -ne 0 ]
    then
      if [ -f $backupDir/gerrit-git.tgz ]
      then
        cur_date=$(date +%Y%m%d)
        mv $backupDir/gerrit-git.md5 $backupDir/gerrit-git.md5.$cur_date
        mv $backupDir/gerrit-git.tgz $backupDir/gerrit-git.tgz.$cur_date
      fi

      mv $backupDir/tmp.gerrit-git.md5 $backupDir/gerrit-git.md5
      mv $backupDir/tmp.gerrit-git.tgz $backupDir/gerrit-git.tgz
      useObjectStorage.sh -bu $backupDir/gerrit-git.tgz

    # if there is no difference in the md5sum of the tarball
    # then remove all temporary files
    else
      rm $backupDir/tmp.gerrit-git.tgz
      rm $backupDir/tmp.gerrit-git.md5
    fi
else
    echo "ERROR: $0 tar generated a 0 size backup! Please check the backup job"
fi
