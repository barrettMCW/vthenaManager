#!/bin/bash
set -eo pipefail 
trap cleanup SIGINT SIGTERM ERR EXIT
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
#fetch defaults
[[ -f $script_dir/.env ]] && source $script_dir/.env
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
  rm -r $env
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

# This checks the VM_OUT for important information, then will send it to a handler if necessary.
parseOutput(){
  echo $1
  [[ $1 == "Booting" ]] && sleep 5 && printf "\n\n" > $VM_IN
  [[ $1 == "login: " ]] && echo "root\n" > $VM_IN
}

##MAIN
main() {
  # workdir
  env=/tmp/$1
  mkdir $env

  # make a pipe
  VM_IN=$env/$SCRIPT_USER.in 
  VM_OUT=$env/$SCRIPT_USER.out
  mkfifo $VM_IN $VM_OUT

  # start the vm
  $script_dir/watchVM.exp `$script_dir/startVM.sh -m 6g -x "-serial pipe:$env/$SCRIPT_USER" $RUN_ARGS $1`
  
  # Watch the vm until it dies
  while read line; do
    [[ -n $VERBOSE ]] && echo "${line}"
    parseOutput $line
  done < $VM_OUT

  # Good Job!
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
    p | passthrough ) RUN_ARGS=$OPT ;; 
    h | help )        help ;;
    ??* )             die "Illegal option --$OPT" ;;  # bad long option
    ? )               exit 2 ;;  # bad short option (error reported via getopts)
  esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list
echo $@
# check input vals 
[[ $# < 2 ]] && die "Needs vm to run on and script to run"
[[ $# > 2 ]] && die "Woah. Too many args"

# if first arg isn't a vm, die
[[ $1 != $($script_dir/util/searchVM.sh $1) ]] && die "VM not found"

# if second arg isn't an executable, check global experiments, if still can't find, die
[[ -x $2 ]] && experiment=$2 || \
  experiment=$(find $script_dir/experiments -name "$2.*" -executable -print -quit)
  
[[ ! -x $experiment ]] && die "Experiment not found"

# default user is root
[[ -z $SCRIPT_USER ]] && SCRIPT_USER=root

# we need a key file to log in
[[ ! -f $VTHENA_DIR/$1/$SCRIPT_USER.key ]] && die "No key for: $SCRIPT_USER! Try: vthena key VM_NAME USER"

# pass all the arguments to main and send exit code
main $1 && exit 0 || die "something went wrong in main" 