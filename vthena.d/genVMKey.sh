#!/bin/bash
set -eo pipefail 
trap die SIGINT SIGTERM ERR EXIT
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
[[ -f $script_dir/vthena.d/.env ]] && source $script_dir/vthena.d/.env
#This script just stores 
##FUNCTIONS
# safely exits in the middle of the script
die() {
  echo $*
  exit 1
}
export VTHENA_DIR=$HOME/vthena
##MAIN
main() {
  local pass
  while true; do
    echo "What password did you set for $2"
    read 
    [[ $REPLY =~ ^[A-Za-z0-9]*$ ]] && \
      pass=$REPLY && break
  done
  while true; do
    echo "Confirm your password"
    read 
    [[ $REPLY != $pass ]] && \
      die "Passwords didn't match. Exiting" || \
      break
  done
  # security is irrelevent here, they're just vm's to run tests on.
  echo pass > $VTHENA_DIR/$1/$2.key
  #Good Job!
  return 0
}

# check input vals 
[[ $# < 2 ]] && die "You need to give a vm and a username"
[[ $# > 2 ]] && die "Too many args"

# check it's a real vm
[[ $($script_dir/util/searchVM.sh $1) != $1 ]] && die "VM not found"

# pass all the arguments to main and send exit code
main $@ && exit 0 || die "something went wrong in main" 