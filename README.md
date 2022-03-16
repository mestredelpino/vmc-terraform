# VMWare Cloud SDDC & TKG deployment with PowerCLI and Terraform

This repository deploys a software defined data center (SDDC) on VMware Cloud on AWS and a Tanzu Community Edition cluster on top of it.

The script consists of a phased terraform deployment which creates diverse infrastructure resources such as an SDDC, NSX-T segments and policies, a VPN tunnel with your on-premises 
infrastructure, a TKG management cluster, a TKG compute cluster and a shared services cluster, where packages will be installed. 
Additionally, it deploys a VPN tunnel between the VMC vSphere environment and the VLAN
your workstation is in, which is necessary to deploy the AVI and TKG OVA/OVF Files

### Setting up the environment

1. [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
2. [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-windows.html) and [add it to path](https://docs.aws.amazon.com/cli/latest/userguide/install-windows.html#awscli-install-windows-path)

### Setting up the credentials

1. [Extract your AWS credentials:](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication) <br/> <br/>
   1. Select the **Command line or programmatic access** option <br/>  <br/>
   ![alt text](SDDC-Deployment/images/aws_credentials_step1.png) <br/>  <br/>
   1. Copy the credentials from **option 3** for further use   <br/>  <br/>
   ![alt text](SDDC-Deployment/images/aws_credentials_step2.png)
2. [Generate a VMware Cloud token](https://docs.vmware.com/en/VMware-Cloud-services/services/Using-VMware-Cloud-Services/GUID-E2A3B1C1-E9AD-4B00-A6B6-88D31FCDDF7C.html) (with NSX Cloud admin & administrator rights)
3. Navigate to the phase1 directory, and insert your variables in terraform.tfvars. For a detailed explanation in the variables, check XXXX





## 1. Deploying an SDDC in VMWare Cloud on AWS

![alt text](SDDC-Deployment/images/vmc_on_aws.png)
1. Create a file called phase1/terraform.tfvars, and insert the following:
```
aws_account_number        = ""
sddc_a_connected_vpc_cidr = ""
vmc_refresh_token         = ""
Org                       = ""
sddc_a_name               = ""
vmc_org_id                = ""
sddc_a_region             = ""
```
2. Open a powershell console
3. Navigate to the *"phase1"* directory
4. Execute `terraform init`
5. Execute `terraform apply`


## 2. Creating NSX-T rules

In the following phase, diverse NSX-T rules will be created
1. Create a file called phase2/terraform.tfvars, and insert the following:
```
workstation_public_ip = ""
```
2. Navigate to the *"SDDC-Deployment/phase2"* directory
3. Execute `terraform init`
4. Execute `terraform apply`

And that is it! Your SDDC in VMware Cloud on AWS got deployed!