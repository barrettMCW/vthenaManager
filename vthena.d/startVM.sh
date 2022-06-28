#!/bin/bash
###TODO: documentation, test real qemu run
set -eo pipefail 
trap cleanup SIGINT SIGTERM ERR EXIT
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
source $script_dir/.env
# Starts a virtual machine based on provided name and specs with defaults happening to be exactly what I want
##FUNCTIONS
# very cheap error logging
die() { 
  echo "$*" >&2 
  exit 2
}

# demands a value for an option 
needs_arg() { 
  [[ -z $OPTARG ]] && \
    die "No arg for --$OPT option" 
  return 0
}

# demands an unused port on localhost
validatePort() {
  # still needs arg
  needs_arg
  # if addr is going to be localhost
  [[ $VM_ADDR =~ ^127.0.0.1$|^0.0.0.0$ ]] && \
    [[ $(sudo lsof -i:$OPTARG) ]] && \
      die "Specified port :$OPTARG is already bound!"
  return 0
}

# safely exits in the middle of the script
cleanup() {
  # don't let them quit the quit cleaner
  trap - SIGINT SIGTERM ERR EXIT
  # remove instance marker
  rm -f $script_dir/_running/$VM_NAME.init
  exit
}

# prints a help message
help() {
  echo "
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-f] -p param_value arg1 [arg2...]

Script description here.

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-f, --flag      Some flag description
-p, --param     Some param description
"
  exit
}

# use qemu-img to find disk format, then return the val
getDiskFormat() { 
  qemu-img info $1 | awk '/file format:/{print $NF}' 
}

