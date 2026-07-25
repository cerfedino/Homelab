output "helm_exposed_apps" {
  sensitive = true
  value = yamlencode({
    endpoints = [
      for k, app in var.applications :
       regex("^(?:https?://)?([^/:]+)", app.external_host)[0]
      if app.exposed
    ]
  })
}