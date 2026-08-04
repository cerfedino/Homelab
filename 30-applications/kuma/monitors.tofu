locals {
  monitored = merge([
    for base, variants in local.apps : {
      for variant, v in variants :
      "${base}_${variant}" => {
        name    = v.display_name
        url     = v.uptime_url
        variant = variant
      } if try(v.uptime_url, null) != null
    }
  ]...)
}

resource "uptimekuma_monitor_http" "apps" {
  for_each = local.monitored
  name     = each.value.name
  url      = each.value.url
  interval = 60
}

resource "uptimekuma_status_page" "internal" {
  slug      = "internal"
  title     = "Homelab (internal)"
  published = true
  public_group_list = [{
    name   = "Applications"
    weight = 1
    monitor_list = [
      for k, m in local.monitored : { id = uptimekuma_monitor_http.apps[k].id } if m.variant == "internal"
    ]
  }]
}

resource "uptimekuma_status_page" "external" {
  slug      = "external"
  title     = "Homelab"
  published = true
  public_group_list = [{
    name   = "Applications"
    weight = 1
    monitor_list = [
      for k, m in local.monitored : { id = uptimekuma_monitor_http.apps[k].id } if m.variant == "external"
    ]
  }]
}