# finds disk images in a folder
getDisks() {
  # add each img file to an array
  local i=1
  local disks=()
  for img in $1/*.img; do 
    [[ -f $img ]] && disks[$i]=$img
    ((i++))
  done
  # Return vals
  echo ${disks[@]} 
  # Good Job!
  return 0
}

# formats given path of .img files into qemu disk string
formatDiskString() {
  local i=1
  local qemuString=()
  for str in $@; do
    # get file format
    local format=$(getDiskFormat $str)
    local diskInd=$((i-1))
    # qemu complains when raw files aren't specified
    [[ $format == raw ]] && qemuString[$i]="-drive file=$str,index=$diskInd,media=disk,if=virtio,format=raw" || \
    qemuString[$i]="-drive file=$str,index=$diskInd,media=disk,if=virtio"
    ((i++))
  done
  echo ${qemuString[@]}
}


# returns open port
getPort() {
  # start at 15900
  local posPort=$VM_PORT_START
  # while we get feedback from lsof, try the next port
  while [[ -n $(sudo lsof -i:$posPort) ]]; do
    ((posPort++))
  done
  # once lsof shuts up, "return" port
  echo $posPort
  return 0
}

# deals with the web of options that are qemu displays
handleDisplayType(){
  # if we can just slap it on the end of a string, send it.
  [[ $VM_DISPLAY_TYPE =~ ^curses$|^none$|^gtk$|^sdl$ ]] && \
    echo "-display $VM_DISPLAY_TYPE" && return 0 

  # nographic option
  [[ $VM_DISPLAY_TYPE =~ ^nographic$ ]] && \
    echo "-nographic"

  # SPICE AND VNC
  # find a port if they didn't give us one
  [[ -z $VM_PORT ]] && VM_PORT=$(getPort)

  # wrap a userprovided password
  [[ -n $VM_PASS ]] && VM_SECURITY=password=$VM_PASS
  # disable security if no password is defined
  [[ -z $VM_SECURITY ]] && VM_SECURITY=disable-ticketing

  # localhost will do the trick for most
  [[ -z $VM_ADDR ]] && VM_ADDR=127.0.0.1

  # if they chose vnc, send it
  [[ $VM_DISPLAY_TYPE =~ ^vnc$ ]] && \
    echo "-display vnc=:$VM_PORT" && return 0

  # they probably should have chose spice tho
  [[ -z $VM_VGA ]] && $VM_VGA=qxl 
  [[ $VM_DISPLAY_TYPE =~ ^spice$ ]] && \
    echo "-spice port=$VM_PORT,addr=$VM_ADDR,$VM_SECURITY" && return 0

  # you shouldn't be here!
  die "We haven't heard of a display type: $VM_DISPLAY_TYPE. Try asking for help."
}

# formats args from getopts into qemu args
wrapQemuArgs() {
  # emulate host if cpu undefined
  [[ -z $VM_CPU ]] && VM_CPU=host

  # wrap a userprovided smp topology
  [[ -n $VM_SMP_TOP ]] && VM_SMP="-smp $VM_SMP_TOP"

  # wrap a userprovided memory cap
  [[ -n $VM_MEM_CAP ]] && VM_MEM="-mem $VM_MEM_CAP"

  # offload display for neatness
  VM_DISPLAY=$(handleDisplayType)

  # set video (when using spice default vga is set in handleDisplayType)
  [[ -n $VM_VGA ]] && VM_VIDEO="-vga $VM_VGA"

  # wrap a userprovided cdrom
  [[ -n $VM_CDROM ]] && VM_OS="-cdrom $VM_CDROM"

  # get disks for this vm (pass external disk directory here)
  local disks=$(getDisks $VTHENA_DIR/$VM_NAME $VM_DISKS_EXTERNAL)
  [[ -z $VM_DISKS ]] && VM_DISKS=$(formatDiskString $disks)

  # get

}

##MAIN
main() {
  ### REFACTOR AS NO ROOT RUNS AND USE nc FOR IP SCANNING
  ### check for kvm group?
  ### ownerless disks
  ### refactor kvm call to make everything optional
  # for now we demand root, would like to figure out a rootless solution
  sudo echo "Starting VM" || die "unfortunately needs to be run as root"

  # checks if this vm is already running
  [[ -e $script_dir/_running/$VM_NAME.init ]] && die "This VM is already running! If you're sure it's not, remove it manually in _running/"

  # make a _running directory if we haven't already
  [[ ! -d $script_dir/_running/ ]] && mkdir $script_dir/_running/

  # set vm directory based on provided name and default vm directory
  cd $VTHENA_DIR/$VM_NAME || die "This vm does not exist! Try using create and giving an iso to create your base vm"

  # marks that we started this vm
  touch $script_dir/_running/$VM_NAME.init
  

  # Start vm with specs#
  kvm -name $VM_NAME \
  -cpu $VM_CPU \
  $VM_SMP $VM_MEM $VM_DISPLAY $VM_VIDEO $VM_OS \
  $VM_DISKS $VM_NET $VM_USB $VM_XTRA

  # Good Job!
  cleanup
}

# parse your options
while getopts a:c:d:m:p:r:s:w:h-: OPT; do
  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi 
  case "$OPT" in
    a | address )  needs_arg && VM_ADDR=$OPTARG ;;
    c | cpu )      needs_arg && VM_CPU=$OPTARG ;;
    d | display )  needs_arg && VM_DISPLAY_TYPE=$OPTARG ;;
    e | extra )    needs_arg && VM_DISKS_EXTERNAL=$OPTARG ;;
    m | memory )   needs_arg && VM_MEM_CAP=$OPTARG ;;
    p | port )     validatePort && VM_PORT=$OPTARG ;;
    r | cdrom )    needs_arg && VM_CDROM=$OPTARG ;;
    s | smp )      needs_arg && VM_SMP_TOP=$OPTARG ;;
    v | vga )      needs_arg && VM_VGA=$OPTARG ;;
    w | password ) needs_arg && VM_PASS=$OPTARG ;;
    x | extra )    needs_arg && VM_XTRA=$OPTARG ;;
    h | help )     help ;;
    ? )            exit 2 ;;  # bad short option (error reported via getopts)
    ?* )           die "Illegal option --$OPT" ;;  # bad long option
  esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list

# use name if provided
[[ -n $1 ]] && VM_NAME=$1

# wraps user given args into qemu command args
wrapQemuArgs


# pass all the arguments to main
main $@ 