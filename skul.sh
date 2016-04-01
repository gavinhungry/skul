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
KEYSIZE=${SKUL_KEYSIZE:-512}
HASH=${SKUL_HASH:-sha512}
ITER=${SKUL_ITER:-4000}

MAPPER=/dev/mapper

clean() {
  echo $1 | sed -e 's/[^[:alnum:]]/_/g' | tr -s '_' | tr A-Z a-z
}

create() {
  checksu
  SIZE=$(arg size)
  KEY=$(arg keyfile)
  HEADER=$(arg header)

  [ -e $CONTAINER ] && die "Container '$CONTAINER' already exists"
  [[ $HEADER && ( -e $HEADER ) ]] && die 'Detached header already exists'
  [ -b $MAPPED ] && die "$MAPPED is already mapped"
  [ "$KEY" == "$CONTAINER" ] && die 'Keyfile and container cannot be the same file'
  [ "$HEADER" == "$CONTAINER" ] && die 'Detached header and container cannot be the same file'
  [[ -n "$KEY" && ( "$HEADER" == "$KEY" ) ]] && die 'Keyfile and detached header cannot be the same file'
  [[ -n "$KEY" && ( ! -f "$KEY" || ! -r "$KEY" ) ]] && die 'Cannot read keyfile'

  inform "Using $CIPHER ${KEYSIZE}-bit $HASH"
  inform "Creating container '$CONTAINER'"
  truncate -s ${SIZE}M $CONTAINER
  [ $? -eq 0 ] || die 'Error creating container'

  inform "Encrypting container '$CONTAINER'"
  CMD="checksu cryptsetup luksFormat $CONTAINER -c $CIPHER -s $KEYSIZE -h $HASH -i $ITER"

  [ -n "$KEY" ] && CMD+=" -d $KEY"
  if [ -n "$HEADER" ]; then
    truncate -s 16M $HEADER
    CMD+=" --header $HEADER"
  fi

  eval $CMD
  [ $? -eq 0 ] || die 'Error encrypting container'

  inform "Truncating detached header"
  if [[ -n "$HEADER" && -e "$HEADER" ]]; then
    TMPHEADER=".${HEADER}.skultmp-${$}"
    mv $HEADER $TMPHEADER
    checksu cryptsetup luksHeaderBackup $TMPHEADER --header-backup-file $HEADER
    rm -f $TMPHEADER
  fi

  open $KEY
  wipe
  mount
}

open() {
  checksu
  KEY=$(arg keyfile)
  HEADER=$(arg header)

  inform "Opening container '$CONTAINER'"
  CMD="checksu cryptsetup luksOpen $CONTAINER $MAPID"

  [ -n "$KEY" ] && CMD+=" -d $KEY"
  [ -n "$HEADER" ] && CMD+=" --header $HEADER"

  eval $CMD
  [ $? -eq 0 ] || die 'Error opening container'
}

mount() {
  checksu

  inform "Mounting '$MAPID'"
  quietly checksu udisks --mount $MAPPED
  [ $? -eq 0 ] || die 'Error mounting'

  MOUNTPOINT=$(udisks --show-info $MAPPED | grep 'mount paths:' | sed s/^\ *mount.paths:\ *//g)
  inform "Setting mountpoint permissions on '$MOUNTPOINT'"
  USER=$(id -u -n)
  GROUP=$(id -g -n)
  checksu chown $USER:$GROUP $MOUNTPOINT
}

wipe() {
  checksu

  inform "Writing encrypted zeroes to '$MAPID'"
  quietly checksu dd if=/dev/zero of=$MAPPED bs=1M
  # [ $? -eq 0 ] || die 'Error writing encrypted zeros'

  inform "Creating filesytem on '$MAPID'"
  quietly checksu mkfs.ext4 $MAPPED -L $MAPID
  [ $? -eq 0 ] || die 'Error creating filesystem'
}

close() {
  checksu

  checksu udisks --unmount $MAPPED &> /dev/null
  checksu cryptsetup luksClose $MAPPED
}

info() {
  cryptsetup luksDump $CONTAINER
}

if [ $# -lt 2 ]; then
  usage '[create|open|close|info] FILENAME [--size|-s SIZE] [--keyfile|-k KEYFILE] [--header|-h HEADERFILE]'
  exit 1
fi

CONTAINER=$2
MAPID="skul-$(clean $CONTAINER)"
MAPPED=$MAPPER/$MAPID

case $1 in
  'create') create ;;
  'open') open && mount ;;
  'close') close ;;
  'info') info ;;
esac
