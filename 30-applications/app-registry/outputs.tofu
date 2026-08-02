locals {
  app_bases = {for k, app in var.applications : k => trimsuffix(trimsuffix(k, "_external"), "_internal")}

  app_variants = {
    for k, app in var.applications : k => merge(app, {
      app     = local.app_bases[k]
      variant = endswith(k, "_external") ? "external" : "internal"
    })
  }
}

output "helm_apps_summary" {
  sensitive = true
  value = yamlencode({
    apps = {
      for base in distinct(values(local.app_bases)) : base => {
        for vk, v in local.app_variants : v.variant => merge(
          v.dns_hostname != null ? { dns_hostname = v.dns_hostname } : {},
          v.href_url != null ? { href_url = v.href_url } : {},
          v.uptime_url != null ? { uptime_url = v.uptime_url } : {}
        ) if v.app == base
      }
    }
  })
}

# OIDC client credentials per application key
output "helm_oidc" {
  sensitive = true
  value = yamlencode({
    oidc = {
      for k, app in var.applications : k => {
        client_id     = app.oidc.client_id
        client_secret = app.oidc.client_secret
        issuer = "https://${var.applications["authentik_${endswith(k, "_external") ? "external" : "internal"}"].dns_hostname}/application/o/${k}/"
      } if app.oidc != null
    }
  })
}

# for authentik to consume once again
output "applications" {
  sensitive = true
  value     = yamlencode(var.applications)
}
