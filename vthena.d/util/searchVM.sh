#!/bin/bash
set -eo pipefail 
trap cleanup SIGINT SIGTERM ERR EXIT
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
source ${script_dir%/*}/.env # (look for .env 1 dir up )

# safely exits in the middle of the script
cleanup() {
  # don't let them quit the quit cleaner
  trap - SIGINT SIGTERM ERR EXIT
  exit
}

##MAIN
main() {
  # get list of vms
  local createdVMs=$($script_dir/listVMs.sh)
  local val #define return variable
  # check each val and return the match
  for vm in $createdVMs; do 
    [[ $vm == $1 ]] && val=$1
  done
  echo $val
  return 0
}

# pass all the arguments to main and send exit code
main $@ && exit 0 || die "something went wrong in main" 