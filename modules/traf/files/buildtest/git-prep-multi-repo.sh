#!/bin/bash -e
# -e option: Error out on any command/pipeline error


# option: -b branch
# Ignored unless ZUUL_REF is not set
BRANCH="master"
if [[ "$1" == "-b" ]]
then
  shift
  BRANCH="$1"
  shift
fi

# arguments: repo list
PROJ_LIST="$*"  

GERRIT_SITE="https://review.trafodion.org"
ZUUL_SITE="http://zuul.trafodion.org"
GIT_ORIGIN="${GERRIT_SITE}/p"
GIT_ZUUL="${ZUUL_SITE}/p"

if [[ -z "$ZUUL_REF" ]]
then
    echo "******************************************"
    echo "Warning: Job not triggered by code change."
    echo "         Building latest on $BRANCH branch."
    echo "******************************************"
    ZUUL_BRANCH="$BRANCH"
    ZUUL_REF="None"
fi

if [[ ! -z "$ZUUL_CHANGE" ]]
then
    echo "Triggered by: $GERRIT_SITE/$ZUUL_CHANGE"
fi

if [[ -z "$PROJ_LIST" ]]
then
    echo "Argument required -- repository list"
    exit 1
fi

export GIT_SSL_NO_VERIFY=1

workspace="$(pwd)"

# $ZUUL_PROJECT is the git repo of the change that triggered the build
# $ZUUL_REF is the git reference of compiled changes within the repo
# If there is a pipeline dependency on another repo, the same reference
# will exist there. If not we take latest on branch.

echo "Using branch: $ZUUL_BRANCH"
echo "Using reference: $ZUUL_REF"

set -x   

# Build ID across repos
BLDInfo="$ZUUL_PIPELINE Build $(date -u)"
rm -f "$workspace/Build_ID" "$workspace/Code_Versions"

if [[ $ZUUL_REF =~ ^refs/tags/ ]]
then
  BID="${ZUUL_REF#refs/tags/}"
  echo "Building for tag: $BID"
elif [[ -n "$ZUUL_CHANGE" ]]
then
  BID="$ZUUL_CHANGE"
  echo "Building for review number: $BID"
elif [[ -n "$ZUUL_PIPELINE" ]]
then
  BID="$(date -u +%Y%m%d_%H%M)"
  echo "Building for date: $BID"
else
  BID="$(date -u +%Y%m%d_%H%M)"
  echo "Building outside of Zuul for date: $BID"
fi

# Leave file around for later job steps
echo "$BID" > "$workspace/Build_ID"


# Repo-specific prep
for repo in $PROJ_LIST
do
    cd "$workspace"
    if [[ ! -e ./$repo ]]
    then
       mkdir -p ./$repo
    fi

    cd ./$repo

    if [[ ! -e .git ]]
    then
        rm -fr .[^.]* *
	git clone $GIT_ORIGIN/$repo .
    fi
    # Make sure we are pointing to right repo and fetch latest
    git remote set-url origin $GIT_ORIGIN/$repo
    if ! git remote update --prune
    then
        echo "The remote update failed, so garbage collecting before trying again."
        git gc
        git remote update --prune
    fi

    # Try to use same branch as Zuul change project, default to master
    if ! git branch -a |grep remotes/origin/$ZUUL_BRANCH>/dev/null; then
        branch=master
	ref=$(echo $ZUUL_REF | sed -e "s,$ZUUL_BRANCH,master,")
    else
        branch=$ZUUL_BRANCH
	ref=$ZUUL_REF
    fi

    # Fetch reference. if it exists, check it out, otherwise checkout latest on branch
    # clean up all the private/modified files from prior builds
    if git fetch $GIT_ZUUL/$repo $ref
    then
      git checkout -f FETCH_HEAD
      git reset --hard FETCH_HEAD
    else
      if [[ "$repo" == "$ZUUL_PROJECT" && "$ZUUL_REF" != "None" ]]
      then
        echo "Could not find Zuul change $ZUUL_REF for $repo"
	exit 3
      fi
      git checkout -f $branch
      git reset --hard remotes/origin/$branch
      ref=$branch
    fi

    git clean -x -f -d -q
    
    # leave some version info around
    echo "$BLDInfo" > build-version.txt
    echo "$repo" >> build-version.txt
    if [[ $ref =~ ^refs/tags/ ]]
    then
      echo "Tag:    ${ref#refs/tags/}" >> build-version.txt
    else
      echo "Ref:    $ref" >> build-version.txt
    fi
    echo "Commit: $(git log -n1 --format=oneline)" >> build-version.txt
    echo "Desc:   $(git describe --long --tags --dirty --always)" >> build-version.txt

    #combined list -- allows check for change from previous build
    echo "$repo $(git log -n1 --format=oneline)" >> "$workspace/Code_Versions"
done

exit 0
