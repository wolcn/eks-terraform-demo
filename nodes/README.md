### Comments on node classes and node pools

- The default node classes and pools have been replaced by custom pools and classes. Initially this was because it is not possible to set custom tags on resources using the default classes, but the default pools also included legacy instance types. With custom pools the instance generations can be managed and legacy types avoided
- Both classes and pools are based on the defaults, but the old names (`system` and `general-purpose`) have not been reused in order to avoid potential conflicts
- The `core` pool is the equivalent of the `system` pool and retains the setting that allows use of both x64 and arm64 instances. This pool is intended for shared non-application specific pods and requires both a toleration of the taint `CriticalAddonsOnly` and a node selector setting `karpenter.sh/nodepool: core`
- The `application` pool is x64 only, replaces the `general-purpose` pool and like that pool, functions as the default pool
- The node selector setting `eks.amazonaws.com/compute-type: auto` is used to ensure that pods are placed on nodes provisioned using the automode functionality; only really relevant in a cluster with where non-automode nodes also exist
- Useful blog post [Using Amazon EC2 Spot Instances with Karpenter](https://aws.amazon.com/blogs/containers/using-amazon-ec2-spot-instances-with-karpenter/)
- Instance type is set using the key `karpenter.sh/capacity-type`
  - If `spot` instances are included in the application pool they will be used when available, otherwise `on-demand` will be used. This requires that applications are able to deal with interruptions gracefully when spot nodes are recycled and pods are recycled
  - Access to EC2 spot instances needs to be enabled if the `spot` instance category is included in the node pools; if not enabled, a deadlock may occur if the provisioner tries to spin up a spot instance
  - From the Karpenter documentation: *For Spot interruptions, the NodePool will start a new node as soon as it sees the Spot interruption warning. Spot interruptions have a 2 minute notice before Amazon EC2 reclaims the instance. Once Karpenter has received this warning it will begin draining the node while in parallel provisioning a new node. Karpenter’s average node startup time means that, generally, there is sufficient time for the new node to become ready before EC2 initiates termination for the spot instance.*
  - Pods running in the `core` pool are assumed to be important to keep running so these nodes should not be set to `spot`
  - If `reserved` instances that match the requirements are available, these are used in preference to other types

- A new category with support for nodes with GPU added
  - The GPU node category spins up `g` instances only; there is another GPU instance category `p`, but those things are `.48xlarge` only and likely intended for AI model building
  - Pods for the GPU nodes need to tolerate a taint with the value `gpu` and use the node selector `karpenter.sh/nodepool: gpu`

- The values for `ephemeralStorage:` in the node class manifests might be minimum values - nodes failed to provision when these values were reduced (the values were originally taken from the default automode node class)
