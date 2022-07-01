#!/bin/bash
set -eo pipefail 
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
#fetch defaults
[[ -f ${script_dir%/*}/.env ]] && source ${script_dir%/*}/.env # (look for .env 1 dir up )
# returns info on a disk img, such as FileFormat, parent, children, etc.
###TODO SECTION:
### Move functions
### Update help message 
# simple help message
help() {
  echo "valid commands are test & com
  use COMMAND --help or COMMAND -h for usage"
  exit 1
}

# use qemu-img to find disk format, then return the val
getDiskFormat() { 
  qemu-img info $1 | awk '/file format:/{print $NF}' 
}

##MAIN
# if they ran this without args, they don't know what this does
[[ $# < 1 ]] && help

# shouldn't be used by people, so we can be pretty explicit in parsing
case $1 in
  # if it starts with a hyphen it's an option, ignore it
  -* ) continue ;;
  # otherwise if it's a known command, run the appropriate script
  format )  getDiskFormat $2 ;;
  # else print help message
  ? ) help ;;
esac

# Good Job!
exit 0