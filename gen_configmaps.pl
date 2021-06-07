#!/usr/bin/env perl

use strict;

my $header = "apiVersion: v1
kind: ConfigMap
metadata:
 name: coredns
 namespace: kube-system
data:
 Corefile: |
   .:53 {
       errors
       ready
       health
       kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            upstream
            fallthrough in-addr.arpa ip6.arpa
       }
       prometheus :9153
       forward . /etc/resolv.conf
       cache 10
       loop
       reload
       loadbalance
   }
";

my $reg_def = "
   _REGION_.svc.cluster.local:53 {       # <---- Modify
       log
       errors
       ready
       cache 10
       forward . _LB_IP_ {      # <---- Modify
       }
   }
";

open SETENV, "bash -c '. ./env.sh && env' |" or die $!;
while (<SETENV>)
{
  chomp;
  my ($k, $v) = split /=/;
  $ENV{$k} = $v;
}
close SETENV;

my @loc = ();
my %clus = ();
my %lb_ip = ();

foreach my $i (1..3)
{
  my $loc = $ENV{"loc" . $i};
  push @loc, $loc;
  $clus{$loc} = $ENV{"clus" . $i};
  open KBCTL, "kubectl get services --namespace kube-system --context $clus{$loc} |" or die $!;
  while (<KBCTL>)
  {
    $lb_ip{$loc} = $1 if /^kube-dns-lb\s+LoadBalancer\s+(?:\d+\.){3}\d+\s+((\d+\.){3}\d+)\s+.+$/;
  }
  close KBCTL;
}

foreach my $loc (@loc)
{
  open YAML, "> configmap-$loc-TEST.yaml" or die $!;
  {
    print YAML $header;
    foreach my $l (@loc)
    {
      next if $l eq $loc;
      my $reg = $reg_def;
      $reg =~ s/_REGION_/$l/;
      $reg =~ s/_LB_IP_/$lb_ip{$l}/;
      print YAML $reg;
    }
  }
  close YAML;
}

