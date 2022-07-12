#!/bin/bash
# searches VTHENA_DIR for .img files and returns them
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
  # Add the name of every dir under VTHENA_DIR to an array
  local i=0 
  local names=()
  for path in $VTHENA_DIR/*/; do
    local dir=${path%/} # VTHENA_DIR/name/ to VTHENA_DIR/name
    local name=${dir##*/}
    names[$i]=$name
    ((i++))
  done
  # "return" names
  echo ${names[@]}
  # Good Job!
  return 0
}

# check arg count 
[[ $# > 0 ]] && die "This command does not take args"

# pass all the arguments to main and send exit code
main && exit 0 || die "something went wrong in main @ $(basename ${BASH_SOURCE[0]})" 