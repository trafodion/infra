## Common Build/Test Shell functions

# source_env - find and source env file
# Caller must be in correct source tree current dir (trafodion/core/sqf)
# parameter is build flavor: release or debug
# leave parameter blank to use prior build flavor
function source_env () {

  # tracing on?
  if [[ $(set -o | grep ^xtrace) =~ .*off ]]
  then  
    TracingWasOn=0
  else
    TracingWasOn=1
    set +x
  fi

  # If no flavor specified, has a flavor been specified previously?
  if [[ -z "$1" && -r ./BuildFlavor ]]
  then
    ENVfile=$(< ./BuildFlavor)
  elif [[ "$1" =~ r.* ]]   # anything beginning with r, is "release"
  then
    ENVfile="sqenvr.sh"
  else			   # default to debug
    ENVfile="sqenvd.sh"
  fi
  # if no build "flavor" env file, then use "default" (installed instead of build tree)
  if [[ ! -r ./$ENVfile ]]
  then
    ENVfile="sqenv.sh"
  fi

  # Save flavor used for later calls
  echo "$ENVfile" > ./BuildFlavor

  echo "Sourcing ./$ENVfile"
  SQ_VERBOSE=1
  export TOOLSDIR=/opt/traf/tools
  source ./$ENVfile
  rc=$?

  if (( $TracingWasOn ))
  then
    set -x
  fi
  return $rc
}

# modify_env - find and source env file
# Caller must be in correct source tree current dir (trafodion/core/sqf)
# source_env must have been called previously (to create BuildFlavor file)
function modify_env() {
  ENVfile=$(< ./BuildFlavor)
  ADDITION="$1"
  if [[ ! -w ./$ENVfile ]]
  then
    echo "Error: ./$ENVfile is not write-able"
    return 1
  fi

  if ! grep -q "$ADDITION" ./$ENVfile
  then
     echo "Adding env: $ADDITION"
     echo "$ADDITION" >> ./$ENVfile
     return $?
  else
     echo "Env already contains: $ADDITION"
     return 0
  fi

}
