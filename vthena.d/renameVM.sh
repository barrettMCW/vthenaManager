#!/bin/bash
# Renames a given vm
set -eo pipefail 
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
#fetch defaults
[[ -f $script_dir/.env ]] && source $script_dir/.env

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

# prints a help message
help() {
  echo "
Usage: vthena name [-h] (arg1=_master) arg2
Renames a given vm.
Available options:
-h, --help      Print this help and exit"
  exit 1
}

##MAIN
main() {
  # all this just for a move command smh
  mv $VTHENA_DIR/$1 $VTHENA_DIR/$2
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
[[ $# < 1 ]] && die "What did you want? Look at help."
[[ $# > 2 ]] && die "Woah too many params, don't use spaces in names and use help if you're lost"

# if one param they want to rename _master, shift desired name and input _master
if [[ $# == 2 ]]; then 
  old=$1
  new=$2
else
  old=_master
  new=$1
fi

# check that vm exists
[[ $($script_dir/util/searchVM.sh $old) != $old ]] && \
  die "VM not found. Do you even have a master vm?"

# check that the new vm doesn't exist
[[ $($script_dir/util/searchVM.sh $new) == $new ]] && \
  die "You already used that name, try a different one"

# pass all the arguments to main or die
main $old $new && exit 0 || die "something went wrong in main" 