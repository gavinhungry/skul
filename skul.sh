#!/bin/bash
#
# Name: skul
# Auth: Gavin Lloyd <gavinhungry@gmail.com>
# Desc: Create, format and mount loopback-based, encrypted LUKS containers
#
# Released under the terms of the MIT license
# https://github.com/gavinhungry/skul
#

[ ${_ABASH:-0} -ne 0 ] || source $(dirname "${BASH_SOURCE}")/abash/abash.sh

CIPHER=${SKUL_CIPHER:-aes-xts-plain64}
KEYSIZE=${SKUL_KEYSIZE:-256}
HASH=${SKUL_HASH:-sha512}
ITER=${SKUL_ITER:-4000}

MAPPER=/dev/mapper

clean() {
  echo $1 | sed -e 's/[^[:alnum:]]/_/g' | tr -s '_' | tr A-Z a-z
}

create() {
  checksu
  SIZE=$1
  KEY=$2

  [ -e $CONTAINER ] && error "Container '$CONTAINER' already exists"
  [ -b $MAPPED ] && error "$MAPPED is already mapped"
  [ "$KEY" == "$CONTAINER" ] && error 'Key and container cannot be the same file'
  [[ "$KEY" && ( ! -f "$KEY" || ! -r "$KEY" ) ]] && error 'Cannot read key'

  inform "Using $CIPHER ${KEYSIZE}-bit $HASH"
  inform "Creating container '$CONTAINER'"
  truncate -s ${SIZE}M $CONTAINER
  [ $? -eq 0 ] || error 'Error creating container'

  inform "Encrypting container '$CONTAINER'"
  if [ -n "$KEY" ]; then
    checksu cryptsetup luksFormat $CONTAINER -c $CIPHER -s $KEYSIZE -h $HASH -i $ITER -d "$KEY"
  else
    checksu cryptsetup luksFormat $CONTAINER -c $CIPHER -s $KEYSIZE -h $HASH -i $ITER
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
    checksu cryptsetup luksOpen $CONTAINER $MAPID -d "$KEY"
  else
    checksu cryptsetup luksOpen $CONTAINER $MAPID
  fi
  [ $? -eq 0 ] || error 'Error opening container'
}

mount() {
  checksu

  inform "Mounting '$MAPID'"
  checksu udisks --mount $MAPPED
  [ $? -eq 0 ] || error 'Error mounting'

  MOUNTPOINT=$(udisks --show-info $MAPPED | grep 'mount paths:' | sed s/^\ *mount.paths:\ *//g)
  inform "Setting mountpoint permissions on '$MOUNTPOINT'"
  USER=$(id -u -n)
  GROUP=$(id -g -n)
  checksu chown $USER:$GROUP $MOUNTPOINT
}

wipe() {
  checksu

  inform "Writing encrypted zeroes to '$MAPID'"
  checksu dd if=/dev/zero of=$MAPPED bs=1M
  # [ $? -eq 0 ] || error 'Error writing encrypted zeros'

  inform "Creating filesytem on '$MAPID'"
  checksu mkfs.ext4 $MAPPED -L $MAPID
  [ $? -eq 0 ] || error 'Error creating filesystem'
}

close() {
  checksu

  checksu udisks --unmount $MAPPED &> /dev/null
  checksu cryptsetup luksClose $MAPPED
}

if [ $# -lt 2 ]; then
  usage '[create|open|close] FILENAME [SIZE] [KEYFILE]'
  exit 1
fi

CONTAINER=$2
MAPID="skul-$(clean $CONTAINER)"
MAPPED=$MAPPER/$MAPID

case $1 in
  'create') create $3 $4 ;;
  'open') open $3; mount $3 ;;
  'close') close ;;
esac