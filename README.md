terraform-openstack-cdh
========================

### Description

This creates a manager vm with floating ip and n number of vms that can be used for slave. This creates keypair and assumes that internal network is already created.
**Note**: This does not provision CDH yet. This is just setting up vms so they can be provisioned.


Deploy CDH VMS
--------------------

### Prerequisites

Terraform openstack is not official yet. Included in this repo in the bin/* folder is pre built binary for Terraform openstack plugin.

If needed, terraform openstack plugin can be build for other platforms. Please email <long@starkandwayne.com> to add it.

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
