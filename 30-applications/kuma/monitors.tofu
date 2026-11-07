locals {
  monitored = merge([
    for name, app in local.apps : { for m in app.monitors : "${name}/${m.name}" => m }
  ]...)
}

resource "uptimekuma_monitor_http" "apps" {
  for_each = local.monitored
  name     = each.value.name
  url      = each.value.url
  interval = 60
}

resource "uptimekuma_status_page" "homelab" {
  slug      = "homelab"
  title     = "Homelab"
  published = true
  public_group_list = [{
    name   = "Applications"
    weight = 1
    monitor_list = [
      for k in sort(keys(local.monitored)) : { id = uptimekuma_monitor_http.apps[k].id }
    ]
  }]
}
