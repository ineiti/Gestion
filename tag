#!/bin/bash
if [ ! "$1" ]; then
  echo Please give a tag-name
  exit
fi
(
for a in Gestion QooxView AfriCompta LibNet Config; do
  echo Doing $a
  cd ../$a
  hg tag "$1"
done
)
./commit "Added Tag $1"
