#!/bin/bash
set -eo pipefail 
trap cleanup SIGINT SIGTERM ERR EXIT
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
source $script_dir/.env
# Clones a given vm
##FUNCTIONS
# very cheap error logging
die() { 
  echo "$*" >&2 
  exit 2
}

# demands a value for an option 
needs_arg() { 
  [[ ! "$OPTARG" ]] && \
    die "No arg for --$OPT option" 
  return 0
}

# safely exits in the middle of the script
cleanup() {
  # don't let them quit the quit cleaner
  trap - SIGINT SIGTERM ERR EXIT

  exit 
}

# prints a help message
help() {
  echo "
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-f] -p param_value arg1 [arg2...]
Script description here.
Available options:
-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-f, --flag      Some flag description
-p, --param     Some param description"
  exit 1
}

##MAIN
main() {
  # rename old master vm
  [[ -d $VTHENA_DIR/_master/ ]] && \
    mv $VTHENA_DIR/_master/ $VTHENA_DIR/old_master/ || echo "Setting master for the first time!"

  # rename desired vm 
  [[ -d $VTHENA_DIR/$1/ ]] && \
    mv $VTHENA_DIR/$1/ $VTHENA_DIR/_master || die "We thought we saw your vm, but now it's not there! This is disasterous."

  # delete old master
  [[ -d $VTHENA_DIR/old_master/ ]] && \
    rm -r $VTHENA_DIR/old_master/

  #Good Job!
  return 0
}
# first parse your options
while getopts h-: OPT; do
  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi 
  case "$OPT" in
    h | help )     help ;;
    ??* )          die "Illegal option --$OPT" ;;  # bad long option
    ? )            exit 2 ;;  # bad short option (error reported via getopts)
  esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list

# check input quantity
[[ $# < 1 ]] && die "Which vm did you want to make master?"
[[ $# > 1 ]] && die "Woah now, just one param please."

# check that vm exists
[[ $($script_dir/util/searchVM.sh $1) != $1 ]] && die "VM not found. Check spelling and vm dir"

# pass all the arguments to main and send exit code
main $@ && exit 0 || die "something went wrong in main" 