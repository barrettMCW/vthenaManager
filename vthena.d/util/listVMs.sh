#!/bin/bash
set -eo pipefail 
trap cleanup SIGINT SIGTERM ERR EXIT
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
#fetch defaults
[[ -f ${script_dir%/*}/.env ]] && source ${script_dir%/*}/.env # (look for .env 1 dir up )

# safely exits in the middle of the script
cleanup() {
  # don't let them quit the quit cleaner
  trap - SIGINT SIGTERM ERR EXIT
  exit
}

##MAIN
main() {
  # Add the name of every dir under VTHENA_DIR to an array
  local i=1 
  local names=()
  for path in $VTHENA_DIR/*/; do
    local dir=${path%/} # VTHENA_DIR/name/ to VTHENA_DIR/name
    local name=${dir##*/}
    names[$i]=$name
    ((i++))
  done
  #"return" names
  echo ${names[@]}
  # Good Job!
  return 0
}

# pass all the arguments to main and send exit code
main $@ && exit 0 || die "something went wrong in main" 