# terraform-openstack-cdh


This creates a manager VM with floating ip and n number of VMs that can be used for slave. This creates keypair and assumes that internal network is already created.
**Note**: This does not provision CDH yet. This is just setting up VMs so they can be provisioned.


## Deploy CDH VMS

### Prerequisites

Terraform openstack is not official yet. Included in this repo in the bin/* folder is pre built binary for Terraform OpenStack plugin.

### How to run

```bash
git clone https://github.com/trustedanalytics/terraform-openstack-cdh
cd terraform-openstack-cdh
cp terraform.tfvars.example terraform.tfvars
```

Next, edit `terraform.tfvars` using your text editor and fill out the variables with your own values (AWS credentials, AWS region, etc).

```bash
make plan
make apply
```
