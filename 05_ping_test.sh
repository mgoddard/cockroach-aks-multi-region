#!/bin/bash

. ./env.sh

# az aks get-credentials --name $clus3 --resource-group $rg

kubectl config use-context $clus1
kubectl run network-test --image=alpine --restart=Never -- sleep 999999
ip=$( kubectl describe pods | perl -ne 'print "$1\n" if /^IP:\s+((\d+\.){3}\d+).*$/' )

kubectl config use-context $clus3
kubectl run -it network-test --image=alpine --restart=Never -- ping -c 1 $ip

kubectl delete pod network-test
kubectl config use-context $clus1
kubectl delete pod network-test

