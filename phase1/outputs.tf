output "sddc_a_name" {
  value = var.sddc_a_name
}

output "sddc_a_nsxt_reverse_proxy_url" {
  value = vmc_sddc.sddc_a.nsxt_reverse_proxy_url
}

output "sddc_a_vsphere_user" {
  value = vmc_sddc.sddc_a.cloud_username
}

output "sddc_a_vsphere_password" {
  value     = vmc_sddc.sddc_a.cloud_password
  sensitive = true
}

output "sddc_a_vsphere_url" {
  value = vmc_sddc.sddc_a.vc_url
}

output "sddc_a_vm_segment_name" {
  value = local.sddc_a_vm_segment_name
}

output "sddc_a_vm_segment_cidr" {
  value = var.sddc_a_vm_segment_cidr
}

output "sddc_a_vm_segment_gateway" {
  value = local.sddc_a_vm_segment_gateway
}

output "sddc_a_vm_segment_gateway_cidr" {
  value = local.sddc_a_vm_segment_gateway_cidr
}

output "sddc_a_vm_segment_dhcp_range" {
  value = local.sddc_a_vm_segment_dhcp_range
}

output "name_specs" {
  value = {
    name_spec        = local.name_spec
    sddc_a_name_spec = local.sddc_a_name_spec
  }
}

output "vmc_refresh_token" {
  value = var.vmc_refresh_token
  sensitive = true
}


