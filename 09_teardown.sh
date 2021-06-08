#!/bin/bash

. ./env.sh

for i in 1 2 3
do
  clus="clus$i"
  az aks delete -g $rg -n ${!clus}
done

az group delete --name $rg

