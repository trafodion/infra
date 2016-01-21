#!/bin/bash

# Buckets
# to start, we only care about docs/ vs everything else
# we categorize based on path, and include all changes (add, delete, modified)


TMPFILE=/tmp/ChangedFilesToScan.$$
RESFILE="$WORKSPACE/bucket.properties"

rm -rf $RESFILE
touch $RESFILE  # creae file if nothing else

COMMIT=$1
if [[ -z "$COMMIT" ]]; then
  COMMIT="${sha1}"
fi

source /usr/local/bin/traf-functions.sh
log_banner

cd "$WORKSPACE"

# To get change-list we are doing log of PR commit versus target branch
# If we did diff, we'd see any files merged since we branched. This way we see
# only files touched in this branch. However, this does include files that might
# have been reverted in a later commit. In that small case, we are a little conservative.
listcmd="git log --pretty=format:%n --name-only origin/${ghprbTargetBranch}..$COMMIT"
echo "File list command: $listcmd"
$listcmd > $TMPFILE

DOCS=0
NONDOCS=0
while read fName; do
  if [[ -n "$fName" ]]; then
    if [[ $fName =~ ^docs/|^pom.xml ]]
    then
      (( DOCS+=1 ))
    else
      (( NONDOCS+=1 ))
    fi
  fi
done < $TMPFILE
rm -f $TMPFILE

echo "Found $DOCS docs/ file changes"
echo "Found $NONDOCS other file changes"

if (( $DOCS > 0 ))
then
  echo "BUCKET_DOC = true" >> $RESFILE
else
  echo "BUCKET_DOC = false" >> $RESFILE
fi
if (( $NONDOCS > 0 ))
then
  echo "BUCKET_NONDOC = true" >> $RESFILE
else
  echo "BUCKET_NONDOC = false" >> $RESFILE
fi

exit 0
