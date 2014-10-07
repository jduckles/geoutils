#!/bin/sh

FILES=$1

for file in $(cat $FILES); do
    wget -nc -P data/ ${file};
done
