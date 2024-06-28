# TFE FDO Nomad on AWS
Install Terraform Enterprise on Nomad with Redis + S3 + DB from AWS as an active-active installation

This repository is based on the following repositories

- Terraform Enterprise active-active with replicated from [here](https://github.com/munnep/tfe_aws_active_mode_step)
- Terraform Enterprise FDO with docker single instance from [here](https://github.com/munnep/tfe_next_aws_external)
- The nomad getting started tutorial from [here](https://developer.hashicorp.com/nomad/tutorials/get-started/gs-start-a-cluster)

This code will create a Nomad Server and Nomad client on which we will deploy Terraform Enterprise FDO

- Create an instance with Nomad Server
- Create an instance with Nomad client
- Create S3 buckets used for TFE
- Generate TLS certificates with Let's Encrypt to be used by TFE
- Create a VPC network with subnets, security groups, internet gateway
- Create a RDS PostgreSQL to be used by TFE
- Create a Redis database

# Diagram

Detailed Diagram of the environment:  


# Prerequisites

## License
Make sure you have a TFE license available for use

## AWS
We will be using AWS. Make sure you have the following
- AWS account  
- Install AWS cli [See documentation](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

## Install terraform  
See the following documentation [How to install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

## TLS certificate
You need to have valid TLS certificates that can be used with the DNS name you will be using to contact the TFE instance.  
  
The repo assumes you have no certificates and want to create them using Let's Encrypt and that your DNS domain is managed under AWS. 

# How to

## Build TFE active/active environment
- Clone the repository to your local machine
```sh
git clone https://github.com/munnep/tfe_aws_fdo_nomad.git
```
- Go to the directory
```sh
cd tfe_aws_fdo_nomad
```
- Set your AWS credentials
```sh
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_SESSION_TOKEN=
```
- create a file called `variables.auto.tfvars` with the following contents and your own values. Example will create 2 TFE nodes at the start.  
```hcl
tag_prefix                 = "tfe21"                                    # TAG prefix for names to easily find your AWS resources
region                     = "eu-north-1"                               # Region to create the environment
vpc_cidr                   = "10.221.0.0/16"                            # subnet mask that can be used 
rds_password               = "Password#1"                               # password used for the RDS environment
dns_hostname               = "tfe21"                                    # DNS hostname for the TFE
dns_zonename               = "aws.munnep.com"                           # DNS zone name to be used
tfe_password               = "Password#1"                               # TFE password for the dashboard and encryption of the data
certificate_email          = "patrick.munne@hashicorp.com"              # Your email address used by TLS certificate registration
terraform_client_version   = "1.1.7"                                    # Terraform version you want to have installed on the client machine
public_key                 = "ssh-rsa AAAAB3Nzf"                        # The public key for you to connect to the server over SSH
tfe_active_active          = true                                       # TFE instance setup of active/active - false to start with
tfe_license                = "<your_license>"                           # license key for TFE as string
tfe_release                = "v202309-1"                                # version of TFE you want to install
```
- Terraform initialize
```sh
terraform init
```
- Terraform plan
```sh
terraform plan
```
- Terraform apply
```sh
terraform apply
```
- Terraform output should create 58 resources and show you the public dns string you can use to connect to the TFE instance
```sh
Plan: 45 to add, 0 to change, 0 to destroy.

Outputs:

```
- The ssh_tfe_server is empty. You will have to do another terraform apply for this to be visible as at the end of the former execution the server are not in a running state yet
```sh
terraform apply
```
- Output is now visible to 
```

## testing

- Go to the directory test_code
```sh
cd test_code
```
- login to your terraform environment just created
```sh
terraform login tfe21.aws.munnep.com
```
- Edit the `main.tf` file with the hostname of your TFE environment
```hcl
terraform {
  cloud {
    hostname = "tfe21.aws.munnep.com"
    organization = "test"

    workspaces {
      name = "test"
    }
  }
}
```
- Run terraform init
```sh
terraform init
```
- run terraform apply
```sh
terraform apply
```
output
```sh
Plan: 1 to add, 0 to change, 0 to destroy.


Do you want to perform these actions in workspace "test-agent"?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

terraform_data.test: Creating...
terraform_data.test: Creation complete after 0s [id=de1c6969-e277-26f1-5434-9020b03ed3fd]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```



# TODO


# DONE



