## Common Build/Test Shell functions

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


############################################################
# Set common variables

# depend on standard workspace location rather than initial CWD
WORKSPACE="$HOME/workspace/$JOB_NAME"

INSTLOC="$WORKSPACE/traf_inst"
RUNLOC="$WORKSPACE/traf_run"


############################################################
# save locations of instance stuff for later use
# encapsulate use of save file into functions in this file

function install_loc () {
  rm -f "$WORKSPACE/InstallEnv.sh"
  if [[ $1 == "build" ]]
  then
    ENVloc=$WORKSPACE/trafodion/core/sqf
    ENVfile=$(< $ENVloc/BuildFlavor)
    REGloc=$WORKSPACE/trafodion/core/sql/regress
  else
    ENVloc=$RUNLOC
    ENVfile=sqenv.sh
    REGloc=$RUNLOC/sql/regress
  fi
  echo "ILOC=$ENVloc"  >  "$WORKSPACE/InstallEnv.sh"
  echo "IENV=$ENVfile" >> "$WORKSPACE/InstallEnv.sh"
  if [[ $2 == "regress" ]]
  then
    echo "RLOC=$REGloc" >> "$WORKSPACE/InstallEnv.sh"
  fi
}

# locate regress -- retrieve from save file
function loc_regress () {
  source "$WORKSPACE/InstallEnv.sh"
  echo "$RLOC"
}


############################################################
# source_env - find and source env file
#
# Option: -v -- verbose
# 1st Parameter: build | run -- build space or running instance
# 2nd Parameter: (optional) release | debug -- build flavor
# 		Leave parameter blank to use prior build flavor

function source_env () {
  # tracing on?
  if [[ $(set -o | grep ^xtrace) =~ .*off ]]
  then
    TracingWasOn=0
  else
    TracingWasOn=1
    set +x
  fi
  currentdir="$(pwd)"

  if [[ $1 == "-v" ]]
  then
    SQ_VERBOSE=1
    shift
  fi

  # test environment build tools
  export TOOLSDIR=/opt/traf/tools

  if [[ $1 == "build" ]]
  then
    cd "$WORKSPACE/trafodion/core/sqf"

    # If no flavor specified, has a flavor been specified previously?
    if [[ -z "$2" && -r ./BuildFlavor ]]
    then
      ENVfile=$(< ./BuildFlavor)
    elif [[ "$2" =~ r.* ]]   # anything beginning with r, is "release"
    then
      ENVfile="sqenvr.sh"
    else			   # default to debug
      ENVfile="sqenvd.sh"
    fi

    # Save flavor used for later calls
    echo "$ENVfile" > ./BuildFlavor

    # add this save file to the ignored file list for this workspace
    if ! grep -q sqf/BuildFlavor ../.git/info/exclude
    then
      echo "sqf/BuildFlavor" >> ../.git/info/exclude
    fi
    echo "Sourcing ./$ENVfile"
    source ./$ENVfile
    rc=$?

  elif [[ $1 == "run" ]]
  then
    source "$WORKSPACE/InstallEnv.sh"
    echo "Sourcing $ILOC/$IENV"
    cd "$ILOC"
    source "./$IENV"
    rc=$?

  else
    echo "Error: specify build or run environment"
    rc=1

  fi

  # restore environment
  if (( $TracingWasOn ))
  then
    set -x
  fi
  cd "$currentdir"

  return $rc
}

############################################################
# modify_env - add local env setting (will be sourced by ENVfile above)
#

function modify_env() {
  ADDITION="$1"

  if ! grep -q "$ADDITION" ~/.trafodion
  then
     echo "Adding env: $ADDITION"
     echo "$ADDITION" >> ~/.trafodion
     return $?
  else
     echo "Env already contains: $ADDITION"
     return 0
  fi

}

############################################################
# clear_env - clear local environment file
#
function clear_env() {
  rm -f ~/.trafodion
  return $?
}

############################################################
# report_on_corefiles - find and report on corefiles
#
# If argument supplied, use that, otherwise try the directory
# above MY_SQROOT.  The return code is the number of
# core files found.
#
function report_on_corefiles() {
  ADIR="$1"
  if [[ -z "$ADIR" ]]; then
    if [[ -n "$MY_SQROOT" ]]; then
      BDIR=$(dirname "$MY_SQROOT")
      if [[ -d "$BDIR" ]]; then
        ADIR="$BDIR"
      fi
    fi
  fi
  if [[ -z "$ADIR" ]]; then
    echo "WARNING: report_on_corefiles could not find a directory to report on"
    return 0
  fi
  CORECOUNT=0
  if [[ -d "$ADIR" ]]; then
    echo
    COREFILES=$(find-corefiles.pl "$ADIR")
    if [[ -n "$COREFILES" ]]; then
      echo "WARNING: Core files found in $ADIR :"
      pushd "$ADIR" > /dev/null
      ls -l $COREFILES
      /usr/local/bin/core_bt -t
      popd > /dev/null
      CORECOUNT=$(echo $COREFILES | wc -w)
      echo
    else
      echo "INFO: Found no core files in $ADIR"
    fi
    echo
  fi
  return $CORECOUNT
}
