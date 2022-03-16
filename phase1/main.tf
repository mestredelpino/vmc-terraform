# ---------------------------------------------------------------------------------------------------------------------
# SET UP LOCALS
# ---------------------------------------------------------------------------------------------------------------------

locals {
  name_spec        = "Automated TCE Deployment %s"
  sddc_a_name_spec = "${var.sddc_a_name} - %s"
  vm_network_ipv4_cidr_prefix_length = 24
  vm_network_dhcpv4_start            = 50
  vm_network_dhcpv4_end              = 250
  student_vm_username = "vmc-user"
  provider_type      = "AWS"
  sddc_a_region = replace(upper(var.sddc_a_region), "-", "_")
  sddc_a_vm_segment_name = "TCE-Management"
  sddc_a_vm_segment_gateway = cidrhost(var.sddc_a_vm_segment_cidr, 1)
  sddc_a_vm_segment_gateway_cidr = "${cidrhost(var.sddc_a_vm_segment_cidr, 1)}/${local.vm_network_ipv4_cidr_prefix_length}"
  sddc_a_vm_segment_dhcp_range = "${cidrhost(var.sddc_a_vm_segment_cidr, local.vm_network_dhcpv4_start)}-${cidrhost(var.sddc_a_vm_segment_cidr, 250)}"
  tags = {
    Terraform = "Managed by Terraform"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SET UP PROVIDERS AND REQUIRED VERSIONS
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.52.0"
    }
    vmc = {
      source  = "terraform-providers/vmc"
      version = "1.6.0"
    }
  }
  required_version = ">= 0.14"
}

provider "aws" {
  alias  = "region_a"
  region = var.sddc_a_region
}

provider "vmc" {
  org_id        = var.vmc_org_id
  refresh_token = var.vmc_refresh_token
}

# ---------------------------------------------------------------------------------------------------------------------
# SET UP THE NETWORKING AT THE AWS SIDE (RETRIEVE DATA VALUES AND CREATE RESOURCES)
# ---------------------------------------------------------------------------------------------------------------------

data "aws_availability_zone" "region_a_az1" {
  provider = aws.region_a
  zone_id = var.region_azs[var.sddc_a_region]["az1"]
}

data "vmc_connected_accounts" "vmc_connected_account" {
  account_number = var.aws_account_number
}

data "aws_route_tables" "sddc_a_connected_vpc" {
  provider = aws.region_a
  vpc_id = aws_vpc.sddc_a_connected_vpc.id
}

resource "aws_vpc" "sddc_a_connected_vpc" {
  provider = aws.region_a
  cidr_block = var.sddc_a_connected_vpc_cidr
  tags = merge(
  { Name = format(local.sddc_a_name_spec, "Connected VPC") },
  local.tags,
  )
}

resource "aws_subnet" "sddc_a_connected_vpc_subnet" {
  provider = aws.region_a
  count    = 2
  vpc_id               = aws_vpc.sddc_a_connected_vpc.id
  cidr_block           = cidrsubnet(aws_vpc.sddc_a_connected_vpc.cidr_block, 8, count.index)
  availability_zone_id = var.region_azs[var.sddc_a_region]["az${count.index + 1}"] # Ensuring the first subnet is created in an AZ with VMC capacity
  tags = merge(
  { Name = format(local.sddc_a_name_spec, "Subnet ${count.index + 1}") },
  local.tags,
  )
}

resource "aws_default_security_group" "sddc_a_default_security_group" {
  provider = aws.region_a
  vpc_id = aws_vpc.sddc_a_connected_vpc.id
  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }
  ingress {
    description = aws_vpc.sddc_a_connected_vpc.id
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = [var.sddc_a_connected_vpc_cidr]
  }
  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
  { Name = format(local.sddc_a_name_spec, "default security group") },
  local.tags,
  )
}

resource "aws_vpc_endpoint" "sddc_a" {
  provider = aws.region_a
  vpc_id            = aws_vpc.sddc_a_connected_vpc.id
  service_name      = "com.amazonaws.${var.sddc_a_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = tolist(data.aws_route_tables.sddc_a_connected_vpc.ids)
  tags = merge(
  { Name = format(local.sddc_a_name_spec, "S3 VPC Gateway Endpoint") },
  local.tags,
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY AN SDDC ON VMC
# ---------------------------------------------------------------------------------------------------------------------

resource "vmc_sddc" "sddc_a" {
  sddc_name           = var.sddc_a_name
  vpc_cidr            = var.sddc_a_mgmt_cidr
  num_host            = 1
  provider_type       = local.provider_type
  region              = local.sddc_a_region
  delay_account_link  = false
  skip_creating_vxlan = false
  sso_domain          = var.sso_domain
  deployment_type     = "SingleAZ"
  sddc_type           = "1NODE"
  vxlan_subnet        = var.sddc-cgw-network1


  account_link_sddc_config {
    customer_subnet_ids  = [aws_subnet.sddc_a_connected_vpc_subnet[0].id]
    connected_account_id = data.vmc_connected_accounts.vmc_connected_account.id
  }
  lifecycle {
    ignore_changes = [
      edrs_policy_type,
      max_hosts,
      min_hosts,
    ]
  }
}
