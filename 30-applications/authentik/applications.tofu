
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
    applications = yamldecode(file("../app-registry/generated/generated.applications.yaml"))

    fwauth_variants = {
        for k, app in local.applications : k => merge(app, {
            variant = endswith(k, "_external") ? "external" : "internal"
        }) if app.type == "forward-auth" && app.dns_hostname != null
    }
    proxy_apps_local    = {for k, v in local.fwauth_variants : k => v if v.variant == "internal"}
    proxy_apps_external = {for k, v in local.fwauth_variants : k => v if v.variant == "external"}

    oidc_apps = {for k, app in local.applications : k => app if app.type == "oidc"}
}

data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-implicit-consent"
}
data "authentik_flow" "default-invalidation-flow" {
  slug = "default-invalidation-flow"
}

resource "authentik_provider_proxy" "proxies" {
  for_each = local.fwauth_variants
  mode               = "forward_single"
  name               = each.key
  external_host      = "https://${each.value.dns_hostname}"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  authentication_flow = authentik_flow.homelab_login.uuid
  invalidation_flow = data.authentik_flow.default-invalidation-flow.id
}


data "authentik_flow" "default-provider-invalidation-flow" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_property_mapping_provider_scope" "oidc_scopes" {
  for_each   = toset([for s in flatten([for k, app in local.oidc_apps : app.oidc.scopes]) : s if s != "email"])
  scope_name = each.value
}

# map this property to true because vaultwarden SSO expects it. authentik as far as i know doesnt track email verification status
resource "authentik_property_mapping_provider_scope" "email_verified" {
  name       = "email (verified)"
  scope_name = "email"
  expression = <<-EOT
    return {
        "email": request.user.email,
        "email_verified": True,
    }
  EOT
}

data "authentik_certificate_key_pair" "generated" {
  name = "authentik Self-signed Certificate"
}

resource "authentik_provider_oauth2" "oidc" {
  for_each = local.oidc_apps
  name     = each.key

  client_id     = each.value.oidc.client_id
  client_secret = each.value.oidc.client_secret
  client_type   = each.value.oidc.client_type
  grant_types   = each.value.oidc.grant_types

  authorization_flow = data.authentik_flow.default-authorization-flow.id
  authentication_flow = authentik_flow.homelab_login.uuid
  invalidation_flow  = data.authentik_flow.default-provider-invalidation-flow.id

  allowed_redirect_uris = [
    for r in each.value.oidc.redirect_uris : {
      matching_mode = r.matching_mode
      url           = r.url
      redirect_uri_type = "authorization"
    }
  ]
  property_mappings = [
    for s in each.value.oidc.scopes : (
      s == "email" ? authentik_property_mapping_provider_scope.email_verified.id : data.authentik_property_mapping_provider_scope.oidc_scopes[s].id
    )
  ]
  signing_key = each.value.oidc.signing ? data.authentik_certificate_key_pair.generated.id : null

  sub_mode                   = each.value.oidc.sub_mode
  issuer_mode                = each.value.oidc.issuer_mode
  include_claims_in_id_token = each.value.oidc.include_claims_in_id_token
  access_code_validity       = each.value.oidc.access_code_validity
  access_token_validity      = each.value.oidc.access_token_validity
  refresh_token_validity     = each.value.oidc.refresh_token_validity
}



# Recreate each application instead of editing it in place
resource "terraform_data" "app_revision" {
  for_each         = local.applications
  triggers_replace = each.value
}

resource "authentik_application" "apps" {
  for_each = local.applications
  name              = each.value.display_name
  slug              = each.key
  protocol_provider = (
    each.value.type == "forward-auth" && each.value.dns_hostname != null ? tonumber(authentik_provider_proxy.proxies[each.key].id) :
    each.value.type == "oidc" ? tonumber(authentik_provider_oauth2.oidc[each.key].id) :
    null
  )

  group = each.value.group
  policy_engine_mode= each.value.policy_engine_mode
  meta_hide = each.value.hidden

  meta_description = each.value.meta_description
  meta_publisher = each.value.meta_publisher
  meta_icon = each.value.meta_icon
  meta_launch_url = each.value.href_url

  lifecycle {
    replace_triggered_by = [terraform_data.app_revision[each.key]]
  }
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
        for k, app in local.applications : {
            for i, g in app.allowed_groups : "${k}/${g}" => { app = k, group = g, order = i }
        }
    ]...)
  target   = authentik_application.apps[each.value.app].uuid
  group    = authentik_group.groups[each.value.group].id
  order    = each.value.order
}

resource "authentik_policy_binding" "app_allowed_users" {
  for_each =  merge([
        for k, app in local.applications : {
            for i, u in app.allowed_users : "${k}/${u}" => { app = k, user = u, order = 100 + i }
        }
    ]...)
  target   = authentik_application.apps[each.value.app].uuid
  user     = tonumber(authentik_user.users[each.value.user].id)
  order    = each.value.order
}
