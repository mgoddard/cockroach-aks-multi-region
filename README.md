# AKS Multi-Region CockroachDB

Description: Setting up and configuring a multi-region CockroachDB cluster on Azure AKS
Tags: Azure, AKS, Kubernetes, K8s, data

- Create a set of variables in the file [env.sh](./env.sh).

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

- Create a Resource Group (RG) for the project. [This script](./01_create_rg.sh) will create this RG.

    ```bash
    az group create --name $rg --location $loc1
    ```

- Networking configuration

    In order to enable VPC peering between the regions, the CIDR blocks of the
    VPCs must not overlap. This value cannot change once the cluster has been
    created, so be sure that your IP ranges do not overlap.

    [This script](./02_network.sh) handles both the VNet creation and the peering steps.

    - Create vnets for all Regions

        ```bash
        az network vnet create -g $rg -n crdb-$loc1 --address-prefix 20.0.0.0/16 \
            --subnet-name crdb-$loc1-sub1 --subnet-prefix 20.0.0.0/24
        ```

        ```bash
        az network vnet create -g $rg -n crdb-$loc2 --address-prefix 30.0.0.0/16 \
            --subnet-name crdb-$loc2-sub1 --subnet-prefix 30.0.0.0/24
        ```

        ```bash
        az network vnet create -g $rg -n crdb-$loc3 --address-prefix 40.0.0.0/24 \
            --subnet-name crdb-$loc3-sub1 --subnet-prefix 40.0.0.0/24
        ```

    - Peer the Vnets

        ```bash
        az network vnet peering create -g $rg -n $loc1-$loc2-peer --vnet-name crdb-$loc1 \
            --remote-vnet crdb-$loc2 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit
        ```

        ```bash
        az network vnet peering create -g $rg -n $loc2-$loc3-peer --vnet-name crdb-$loc2 \
            --remote-vnet crdb-$loc3 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit
        ```

        ```bash
        az network vnet peering create -g $rg -n $loc1-$loc3-peer --vnet-name crdb-$loc1 \
            --remote-vnet crdb-$loc3 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit
        ```

        ```bash
        az network vnet peering create -g $rg -n $loc2-$loc1-peer --vnet-name crdb-$loc2 \
            --remote-vnet crdb-$loc1 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit
        ```

        ```bash
        az network vnet peering create -g $rg -n $loc3-$loc2-peer --vnet-name crdb-$loc3 \
            --remote-vnet crdb-$loc2 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit
        ```

        ```bash
        az network vnet peering create -g $rg -n $loc3-$loc1-peer --vnet-name crdb-$loc3 \
            --remote-vnet crdb-$loc1 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit
        ```

