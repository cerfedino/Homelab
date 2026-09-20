
import {
  to = proxmox_acme_dns_plugin.cloudflared
  id = "cloudflared"
}

resource "proxmox_acme_dns_plugin" "cloudflared" {
  plugin           = "cloudflared"
  api              = "cf"
  validation_delay = 120
  data             = var.acme_cloudflare
}

resource "proxmox_acme_certificate" "pve1" {
  node_name = var.proxmox_node_name
  account   = "default"
  domains = [
    { domain = local.machines[var.proxmox_node_name].fqdn_internal, plugin = proxmox_acme_dns_plugin.cloudflared.plugin },
    { domain = "${var.proxmox_node_name}.${var.domain_lan}", plugin = proxmox_acme_dns_plugin.cloudflared.plugin },
    { domain = local.machines[var.proxmox_node_name].fqdn_lan, plugin = proxmox_acme_dns_plugin.cloudflared.plugin },
  ]
}
