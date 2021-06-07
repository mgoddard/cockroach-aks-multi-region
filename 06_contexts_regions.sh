#!/bin/bash

. ./env.sh

echo
echo "# Replace the existing contexts and regions definitions in setup.py with these:"
echo "contexts = { '$loc1': '$clus1', '$loc2': '$clus2', '$loc3': '$clus3' }"
echo "regions = { '$loc1': '$loc1', '$loc2': '$loc2', '$loc3': '$loc3' }"
echo

