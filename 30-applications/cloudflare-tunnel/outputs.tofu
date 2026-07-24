


output "helm_cloudflare_tunnel" {
  sensitive = true
  value = yamlencode({
    cloudflareTunnelToken = data.cloudflare_zero_trust_tunnel_cloudflared_token.homelab.token
  })
}
