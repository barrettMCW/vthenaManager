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
  # report
  echo "Cloning $1 as $2"

  # copy files
  cp -r $VTHENA_DIR/$1 $VTHENA_DIR/$2

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

# Check input params
# if they gave 2 params
if [[ $# == 2 ]]; then
  # if param does not exist, quit
  [[ $1 != $($script_dir/util/searchVM.sh $1) ]] && die "Couldn't find specified vm, check your vm directory"
elif [[ $# == 1 ]]; then
  # if there is no dir named _master, then we don't know what they want from us
  [[ _master != $($script_dir/util/searchVM.sh _master) ]] && die "No base vm provided and you haven't set a master copy"
  # shift cloneName and make _master the clone base
  $2=$1 && $1=_master
else 
  # else they used a wrong amount of params
  help
fi

# if vm already exists quit
[[ $createdVMs == *\ $2\ * ]] && die "VM already exists! Use a different name."

# pass all the arguments to main and send exit code
main $@ && exit 0 || die "Something went wrong in main" 