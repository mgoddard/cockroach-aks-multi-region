#!/bin/bash

. ./env.sh

for i in 1 2 3
do
  clus="clus$i"
  loc="loc$i"
  kubectl apply -f configmap-${!loc}.yaml --context ${!clus}
done

