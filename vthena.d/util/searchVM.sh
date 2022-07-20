#!/bin/bash
# Takes one arg and checks if any vms in VTHENA_DIR matches
set -eo pipefail 
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
#fetch defaults
[[ -f ${script_dir%/*}/.env ]] && source ${script_dir%/*}/.env # (look for .env 1 dir up )

##FUNCTIONS
# very cheap error logging
die() { 
  echo "$*" >&2 
  exit 2
}

##MAIN
main() {
  # get list of vms
  local createdVMs=$($script_dir/listVMs.sh)
  # check each val and return the match
  local val
  for vm in $createdVMs; do 
    [[ $vm == $1 ]] && val=$1 && break
  done
  echo $val
  return 0
}

# check arg count
[[ $# < 1 ]] && die "Too few args"
[[ $# > 1 ]] && die "Script currently limited to 1 vm to search with"
 
# pass all the arguments to main and send exit code
main $@ && exit 0 || die "something went wrong in main" 