## EKS/Terraform demo

A simple Terraform EKS installation using the automode configuration and locally defined node categories instead of the default ones    

This code and documentation is something of a work in progress, so will likely get updated from time to time    

### Prerequisites for client    
(a Thinkpad with Ubuntu 24.04.2 LTS was the client used for development)    

  - AWS account with awscli environment configured    
  - Terraform installed and configured    
  - ```kubectl``` installed    

### Provisioning using the Terraform code

Note that this code uses the AWS Region `eu-north-1` - if you want to use another for any reason you'll need to change the value in `main.tf` as well as for example the awscli commands on this page

The Terraform state files are stored locally, which is good enough here

Once the prerequisites are in place, the usual sequence of commands applies:
```
terraform init
terraform plan
terraform apply --auto-approve
```
And when that is done, the local `kubeconfig` file can be updated:
```
aws eks --region eu-north-1 update-kubeconfig --alias demo-cluster --name demo-cluster
```

Check the node classes and pools:
```
kubectl get nodeclasses
kubectl get nodepools
```

Because it's an automode cluster, no nodes will be shown until pods have been sucessfully deployed. When trouble-shooting failed provisioning, the following command can sometimes provide useful information:
```
kubectl get nodeclaims
```

The folder ```inflate/```has a simple manifest that can be used to verify that nodes can be provisioned in different node pools

Once done with the environment, clean up with the usual:
```
terraform destroy
```
