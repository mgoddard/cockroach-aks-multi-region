#!/bin/bash

. ./env.sh

# Create the Kubernetes clusters in each region
loc1subid=$(az network vnet subnet list --resource-group $rg --vnet-name crdb-$loc1 | jq -r '.[].id')
loc2subid=$(az network vnet subnet list --resource-group $rg --vnet-name crdb-$loc2 | jq -r '.[].id')
loc3subid=$(az network vnet subnet list --resource-group $rg --vnet-name crdb-$loc3 | jq -r '.[].id')

az aks create \
  --name $clus1 \
  --resource-group $rg \
  --network-plugin azure \
  --vnet-subnet-id $loc1subid \
  --node-count $n_nodes \
  --node-vm-size $vm_type

az aks create \
  --name $clus2 \
  --resource-group $rg \
  --network-plugin azure \
  --vnet-subnet-id $loc2subid \
  --node-count $n_nodes \
  --node-vm-size $vm_type

az aks create \
  --name $clus3 \
  --resource-group $rg \
  --network-plugin azure \
  --vnet-subnet-id $loc3subid \
  --node-count $n_nodes \
  --node-vm-size $vm_type

# az aks delete -g $rg -n $clus1

