locals {
  infra = yamldecode(file("../../10-infra/generated/generated.infra.yaml"))
}

# Public DNS. Public apps that listed dns entries get one here pointing the the proxy VPS
resource "cloudflare_dns_record" "public" {
  for_each = toset(flatten([for app in module.apps.apps : app.public_vps_dns]))
  zone_id  = var.cloudflare_zone_id
  name     = each.value
  type     = "A"
  content  = local.infra.proxy_vps.address
  proxied  = false
  ttl      = 300
}
