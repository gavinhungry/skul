#!/bin/bash

# cryptsetup
CRYPTSETUP=/usr/bin/cryptsetup
CS="sudo $CRYPTSETUP"

# defaults
CIPHER=aes-xts-plain64
SIZE=256
HASH=sha512
ITER=2000

MAPPER=/dev/mapper

msg() {
  case $1 in
    'red')    color=31 ;;
    'yellow') color=33 ;;
    'white')  color=37 ;;
    '*')      color=37 ;;
  esac

  TITLE=$2
  MSG=$3

  if [ -z "$MSG" ]; then
    TITLE=$(basename $0)
    MSG=$2
  fi

  echo -e "\e[1;${color}m${TITLE}\e[0m: ${MSG}"
}

clean() {
  echo $1 | sed -e 's/[^[:alnum:]]/_/g' | tr -s '_' | tr A-Z a-z
}

if [ $# -lt 2 ]; then
  msg white usage 'FILENAME SIZE [KEYFILE]'
  exit 1
fi

FILENAME=$1
SIZE=$2
KEYFILE=$3

ID="skul-$(clean $FILENAME)"

ID='mozzy'

if [ -b $MAPPER/$ID ]; then
  msg red "$ID is already mapped"
  exit 1
fi

exit 1

if [ $KEYFILE -a -f $KEYFILE -a -r $KEYFILE ]; then
  echo $CS luksCreate $FILENAME -c $CIPHER -s $SIZE -h $HASH -i $ITER -d $KEYFILE
else
  echo $CS luksCreate $FILENAME -c $CIPHER -s $SIZE -h $HASH -i $ITER
fi

echo $CS luksOpen $FILENAME