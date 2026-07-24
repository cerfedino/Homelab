output "helm_cloudflare_proxies" {
  sensitive = true
  value = yamlencode({
    endpoints = [
      for k, app in var.applications :
       regex("^(?:https?://)?([^/:]+)", app.external_host)[0]
      if app.exposed
    ]
  })
}