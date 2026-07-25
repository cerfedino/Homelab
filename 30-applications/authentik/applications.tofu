
data "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
}

# The embedded outpost is recreated everytime authentik starts, so we make sure to import it.
import {
  to = authentik_outpost.embedded
  id = data.authentik_outpost.embedded.id
}

# Outpost for applications reachable only from the local LAN
resource "authentik_outpost" "embedded" {
  name               = "authentik Embedded Outpost"
  type               = "proxy"
  protocol_providers = [
    for k in sort(keys(local.proxy_apps_local)) : tonumber(authentik_provider_proxy.proxies[k].id)
  ]
  config = jsonencode({
    log_level                        = "info"
    docker_labels                    = null
    authentik_host                   = "https://authentik.${local.generated.domain_lan}"
    docker_network                   = null
    container_image                  = null
    docker_map_ports                 = true
    refresh_interval                 = "minutes=5"
    kubernetes_replicas              = 1
    kubernetes_namespace             = "authentik"
    authentik_host_browser           = ""
    object_naming_template           = "ak-outpost-%(name)s"
    authentik_host_insecure          = false
    kubernetes_json_patches          = null
    kubernetes_service_type          = "ClusterIP"
    kubernetes_ingress_path_type     = null
    kubernetes_image_pull_secrets    = []
    kubernetes_ingress_class_name    = null
    kubernetes_disable_x509_strict   = false
    kubernetes_disabled_components   = []
    kubernetes_ingress_annotations   = {}
    kubernetes_ingress_secret_name   = "authentik-outpost-tls"
    kubernetes_httproute_annotations = {}
    kubernetes_httproute_parent_refs = []
  })
}


locals {
    proxy_apps = {for k, app in var.applications: k => app if app.type == "proxy"}

    redirect_apps =  {for k, app in var.applications: k=>app if app.type == "redirect"}

    proxy_apps_local    = {for k, app in local.proxy_apps : k => app if !app.exposed}
    proxy_apps_external = {for k, app in local.proxy_apps : k => app if app.exposed}
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
  meta_hide = each.value.hidden

  meta_description = each.value.meta_description
  meta_publisher = each.value.meta_publisher
  meta_icon = each.value.meta_icon
  meta_launch_url = each.value.external_host
}


data "authentik_service_connection_kubernetes" "local" {
  name = "Local Kubernetes Cluster"
}

# Outpost for applications reachable from the outside.
resource "authentik_outpost" "external" {
  count              = length(local.proxy_apps_external) > 0 ? 1 : 0
  name               = "external"
  type               = "proxy"
  service_connection = data.authentik_service_connection_kubernetes.local.id
  protocol_providers = [
    for k in sort(keys(local.proxy_apps_external)) : tonumber(authentik_provider_proxy.proxies[k].id)
  ]
  config = jsonencode({
    log_level               = "info"
    refresh_interval        = "minutes=5"
    authentik_host          = "http://authentik-server.authentik.svc.cluster.local"
    authentik_host_browser  = "https://authentik.${local.generated.domain}"
    authentik_host_insecure = false
    object_naming_template  = "ak-outpost-%(name)s"
    kubernetes_namespace    = "authentik"
    kubernetes_replicas     = 1
    kubernetes_service_type = "ClusterIP"
    kubernetes_disabled_components = ["ingress", "traefik middleware"]
  })
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
