# AKS Multi-Region CockroachDB

Description: Setting up and configuring a multi-region CockroachDB cluster on Azure AKS
Tags: Azure, AKS, Kubernetes, K8s, data

## Edit the file [env.sh](./env.sh), setting each of the variables to suit your application.

```bash
vm_type="Standard_E2d_v4"
n_nodes=3
rg="$USER-aks-multi-region"

loc1="westus"
loc2="centralus"
loc3="eastus"

clus1="crdb-aks-$loc1"
clus2="crdb-aks-$loc2"
clus3="crdb-aks-$loc3"
```

## Run [this script](./01_create_rg.sh) to create a resource group (RG) for the project.

## Networking configuration

In order to enable VPC peering between the regions, the CIDR blocks of the
VPCs must not overlap. This value cannot change once the cluster has been
created, so be sure that your IP ranges do not overlap.

Run [this script](./02_network.sh) to create the the virtual networks creation and peer them.

## Run [This script](./03_k8s_clusters.sh) to create a Kubernetes (K8s) cluster in each of the three regions.

When prompted about whether or not to proceed with each process, type `y`.

## Run [this script](./04_get_credentials.sh) to configure kubectl.

You can switch K8s contexts using this approach:

```bash
kubectl config use-context crdb-aks-$clus1
```

where `$clus1`, `$clus2` and `$clus3` are defined in your `./env.sh` file.

## (optional) Run [this script](./05_ping_test.sh) to test network connectivity.

## If you haven't done this already, install CockroachDB locally and add it to
`PATH`. Download it [here](https://www.cockroachlabs.com/docs/v20.1/install-cockroachdb).
The `cockroach` binary will be used to generate certificates.

If the `cockroach` binary is not on your `PATH`, in the `setup.py` script, set
the `cockroach_path` variable to the path to the binary.

## Run [this script](./06_contexts_regions.sh) to generate the `context` and
`regions` maps you'll embed into `./multiregion/setup.py`.

```bash
./06_contexts_regions.sh 

# Replace the existing contexts and regions definitions in setup.py with these:
contexts = { 'westus': 'crdb-aks-westus', 'centralus': 'crdb-aks-centralus', 'eastus': 'crdb-aks-eastus' }
regions = { 'westus': 'westus', 'centralus': 'centralus', 'eastus': 'eastus' }

```

Use this output to edit `setup.py`.
**NOTE**: the `regions` map just maps each region to itself.

## Run the `./multiregion/setup.py` script: 

```bash
cd ./multiregion/
python setup.py
cd -
```

As the script creates various resources and creates and initializes the
CockroachDB cluster, you'll see a lot of output, eventually ending with `job
"cluster-init-secure" created`.

## Configure CoreDNS

Each Kubernetes cluster has a [CoreDNS](https://coredns.io/) service that
responds to DNS requests for pods in its region. CoreDNS can also forward DNS
requests to pods in other regions.

To enable traffic forwarding to CockroachDB pods in all 3 regions, you need
to [modify the
ConfigMap](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/#coredns-configmap-options) for
the CoreDNS Corefile in each region.

There are three sample config maps [here](./EXAMPLE).

- Run [This script](./07_gen_configmaps.sh) to create the three `configmap-*.yaml` files you need in the next step.

These files will be named `configmap-`, the name of the region (the `$loc*` values from `env.sh`), then `.yaml`.

- (optional) Back up the existing config maps (do this for each region):

```bash
kubectl -n kube-system get configmap coredns -o yaml > <configmap-backup-name>
```

- Run [this script](./08_apply_configmaps.sh) to apply each of the three config maps.

- For each region, check that your CoreDNS settings were applied: 

```bash
kubectl get -n kube-system cm/coredns -o yaml --context <cluster-context>
```
- Confirm that the CockroachDB pods in each cluster report `1/1` in
the `READY` column, indicating that they've successfully joined the
cluster.  **NOTE**: This could take from a couple of minutes to **hours**
to take effect.  Be patient.

```bash
kubectl get pods --selector app=cockroachdb --all-namespaces --context $clus1

NAMESPACE NAME READY STATUS RESTARTS AGE
us-east1-b cockroachdb-0 1/1 Running 0 14m
us-east1-b cockroachdb-1 1/1 Running 0 14m
us-east1-b cockroachdb-2 1/1 Running 0 14m
```

```bash
kubectl get pods --selector app=cockroachdb --all-namespaces --context $clus2

NAMESPACE NAME READY STATUS RESTARTS AGE
us-central1-a cockroachdb-0 1/1 Running 0 14m
us-central1-a cockroachdb-1 1/1 Running 0 14m
us-central1-a cockroachdb-2 1/1 Running 0 14m
```

```bash
kubectl get pods --selector app=cockroachdb --all-namespaces --context $clus3

NAMESPACE NAME READY STATUS RESTARTS AGE
us-west1-a cockroachdb-0 1/1 Running 0 14m
us-west1-a cockroachdb-1 1/1 Running 0 14m
us-west1-a cockroachdb-2 1/1 Running 0 14m
```

## SSH into one of the pods **OR** Create secure client

- SSH approach to get a SQL prompt:

```bash
kubectl exec --stdin --tty cockroachdb-0 --namespace $loc3 --context $clus3 -- /bin/bash
```

Then, start the SQL CLI:
```bash
# ./cockroach sql --certs-dir ./cockroach-certs
```

- Creation of secure client:

```bash
kubectl create -f https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/client-secure.yaml --namespace $loc1
```

```bash
kubectl exec -it cockroachdb-client-secure -n $loc1 -- ./cockroach sql --certs-dir=/cockroach-certs --host=cockroachdb-public
```
## Port forward the DB Console.
**NOTE**: you must first create a user with admin rights so that you can log in
to the console.

```bash
kubectl port-forward cockroachdb-0 8080 --context $clus1 --namespace $loc1
```

## Tear it all down when you're finished.

```bash
./09_teardown.sh
```

