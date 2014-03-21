#!/bin/bash -e
# -e option: Error out on any command/pipeline error

# arguments: repo list
PROJ_LIST="$*"  

GERRIT_SITE="https://review.trafodion.org"
ZUUL_SITE="http://zuul.trafodion.org"
GIT_ORIGIN="${GERRIT_SITE}/p"
GIT_ZUUL="${ZUUL_SITE}/p"

if [ -z "$ZUUL_REF" ]
then
    echo "******************************************"
    echo "Warning: Job not triggered by Zuul."
    echo "         Defaulting to master branch."
    echo "******************************************"
    ZUUL_BRANCH="master"
    ZUUL_REF="None"
fi

if [ ! -z "$ZUUL_CHANGE" ]
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

set -x   
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
      if [[ "$repo" == "$ZUUL_PROJECT" ]]
      then
        echo "Could not find Zuul change $ZUUL_REF for $repo"
	exit 3
      fi
      git checkout -f $branch
      git reset --hard remotes/origin/$branch
    fi

    git clean -x -f -d -q

done

exit 0
