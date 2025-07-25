## EKS/Terraform demo

A simple Terraform EKS installation using the automode configuration and locally defined node categories instead of the default ones

This code and documentation is something of a work in progress, so will likely get updated from time to time

A Thinkpad with Ubuntu 24.04.2 LTS was used for development

### Prerequisites for client

  - AWS account with awscli environment configured
  - Terraform installed and configured
  - ```kubectl``` installed

### Enable EC2 spot instances
Required if you want to use EC2 spot instances
```
aws iam create-service-linked-role --aws-service-name spot.amazonaws.com || true
```
If the role has already been created, you will see:

`An error occurred (InvalidInput) when calling the CreateServiceLinkedRole operation: Service role name AWSServiceRoleForEC2Spot has been taken in this account, please try a different suffix.`

### Provisioning using the Terraform code

Note that this code uses the AWS Region `eu-north-1` so if you want to use another for any reason you'll need to change the value in `main.tf` as well as for the awscli command given on this page to update the local `kubeconfig` file

The Terraform state files are stored locally, which is good enough here

Once the prerequisites are in place, the usual sequence of commands applies:
```
terraform init
terraform plan
terraform apply --auto-approve
```
And when that is done, the local `kubeconfig` file can be updated:
```
aws eks --region eu-west-1 update-kubeconfig --alias demo-cluster --name demo-cluster
```

Check the node classes and pools:
```
kubectl get nodeclasses
kubectl get nodepools
```

Because it's an automode cluster, no nodes will be shown until pods have been successfully deployed. When trouble-shooting failed provisioning, the following command can sometimes provide useful information:
```
kubectl get nodeclaims
```

The folder [inflate](/inflate) has a simple deployment manifest that can be used to verify that nodes can be provisioned in different node pools

Once done with the environment, clean up with:
```
terraform destroy
```
