#!/bin/sh

source /config/custom-command

for b in $BUCKETS; do
  name=$(echo $b | cut -d: -f1)
  locks=$(echo $b | cut -d: -f2)
  versioning=$(echo $b | cut -d: -f3)
  ${MC} mb --ignore-existing $locks $versioning myminio/$name
done
