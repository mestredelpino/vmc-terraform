# ---------------------------------------------------------------------------------------------------------------------
# SET UP THE .TFSTATE FROM PHASE 1 AS DATA SOURCE
# ---------------------------------------------------------------------------------------------------------------------

data "terraform_remote_state" "phase1" {
  backend = "local"

  config = {
    path = "../phase1/terraform.tfstate"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEFINE THE LOCALS AND DATA VALUES
# ---------------------------------------------------------------------------------------------------------------------

locals {
  endpoint_tag_scope = "Endpoint"
  # aws_variables = jsondecode(file("${path.module}/../variables_json/aws_variables.json"))
  # sddc_variables = jsondecode(file("${path.module}/../variables_json/sddc_variables.json"))
  # tanzu_variables = jsondecode(file("${path.module}/../variables_json/tanzu_variables.json"))
  # vmc_variables = jsondecode(file("${path.module}/../variables_json/vmc_variables.json"))
  # vpn_variables = jsondecode(file("${path.module}/../variables_json/vpn_variables.json"))
  tags = {
    Terraform = "Managed by Terraform"
  }
}

# data "local_file" "cgw_snat_ip_file" {
#   filename = "../phase1/cgw_snat_ip.txt"
# }

data "nsxt_policy_transport_zone" "sddc_a_tz" {
  provider     = nsxt
  display_name = "vmc-overlay-tz"
}

# ---------------------------------------------------------------------------------------------------------------------
# SET THE TERRAFORM PROVIDERS AND REQUIRED VERSIONS
# ---------------------------------------------------------------------------------------------------------------------


terraform {
  required_providers {
    nsxt = {
      source  = "vmware/nsxt"
      version = ">= 3.2.2"
    }
  }
  required_version = ">= 0.14"
}

provider "nsxt" {
  host              = data.terraform_remote_state.phase1.outputs.sddc_a_nsxt_reverse_proxy_url
  vmc_token         = data.terraform_remote_state.phase1.outputs.vmc_refresh_token
  enforcement_point = "vmc-enforcementpoint"
}


# ---------------------------------------------------------------------------------------------------------------------
# COMPUTE GATEWAY
# ---------------------------------------------------------------------------------------------------------------------


resource "nsxt_policy_fixed_segment" "sddc_a_default_vm_network" {
  provider            = nsxt
  display_name        = data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_name
  connectivity_path   = "/infra/tier-1s/cgw"
  transport_zone_path = data.nsxt_policy_transport_zone.sddc_a_tz.path

  subnet {
    cidr        = data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_gateway_cidr
    dhcp_ranges = [data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_dhcp_range]
    dhcp_v4_config {
      dns_servers = ["8.8.8.8"]
      lease_time     = 5400
    }
  }
}

# Define the Compute Gateway (CGW) policy groups in SDDC A

resource "nsxt_policy_group" "sddc_a_vm_segment" {
  provider     = nsxt
  domain       = "cgw"
  display_name = data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_name
  description = format(
  data.terraform_remote_state.phase1.outputs.name_specs.name_spec,
  "${data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_name} Compute Group.",
  )
  criteria {
    path_expression {
      member_paths = [nsxt_policy_fixed_segment.sddc_a_default_vm_network.path]
    }
  }
  conjunction { operator = "OR" }
  criteria {
    ipaddress_expression {
      ip_addresses = [data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_cidr]
    }
  }
}

resource "nsxt_policy_group" "workstation_cgw" {
  provider = nsxt
  domain = "cgw"
  display_name = "workstation_cgw"
  criteria {
    ipaddress_expression {
      ip_addresses = [var.workstation_public_ip]
    }
  }
}


# Deploy the Compute Gateway (CGW) policies

resource "nsxt_policy_predefined_gateway_policy" "cgw_policy" {
  provider = nsxt
  path     = "/infra/domains/cgw/gateway-policies/default"
  rule {
    action                = "ALLOW"
    destination_groups    = []
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "Default VTI Rule"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "default_vti"
    nsx_id                = "default-vti-rule"
    profiles              = []
    scope                 = ["/infra/labels/cgw-vpn"]
    services              = []
    source_groups         = []
    sources_excluded      = false
  }

  rule {
    action                = "ALLOW"
    destination_groups    = []
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "VPC Inbound/Outbound Rule"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "vpc_inbound_outbound"
    notes                 = "Break this up into granular rules."
    profiles              = []
    scope                 = ["/infra/labels/cgw-cross-vpc"]
    services              = []
    source_groups         = []
    sources_excluded      = false
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# MANAGEMENT GATEWAY
# ---------------------------------------------------------------------------------------------------------------------

# DEPLOY THE MANAGEMENT GATEWAY POLICY GROUPS


resource "nsxt_policy_group" "workstation" {
  provider     = nsxt
  domain       = "mgw"
  display_name = "workstation"

  criteria {
    ipaddress_expression {
      ip_addresses = [var.workstation_public_ip]
    }
  }
}

# resource "nsxt_policy_group" "source_nat_ip" {
#   provider     = nsxt
#   domain       = "mgw"
#   display_name = "Source NAT IP"
#   criteria {
#     ipaddress_expression {
#       ip_addresses = [data.local_file.cgw_snat_ip_file.content]
#     }
#   }
# }

# Define the Management Gateway policies.

resource "nsxt_policy_predefined_gateway_policy" "sddc_a_mgw_policy" {
  provider = nsxt
  path     = "/infra/domains/mgw/gateway-policies/default"

  rule {
    action                = "ALLOW"
    destination_groups    = []
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "vCenter Outbound Rule"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "vcenter_outbound"
    profiles              = []
    scope                 = ["/infra/labels/mgw"]
    services              = []
    source_groups         = ["/infra/domains/mgw/groups/VCENTER"]
    sources_excluded      = false

  }

  rule {
    action                = "ALLOW"
    destination_groups    = ["/infra/domains/mgw/groups/VCENTER"]
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "Allow vCenter access from the workstation from where the SDDC creation is executed"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "vcenter_inbound"
    profiles              = []
    scope                 = ["/infra/labels/mgw"]
    services              = ["/infra/services/HTTPS"]
    source_groups         = [nsxt_policy_group.workstation.path]
    sources_excluded      = false
  }

  rule {
    action                = "ALLOW"
    destination_groups    = []
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "ESXi Outbound Rule"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "esxi_outbound"
    profiles              = []
    scope                 = ["/infra/labels/mgw"]
    services              = []
    source_groups         = ["/infra/domains/mgw/groups/ESXI"]
    sources_excluded      = false
  }
}