- Create the Kubernetes clusters in each region.  [This script](./03_k8s_clusters.sh) handles this step.
    - To get SubnetID

        ```bash
        loc1subid=$(az network vnet subnet list --resource-group $rg --vnet-name crdb-$loc1 | jq -r '.[].id')
        loc2subid=$(az network vnet subnet list --resource-group $rg --vnet-name crdb-$loc2 | jq -r '.[].id')
        loc3subid=$(az network vnet subnet list --resource-group $rg --vnet-name crdb-$loc3 | jq -r '.[].id')
        ```

    - Create K8s clusters in each region

        ```bash
        az aks create \
          --name $clus1 \
          --resource-group $rg \
          --network-plugin azure \
          --vnet-subnet-id $loc1subid \
          --node-count $n_nodes \
          --node-vm-size $vm_type
        ```

        ```bash
        az aks create \
          --name $clus2 \
          --resource-group $rg \
          --network-plugin azure \
          --vnet-subnet-id $loc2subid \
          --node-count $n_nodes \
          --node-vm-size $vm_type
        ```

        ```bash
        az aks create \
          --name $clus3 \
          --resource-group $rg \
          --network-plugin azure \
          --vnet-subnet-id $loc3subid \
          --node-count $n_nodes \
          --node-vm-size $vm_type
        ```

    - Configure kubectl as shown below or use [this script](./04_get_credentials.sh).

        ```bash
        az aks get-credentials --name $clus1 --resource-group $rg
        ```

        ```bash
        az aks get-credentials --name $clus2 --resource-group $rg
        ```

        ```bash
        az aks get-credentials --name $clus3 --resource-group $rg
        ```

        - To switch contexts use

        ```bash
        kubectl config use-context crdb-aks-eastus
        kubectl config use-context crdb-aks-westus
        kubectl config use-context crdb-aks-northeurope
        ```

    - Test Network Connectivity as shown below or use [this script](./05_ping_test.sh).

        ```bash
        #Set Context north EU
        kubectl config use-context crdb-aks-northeurope
        #Create a test pod to ping
        kubectl run network-test --image=alpine --restart=Never -- sleep 999999
        # Get Ip addresss of pod to ping
        kubectl describe pods
        #Switch to Eastus context
        kubectl config use-context crdb-aks-eastus
        # Create a pod and ping the test pod
        kubectl run -it network-test --image=alpine --restart=Never -- ping 40.0.0.4
        ```

    - Download and configure the scripts to deploy CockroachDB. **NOTE**: This repo includes these files.
        1. Create a directory and download the required script and configuration files into it:   

            ```bash
            mkdir multiregion
            ```

            ```bash
            cd multiregion
            ```

            ```bash
            curl -OOOOOOOOO \
            https://raw.githubusercontent.com/cockroachdb/cockroach/master/cloud/kubernetes/multiregion/{README.md,client-secure.yaml,cluster-init-secure.yaml,cockroachdb-statefulset-secure.yaml,dns-lb.yaml,example-app-secure.yaml,external-name-svc.yaml,setup.py,teardown.py}
            ```

        2. Run [./06_contexts_regions.sh](./06_contexts_regions.sh) to generate the `context` and `regions` maps you'll need in the next steps.

            ```bash
            $ ./06_contexts_regions.sh 

            # Replace the existing contexts and regions definitions in setup.py with these:
            contexts = { 'westus': 'crdb-aks-westus', 'centralus': 'crdb-aks-centralus', 'eastus': 'crdb-aks-eastus' }
            regions = { 'westus': 'westus', 'centralus': 'centralus', 'eastus': 'eastus' }

            ```

            Use this output to edit `setup.py`.  **NOTE**: the `regions` map just maps each region to itself.

        3. If you haven't already, [install CockroachDB locally and add it to your `PATH`](https://www.cockroachlabs.com/docs/v20.1/install-cockroachdb). The `cockroach` binary will be used to generate certificates.

            If the `cockroach` binary is not on your `PATH`, in the `setup.py` script, set the `cockroach_path` variable to the path to the binary.

        4. Run the `setup.py` script: 

            ```bash
            python setup.py
            ```

            As the script creates various resources and creates and initializes the CockroachDB cluster, you'll see a lot of output, eventually ending with `job "cluster-init-secure" created`.

        5. Configure CoreDNS
            
            Each Kubernetes cluster has a [CoreDNS](https://coredns.io/) service that responds to DNS requests for pods in its region. CoreDNS can also forward DNS requests to pods in other regions.

            To enable traffic forwarding to CockroachDB pods in all 3 regions, you need to [modify the ConfigMap](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/#coredns-configmap-options) for the CoreDNS Corefile in each region.

            There are three sample config maps [here](./EXAMPLE).

            1. [This script](./07_gen_configmaps.sh) will create the three `configmap-*.yaml` files you need in the next step.

            ```bash
            $ ./07_gen_configmaps.sh
            ```

            These files will be named `configmap-`, the name of the region (the `$loc*` values from `env.sh`), then `.yaml`.

            2. For each region, first back up the existing ConfigMap:  

            ```bash
            kubectl -n kube-system get configmap coredns -o yaml > <configmap-backup-name>
            ```

            Then apply the new ConfigMaps.
            **NOTE** [This script](./08_apply_configmaps.sh) can instead be used to apply all three config maps.

            ```bash
            kubectl apply -f <configmap-name> --context <cluster-context>
            ```

            3. For each region, check that your CoreDNS settings were applied: 

            ```bash
            kubectl get -n kube-system cm/coredns -o yaml --context <cluster-context>
            ```

        6. Confirm that the CockroachDB pods in each cluster say `1/1` in
           the `READY` column, indicating that they've successfully joined the
           cluster.  **NOTE**: This could take from a couple of minutes to **hours**
           to take effect.  Be patient.

            ```bash
            kubectl get pods --selector app=cockroachdb --all-namespaces --context <cluster-context-1>
            ```

            > `NAMESPACE NAME READY STATUS RESTARTS AGE
            us-east1-b cockroachdb-0 1/1 Running 0 14m
            us-east1-b cockroachdb-1 1/1 Running 0 14m
            us-east1-b cockroachdb-2 1/1 Running 0 14m`

            ```bash
            kubectl get pods --selector app=cockroachdb --all-namespaces --context <cluster-context-2>
            ```

            > `NAMESPACE NAME READY STATUS RESTARTS AGE
            us-central1-a cockroachdb-0 1/1 Running 0 14m
            us-central1-a cockroachdb-1 1/1 Running 0 14m
            us-central1-a cockroachdb-2 1/1 Running 0 14m`

            ```bash
            kubectl get pods --selector app=cockroachdb --all-namespaces --context <cluster-context-3>
            ```

            > `NAMESPACE NAME READY STATUS RESTARTS AGE
            us-west1-a cockroachdb-0 1/1 Running 0 14m
            us-west1-a cockroachdb-1 1/1 Running 0 14m
            us-west1-a cockroachdb-2 1/1 Running 0 14m`


        7. SSH into one of the pods **OR** Create secure client

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

        8. Port forward the DB Console.  **NOTE**: you first need to create a
           user with admin rights so that you can log in to the console.

        ```bash
        kubectl port-forward cockroachdb-0 8080 --context $clus1 --namespace $loc1
        ```

