#!/bin/bash

. ./env.sh

# In order to enable VPC peering between the regions, the CIDR blocks of the VPCs
# must not overlap. This value cannot change once the cluster has been created,
# so be sure that your IP ranges do not overlap.

# Create vnets for all Regions
az network vnet create -g $rg -n crdb-$loc1 --address-prefix 20.0.0.0/16 \
    --subnet-name crdb-$loc1-sub1 --subnet-prefix 20.0.0.0/24

az network vnet create -g $rg -n crdb-$loc2 --address-prefix 30.0.0.0/16 \
    --subnet-name crdb-$loc2-sub1 --subnet-prefix 30.0.0.0/24

az network vnet create -g $rg -n crdb-$loc3 --address-prefix 40.0.0.0/24 \
    --subnet-name crdb-$loc3-sub1 --subnet-prefix 40.0.0.0/24

# Peer the Vnets
az network vnet peering create -g $rg -n $loc1-$loc2-peer --vnet-name crdb-$loc1 \
    --remote-vnet crdb-$loc2 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit

az network vnet peering create -g $rg -n $loc2-$loc3-peer --vnet-name crdb-$loc2 \
    --remote-vnet crdb-$loc3 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit

az network vnet peering create -g $rg -n $loc1-$loc3-peer --vnet-name crdb-$loc1 \
    --remote-vnet crdb-$loc3 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit

az network vnet peering create -g $rg -n $loc2-$loc1-peer --vnet-name crdb-$loc2 \
    --remote-vnet crdb-$loc1 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit

az network vnet peering create -g $rg -n $loc3-$loc2-peer --vnet-name crdb-$loc3 \
    --remote-vnet crdb-$loc2 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit

az network vnet peering create -g $rg -n $loc3-$loc1-peer --vnet-name crdb-$loc3 \
    --remote-vnet crdb-$loc1 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit


