
data "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
}


locals {
    proxy_apps = {for k, app in var.applications: k => app if app.type == "proxy"}

    redirect_apps =  {for k, app in var.applications: k=>app if app.type == "redirect"}
}

data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-implicit-consent"
}
data "authentik_flow" "default-invalidation-flow" {
  slug = "default-invalidation-flow"
}

resource "authentik_provider_proxy" "proxies" {
  for_each = local.proxy_apps
  mode               = "forward_single"
  name               = "Provider for ${each.value.display_name}"
  external_host      = each.value.external_host
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow = data.authentik_flow.default-invalidation-flow.id
}



resource "authentik_application" "apps" {
  for_each = var.applications
  name              = each.value.display_name
  slug              = each.key
  protocol_provider = each.value.type == "proxy" ? tonumber(authentik_provider_proxy.proxies[each.key].id) : null

  group = each.value.group
  policy_engine_mode= each.value.policy_engine_mode

  meta_description = each.value.meta_description
  meta_publisher = each.value.meta_publisher
  meta_icon = each.value.meta_icon
  meta_launch_url = each.value.meta_launch_url
}


resource "authentik_outpost_provider_attachment" "provider_attachment" {
  for_each = local.proxy_apps
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.proxies[each.key].id
}

resource "authentik_policy_binding" "app_allowed_groups" {
  for_each = merge([
        for k, app in var.applications : {
            for i, g in app.allowed_groups : "${k}/${g}" => { app = k, group = g, order = i }
        }
    ]...)
  target   = authentik_application.apps[each.value.app].uuid
  group    = authentik_group.groups[each.value.group].id
  order    = each.value.order
}

resource "authentik_policy_binding" "app_allowed_users" {
  for_each =  merge([
        for k, app in var.applications : {
            for i, u in app.allowed_users : "${k}/${u}" => { app = k, user = u, order = 100 + i }
        }
    ]...)
  target   = authentik_application.apps[each.value.app].uuid
  user     = tonumber(authentik_user.users[each.value.user].id)
  order    = each.value.order
}
