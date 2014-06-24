#!/bin/bash

CS=/usr/bin/cryptsetup
DD=/usr/bin/dd
EXT4=/usr/bin/mkfs.ext4
UDISKS=/usr/bin/udisks
SU=/usr/bin/sudo

ZERO=/dev/zero

# defaults
CIPHER=aes-xts-plain64
KEYSIZE=256
HASH=sha512
ITER=2000

MAPPER=/dev/mapper

msg() {
  case $1 in
    'red')    color=31 ;;
    'green')  color=32 ;;
    'white')  color=37 ;;
    '*')      color=37 ;; # default to white
  esac

  TITLE=$2
  MSG=$3

  if [ -z "$MSG" ]; then
    TITLE=$(basename $0)
    MSG=$2
  fi

  [ -n "$MSG" ] && echo -e "\e[1;${color}m${TITLE}\e[0m: ${MSG}"
}

usage() {
  msg white usage "$@"
  error
}

inform() {
  msg green "\n$@"
}

error() {
  msg red "$@"
  exit 1
}

clean() {
  echo $1 | sed -e 's/[^[:alnum:]]/_/g' | tr -s '_' | tr A-Z a-z
}

if [ $# -lt 2 ]; then
  usage 'FILENAME SIZE [KEYFILE]'
  exit 1
fi

CONTAIN=$1
SIZE=$2
KEY=$3

MAPID="skul-$(clean $CONTAIN)"
MAP=$MAPPER/$MAPID

[ -b $MAP ] && error "$MAP is already mapped"
[ "$KEY" == "$CONTAIN" ] && error 'Key and container cannot be the same file'
[[ "$KEY" && ( ! -f "$KEY" || ! -r "$KEY" ) ]] && error 'Cannot read key'

inform "Creating container '$CONTAIN'"
$DD if=$ZERO of=$CONTAIN bs=1M count=$SIZE
[ $? -eq 0 ] || error 'Error creating container'

inform "Encrypting container '$CONTAIN'"
if [ -n "$KEY" ]; then
  $SU $CS luksFormat $CONTAIN -c $CIPHER -s $KEYSIZE -h $HASH -i $ITER -d "$KEY"
else
  $SU $CS luksFormat $CONTAIN -c $CIPHER -s $KEYSIZE -h $HASH -i $ITER
fi
[ $? -eq 0 ] || error 'Error encrypting container'

inform "Opening container '$CONTAIN'"
if [ -n "$KEY" ]; then
  $SU $CS luksOpen $CONTAIN $MAPID -d "$KEY"
else
  $SU $CS luksOpen $CONTAIN $MAPID
fi
[ $? -eq 0 ] || error 'Error opening container'

inform "Writing encrypted zeroes to '$MAPID'"
$SU $DD if=$ZERO of=$MAP bs=1M
[ $? -eq 0 ] || error 'Error writing encrypted zeros'

inform "Creating filesytem on '$MAPID'"
$SU $EXT4 $MAP -L $MAPID
[ $? -eq 0 ] || error 'Error creating filesystem'

inform "Mounting '$MAPID'"
$SU $UDISKS --mount $MAP
[ $? -eq 0 ] || error 'Error mounting'
