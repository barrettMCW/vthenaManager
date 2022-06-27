#!/bin/bash
set -eo pipefail 
trap cleanup SIGINT SIGTERM ERR EXIT
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
source $script_dir/.env
# Creates a vm with provided iso file
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
    rm -rf $VTHENA_DIR/old_master/
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

# asks for conf, renames old _master vm which will later be deleted
handleOldMasterVM() {
  # prompt for confirmation
  read -p "This will overwrite your current _master VM. Are you sure? " -n 1
  echo
  [[ $REPLY =~ ^[Yy]$ ]] || die

  # move old master until we are finished
  mv $VTHENA_DIR/_master/ $VTHENA_DIR/old_master/

  return 0
}

# takes name, format, size, and qty to make a set of disk images
createDisks() {
    for i in $(seq 1 $4); do
        qemu-img create -f $2 $VTHENA_DIR/_master/$1$i.img $3
    done
}

# interactive disk config creator
askForDisks() {
    while true; do
      # what name would you like for your disks?
      local name
      while true; do
        echo  "What name would you like? (no special characters) ex: boot -> boot1.img boot2.img... "
        read 
        [[ $REPLY =~ ^[A-Za-z0-9]+$ ]] && \
            name=$REPLY && break
      done

      # what disk format?
      local format
      while true; do
        echo "What format would you like: qcow2 , qed , raw , vdi , vhd , and vmdk"
        read
        [[ $REPLY =~ ^qcow2$|^qed$|^raw$|^cdi$|^vhd$|^vmdk$ ]] && \
            format=$REPLY && break
      done

      # how big of disks?
      local size
      while true; do 
        echo "How big would you like your disks? ex: 1G, 1000M" 
        read
        [[ $REPLY =~ ^[0-9]+[G,M]{1}$ ]] && \
          size=$REPLY && break
      done

      # how many disks with these settings?
      local qty
      while true; do
        echo "How many of these disks? "
        read
        [[ $REPLY =~ ^[1-9]{1}[0-9]*$ ]] && \
            qty=$REPLY && break
      done

      # ask if they're sure 
      read -p "Are you sure you want to create $qty disks, named $name, of $size, formatted in $format? Y/n"  -n 1 -r
      # if yes, create disks, regardless, ask if they want to continue
      [[ $REPLY =~ ^[Yy]$ ]] && createDisks $name $format $size $qty

      # continue?
      read -p "Add more disks?" -n 1 -r
      [[ $REPLY =~ ^[Yy]$ ]] || break #if n exit loop
    done
}

##MAIN
main() {
  # workdir
  mkdir $VTHENA_DIR/_master/ $VTHENA_DIR/_master/experiments

  # ask for disk config
  askForDisks

  # well here goes nothing
  $script_dir/startVM.sh _master

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

# check input vals 
[[ $# < 1 ]] && die "Need an iso to install an os"
[[ $# > 1 ]] && die "Really, just the iso is fine"

# warn about an already existing _master vm
[[ -d $VTHENA_DIR/_master/ ]] && handleOldMasterVM

# pass all the arguments to main and send exit code
main $@ && exit 0 || die "something went wrong in main" 