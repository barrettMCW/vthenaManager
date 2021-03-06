#!/bin/bash
# Removes a vm and deals with dependants
set -eo pipefail 
trap cleanup SIGINT SIGTERM ERR EXIT
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
#fetch defaults
[[ -f $script_dir/.env ]] && source $script_dir/.env

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

  exit 
}

# prints a help message
help() {
  echo "
Usage: vthena remove [-h] [-r] arg1 [arg2...]
Deletes VMs and rebases their children if necessary
Available options:
-h, --help      Print this help and exit
-r, --recurse   Deletes children VMs instead of rebasing them"
  exit 1
}

# if remove is selected remove the vm directory, else rebase the image
handleOverlay(){
  [[ -n $REMOVE ]] && \
    echo "removing child vm: ${1%/*.img}" && rm -r ${1%/*.img} || \
    ( echo "rebasing image " && qemu-img rebase -F qcow2 -b '' -f qcow2 $1 )

} 

##MAIN
main() {
  # all this to check for overlays
  local VM=$VTHENA_DIR/$1
  # for each image of provided vm
  for img in $VM/*.img; do
    # if it's qcow then check for children
    if [[ $($script_dir/util/getDiskMeta.sh format $img) =~ (qcow2)* ]]; then 
      echo "QCOW2 image detected, checking for overlays"
      local parentData=$(qemu-img info --backing-chain $img) 
      # look at all vms
      for vm in $($script_dir/util/listVMs.sh); do
        [[ $vm == $1 ]] && continue
        # look at each of their images
        for vm_img in $VTHENA_DIR/$vm/*.img; do
          local childData=$(qemu-img info --backing-chain $vm_img)
          # if they have $img's data then it's an overlay and we need to handle that
          [[ $childData == *${parentData} ]] && handleOverlay $vm_img 
        done 
      done
    fi
  done

  # delete the vm 
  rm -rf $VM
  
  echo "Succesfully Deleted VM: $VM"
}

# first parse your options
while getopts rh-: OPT; do
  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi 
  case "$OPT" in
    h | help )        help ;;
    r | recurse ) REMOVE=true ;;
    ??* )             die "Illegal option --$OPT" ;;  # bad long option
    ? )               exit 2 ;;  # bad short option (error reported via getopts)
  esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list

# check input quantity
[[ $# < 1 ]] && die "What did you want? Look at help."

# make sure every vm exists before you start trashing things
for vm? in $@; do 
  # check that vm exists
  [[ $($script_dir/util/searchVM.sh ${vm?}) != ${vm?} ]] && \
    die "VM not found." 
done

# hope everything goes okay, could see some issues trying to delete multiple items but we'll see ig
for removee in $@; do
  # pass all the arguments to main or die
  main $@ || die "something went wrong in main"
done
#Good Job! 
exit 0