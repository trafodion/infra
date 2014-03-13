#!/bin/sh 

DIR="$ZUUL_PIPELINE"
if [[ $DIR != "release" && $DIR != "pre-release" ]]
then
  echo "Only valid for release & pre-release pipelines, not $DIR"
  exit 1
fi

# What Tag are we publishing?
TAG=${ZUUL_REF#refs/tags/}
if [[ -z "$TAG" ]]
then
  echo "No tag name found in ref: $ZUUL_REF"
  exit 1
fi
if [[ ! ("$TAG" =~ ^[0-9].*) ]]
then
  echo "Tag name does not begin with release number: $TAG"
  exit 1
fi

set +x

# Clean up any previous label directories
rm -rf release pre-release


mkdir -p $DIR/$TAG || exit 2

cp trafodion/core/traf*.tgz $DIR/$TAG/  || exit 2

exit 0

