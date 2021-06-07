#!/bin/bash

. ./env.sh

az aks get-credentials --name $clus1 --resource-group $rg
az aks get-credentials --name $clus2 --resource-group $rg
az aks get-credentials --name $clus3 --resource-group $rg

