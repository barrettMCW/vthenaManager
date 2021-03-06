#!/bin/bash
# Starts a virtual machine based on provided name and specs with defaults happening to be exactly what I want
## TODO:
## help isn't entirely forthcoming (display options)
## external disks not implemented
set -eo pipefail 
trap cleanup SIGINT SIGTERM ERR EXIT
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
#fetch defaults
[[ -f $script_dir/vthena.d/.env ]] && source $script_dir/vthena.d/.env

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
    [[ -n $(nc -w 1 localhost $OPTARG) ]] && \
      die "Specified port :$OPTARG is already bound!"
  return 0
}

# safely exits in the middle of the script
cleanup() {
  # don't let them quit the quit cleaner
  trap - SIGINT SIGTERM ERR EXIT
  # remove instance marker
  rm -f $VTHENA_DIR/$VM_NAME/.init
  exit
}

# prints a help message
help() {
  echo "
Usage: vthena start [--address=val] [--cpu=val] [--display=val] [--external=val] [--memory=val] 
[--port=val] [--cdrom=val] [--smp=val] [--vga=val] [--password=val] [--extra=val] vmName
Start a QEMU-KVM with the provided options
Available options:
-h, --help      ex. -h;             Print this help and exit 
-a, --address   ex. -a 127.0.0.1;   Address to host remote viewer (SPICE or VNC)
-c, --cpu       ex. -c EPYC-v1;     Host CPU type, see qemu help for more 
-d, --display   ex. -d nographic;   Display type to use, see qemu help for more
-e, --external  ex. -e /path/;      External (ownerless) disks to use
-m, --memory    ex. -m 8G;          Amount of ram to use 
-p, --port      ex. -p 5900;        Port to host remote viewer (SPICE or VNC)
-r, --cdrom     ex. -r linux.iso;   Path to cdrom (Usually iso to install an oS)
-s, --smp       ex. -s 8;           cpu SMP topology for VM, see qemu for more
-v, --vga       ex. -v virtio;      VGA adapter, see qemu for more
-w, --password  ex. -w password;    Password for use in remote viewers (SPICE or VNC)
-x, --extra     ex. -x '-boot c';   Any other qemu params can be put here, no formatting is done though"
  exit
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
    local format=$($script_dir/util/getDiskMeta.sh format $str)
    local diskInd=$((i-1))
    # qemu complains when raw files aren't specified
    qemuString[$i]="-drive file=$str,index=$diskInd,media=disk,if=virtio,format=$format" 
    [[ $i == 1 ]] && qemuString[1]="-hda $str"
    ((i++))
  done
  echo ${qemuString[@]}
}


# returns open port
getPort() {
  # start at 5901
  [[ -z $VM_PORT_START ]] && VM_PORT_START=5901
  local posPort=$VM_PORT_START
  # while we get feedback from mc, try the next port
  while [[ -n $(nc -w 1 localhost $posPort) ]]; do
    ((posPort++))
  done
  # once mc shuts up, "return" port
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
    echo "-nographic" && return 0

  # SPICE AND VNC
  # find a port if they didn't give us one
  [[ -z $VM_PORT ]] && VM_PORT=$(getPort)

  # wrap a userprovided password
  [[ -n $VM_PASS ]] && VM_SECURITY="password=$VM_PASS"
  # disable security if no password is defined
  [[ -z $VM_SECURITY ]] && VM_SECURITY="disable-ticketing=on"

  # localhost will do the trick for most
  [[ -z $VM_ADDR ]] && VM_ADDR=127.0.0.1

  # if they chose vnc, send it
  [[ $VM_DISPLAY_TYPE =~ ^vnc$ ]] && \
    echo "-display vnc=:$VM_PORT" && return 0

  # spice will be our default for now
  [[ -z $VM_VGA ]] && VM_VGA=qxl 
  echo "-spice port=$VM_PORT,addr=$VM_ADDR,$VM_SECURITY" && return 0
}

# formats args from getopts into qemu args
wrapQemuArgs() {
  # emulate host if cpu undefined
  [[ -z $VM_CPU ]] && VM_CPU=host

  # wrap a userprovided smp topology
  [[ -n $VM_SMP_TOP ]] && VM_SMP="-smp $VM_SMP_TOP"

  # wrap a userprovided memory cap
  [[ -n $VM_MEM_CAP ]] && VM_MEM="-m $VM_MEM_CAP"

  # offload display for neatness
  VM_DISPLAY=$(handleDisplayType)

  # set video (when using spice default vga is set in handleDisplayType)
  [[ -n $VM_VGA ]] && VM_VIDEO="-vga $VM_VGA"

  # wrap a userprovided cdrom
  [[ -n $VM_CDROM ]] && VM_OS="-cdrom $VM_CDROM"

  # get disks for this vm (pass external disk directory here)
  local disks=$(getDisks $VTHENA_DIR/$VM_NAME $VM_DISKS_EXTERNAL)
  [[ -z $VM_DISKS ]] && VM_DISKS=$(formatDiskString $disks)

}

##MAIN
main() {
  # set vm directory based on provided name and default vm directory
  cd $VTHENA_DIR/$VM_NAME || die "This vm does not exist! Try using create and giving an iso to create your base vm"

  # checks if this vm is already running
  [[ -e $VTHENA_DIR/$VM_NAME/.init ]] && die "This VM is already running! If you're sure it's not, remove it manually in _running/"

  # marks that we started this vm
  touch $VTHENA_DIR/$VM_NAME/.init
  
  # Start vm with specs, echo if fakerun
  local "qemu=qemu-system-x86_64 -enable-kvm -name $VM_NAME \
    -cpu $VM_CPU $VM_SMP $VM_MEM $VM_DISPLAY $VM_VIDEO $VM_OS $VM_DISKS $VM_NET $VM_USB $VM_XTRA "
  [[ $FAKE_RUN ]] && echo $qemu || \
    $qemu

  # Good Job!
  cleanup
}

# parse your options
while getopts a:c:d:e:fm:p:r:s:v:w:x:h-: OPT; do
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
    e | external ) needs_arg && VM_DISKS_EXTERNAL=$OPTARG ;;
    f | fake )     FAKE_RUN=true ;; 
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

# _master is default
[[ -z $VM_NAME ]] && VM_NAME=_master

# wraps user given args into qemu command args
wrapQemuArgs


# pass all the arguments to main
main $@ 