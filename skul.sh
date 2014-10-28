#!/bin/bash
#
# Name: skul
# Auth: Gavin Lloyd <gavinhungry@gmail.com>
# Desc: Create, format and mount loopback-based, encrypted LUKS containers
#
# Released under the terms of the MIT license
# https://github.com/gavinhungry/skul
#

CHOWN=/usr/bin/chown
CS=/usr/bin/cryptsetup
DD=/usr/bin/dd
EXT4=/usr/bin/mkfs.ext4
SU=/usr/bin/sudo
UDISKS=/usr/bin/udisks

ZERO=/dev/zero

# defaults
CIPHER=aes-xts-plain64
KEYSIZE=256
HASH=sha512
ITER=4000

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
  msg white usage "$(basename $0) $@"
  error
}

inform() {
  echo
  msg green "$@ ..."
}

error() {
  msg red "$@"
  exit 1
}

clean() {
  echo $1 | sed -e 's/[^[:alnum:]]/_/g' | tr -s '_' | tr A-Z a-z
}

checksu() {
  $SU -v || exit 1
}

create() {
  checksu
  SIZE=$1
  KEY=$2

  [ -e $CONTAINER ] && error "Container '$CONTAINER' already exists"
  [ -b $MAP ] && error "$MAP is already mapped"
  [ "$KEY" == "$CONTAINER" ] && error 'Key and container cannot be the same file'
  [[ "$KEY" && ( ! -f "$KEY" || ! -r "$KEY" ) ]] && error 'Cannot read key'

  inform "Using $CIPHER ${KEYSIZE}-bit $HASH"
  inform "Creating container '$CONTAINER'"
  $DD if=$ZERO of=$CONTAINER bs=1M count=$SIZE
  [ $? -eq 0 ] || error 'Error creating container'

  inform "Encrypting container '$CONTAINER'"
  if [ -n "$KEY" ]; then
    $SU $CS luksFormat $CONTAINER -c $CIPHER -s $KEYSIZE -h $HASH -i $ITER -d "$KEY"
  else
    $SU $CS luksFormat $CONTAINER -c $CIPHER -s $KEYSIZE -h $HASH -i $ITER
  fi
  [ $? -eq 0 ] || error 'Error encrypting container'

  open $KEY
  wipe
  mount
}

open() {
  checksu
  KEY=$1

  inform "Opening container '$CONTAINER'"
  if [ -n "$KEY" ]; then
    $SU $CS luksOpen $CONTAINER $MAPID -d "$KEY"
  else
    $SU $CS luksOpen $CONTAINER $MAPID
  fi
  [ $? -eq 0 ] || error 'Error opening container'
}

mount() {
  checksu

  inform "Mounting '$MAPID'"
  $SU $UDISKS --mount $MAP
  [ $? -eq 0 ] || error 'Error mounting'

  MOUNTPOINT=$($UDISKS --show-info $MAP | grep 'mount paths:' | sed s/^\ *mount.paths:\ *//g)
  inform "Setting mountpoint permissions on '$MOUNTPOINT'"
  USER=$(id -u -n)
  GROUP=$(id -g -n)
  $SU $CHOWN $USER:$GROUP $MOUNTPOINT
}

wipe() {
  checksu

  inform "Writing encrypted zeroes to '$MAPID'"
  $SU $DD if=$ZERO of=$MAP bs=1M
  # [ $? -eq 0 ] || error 'Error writing encrypted zeros'

  inform "Creating filesytem on '$MAPID'"
  $SU $EXT4 $MAP -L $MAPID
  [ $? -eq 0 ] || error 'Error creating filesystem'
}

close() {
  checksu

  $SU $UDISKS --unmount $MAP &> /dev/null
  $SU $CS luksClose $MAP
}

if [ $# -lt 2 ]; then
  usage '[create|open|close] FILENAME [SIZE] [KEYFILE]'
  exit 1
fi

CONTAINER=$2
MAPID="skul-$(clean $CONTAINER)"
MAP=$MAPPER/$MAPID

case $1 in
  'create') create $3 $4 ;;
  'open') open $3; mount $3 ;;
  'close') close ;;
esac