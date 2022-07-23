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

# lvms need to be activated and mounted from a different point
handleLVM(){
  pvscan | while read line; do
    [[ ${line[2]} =~ $1 ]] && break  
  done
  sudo vgchange -ay ${line[4]}
  echo "/dev/${line[4]}/*" #UNLIKELY TO WORK NGL
}

# Copy VM, set it up serial terminal and transfer test files
prepareVM(){
  echo "Preparing vm for testing, unfortunately doing this automatically REQUIRES sudo perms, you will be asked for it shortly"
  # copy vm
  local test_env=$VTHENA_DIR/test_$1
  cp -r $VTHENA_DIR/$1 $test_env

  # mount each disk and handle directories as found
  local i=0 ; for img in $test_env/*.img; do
    # host img as netblockdev
    local diskdir=$test_env/$img.d
    sudo qemu-nbd --connect=/dev/nbd$i $img
    mkdir $diskdir

    # gather lvms
    sudo pvscan --cache
    local lvms=${$(sudo pvscan)}

    # for each partition of the img
    for part in $(fdisk /dev/nbd$i -l); do
      # lvms require a little extra tlc
      [[ " ${lvms[*][2]} " =~ " $part " ]] && part=$(handleLVM $part)

      mount $part $diskdir

      # if directory do thing
      [[ -d $diskdir/grub ]] #/boot part
      [[ -d $diskdir/bin ]] && [[ -d $diskdir/root ]] #/ root part
      [[ -d $diskdir/*/ ]] # idk how to home.

      umount $diskdir
    done

    # cleanup
    rmdir $diskdir
    qemu-nbd --disconnect=/dev/nbd$1
  done

  # move files to /usr/bin/experiment/

  # set up as a serial console
  cp /etc/default/grub   /etc/default/grub.orig
  sudo cp /boot/grub/grub.cfg /boot/grub/grub.cfg.orig
  sudo vim /etc/default/grub
}

##MAIN
main() {
  # we have to mess with important files, make a copy then do that
  prepareVM $1

  # if second arg isn't an executable, check global experiments, if still can't find, die
  [[ -x $2 ]] && experiment=$2 || \
    experiment=$(find $script_dir/experiments -name "$2.*" -executable -print -quit)
  
  [[ ! -x $experiment ]] && die "Experiment not found"

  

  # run the vm and expect script
  $script_dir/watchVM.exp "$2" `$script_dir/startVM.sh $RUN_ARGS $1`

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

# default user is root
[[ -z $SCRIPT_USER ]] && SCRIPT_USER=root

# we need a key file to log in
[[ ! -f $VTHENA_DIR/$1/$SCRIPT_USER.key ]] && die "No key for: $SCRIPT_USER! Try: vthena key VM_NAME USER"

# pass all the arguments to main and send exit code
main $1 $experiment && exit 0 || die "something went wrong in main" 