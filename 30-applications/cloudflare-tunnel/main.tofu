locals {
  apps    = yamldecode(file("../app-registry/generated/generated.apps-summary.yaml")).apps
  exposed = {for k, app in local.apps : k => app.external.dns_hostname if can(app.external.dns_hostname)}
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id = var.cloudflare_account_id
  name       = "homelab"
  config_src = "cloudflare" # ingress rules managed remotely via the _config resource
  tunnel_secret = var.tunnel_secret
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
  config = {
    ingress = concat(
      [for k, hostname in local.exposed : {
        hostname = hostname
        service  = "https://traefik.traefik.svc.cluster.local:443"
        origin_request = {
          origin_server_name = hostname
        }
      }],
      [{ service = "http_status:404" }] # mandatory catch-all, must be last
    )
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}

resource "cloudflare_dns_record" "apps" {
  for_each = local.exposed
  zone_id  = var.cloudflare_zone_id
  name     = each.value
  type     = "CNAME"
  content  = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied  = true
  ttl      = 1
}