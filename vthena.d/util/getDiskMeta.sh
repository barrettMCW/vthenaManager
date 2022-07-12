#!/bin/bash
# returns info on a disk img
set -eo pipefail 
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
#fetch defaults
[[ -f ${script_dir%/*}/.env ]] && source ${script_dir%/*}/.env # (look for .env 1 dir up )

# very cheap error logging
die() { 
  echo "$*" >&2 
  exit 2
}

# use qemu-img to find disk format, then return the val
main() { 
  qemu-img info $1 | awk -v key=$KEY '/key/{print $NF}' 
}

##MAIN
# check arg amount
[[ $# < 1 ]] && die "Too few arguments passed to $(basename ${BASH_SOURCE[0]})"
[[ $# > 2 ]] && die "Too many arguments passed to $(basename ${BASH_SOURCE[0]})"

# shouldn't be used by people, so we can be pretty explicit in parsing
case $1 in
  # store command as a qemu-img key
  format | fmt )            KEY="file format:" ;;
  image | img )             KEY="image:" ;;
  capacity | cap | vsize )  KEY="virtual size:" ;;
  size | usage | dsize )    KEY="disk size:" ;;
  cluster | csize )         KEY="cluster_size:" ;;
  # qcow2
  compression | comp )      KEY="compression type:" ;;
  corrupt | corr )          KEY="false" ;;
  l2 | extended )           KEY="extended" ;;
  # else unknown val
  ? ) die "unknown meta value: $1 passed to $(basename ${BASH_SOURCE[0]})" ;;
esac
# awk out the value 
main $2
# Good Job!
exit 0