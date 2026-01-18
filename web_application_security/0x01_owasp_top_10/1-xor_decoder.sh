#!/bin/bash

if [ -z "$1" ]; then
    exit 1
fi

echo "${1#"{xor}"}" | base64 -d | perl -pe '$_^="_" x length'
