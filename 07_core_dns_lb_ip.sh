#!/bin/bash

for i in 1 2 3
do
  loc="loc${i}"
  clus="clus${i}"
  dns_ip=$( kubectl get services --namespace kube-system --context ${!clus} | grep kube-dns-lb | awk '{print $4}' )
  echo "${!loc} $dns_ip"
done

