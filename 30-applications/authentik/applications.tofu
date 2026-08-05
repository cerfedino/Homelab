
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
    authentik_host                   = "https://${local.applications["authentik_internal"].dns_hostname}"
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
    ldap_apps = {for k, app in local.applications : k => app if app.type == "ldap"}
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
  skip_path_regex    = each.value.skip_path_regex
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  authentication_flow = authentik_flow.homelab_login.uuid
  invalidation_flow = data.authentik_flow.default-invalidation-flow.id
}


data "authentik_flow" "default-provider-invalidation-flow" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_property_mapping_provider_scope" "oidc_scopes" {
  for_each   = toset([for s in flatten([for k, app in local.oidc_apps : app.oidc.scopes]) : s if s != "email" && s != "groups"])
  scope_name = each.value
}

# process oidc group claim mapping
resource "authentik_property_mapping_provider_scope" "app_group_map" {
  for_each   = {for k, app in local.oidc_apps : k => app.oidc.group_map if app.oidc.group_map != null}
  name       = "groups mapping (${each.key})"
  scope_name = "groups"
  expression = <<-EOT
    mapping = ${jsonencode(each.value)}
    groups = []
    for src, dst in mapping.items():
        if request.user.ak_groups.filter(name=src).exists():
            groups.append(dst)
    return {"groups": groups}
  EOT
}

# take the profile_claims attribute for each user and merge it into the profile claims
resource "authentik_property_mapping_provider_scope" "profile_claims" {
  name       = "profile (user claims)"
  scope_name = "profile"
  expression = <<-EOT
    claims = request.user.attributes.get("profile_claims") or {}
    return {k: v for k, v in claims.items() if v is not None}
  EOT
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
  property_mappings = concat(
    [
      for s in each.value.oidc.scopes : (
        s == "email" ? authentik_property_mapping_provider_scope.email_verified.id :
        s == "groups" ? authentik_property_mapping_provider_scope.app_group_map[each.key].id :
        data.authentik_property_mapping_provider_scope.oidc_scopes[s].id
      )
    ],
    [authentik_property_mapping_provider_scope.profile_claims.id],
  )
  signing_key = each.value.oidc.signing ? data.authentik_certificate_key_pair.generated.id : null

  sub_mode                   = each.value.oidc.sub_mode
  issuer_mode                = each.value.oidc.issuer_mode
  include_claims_in_id_token = each.value.oidc.include_claims_in_id_token
  access_code_validity       = each.value.oidc.access_code_validity
  access_token_validity      = each.value.oidc.access_token_validity
  refresh_token_validity     = each.value.oidc.refresh_token_validity
}

resource "authentik_provider_ldap" "ldap" {
  for_each = local.ldap_apps
  name     = each.key

  base_dn = each.value.ldap.base_dn

  bind_flow   = authentik_flow.ldap_login.uuid
  unbind_flow = data.authentik_flow.default-invalidation-flow.id

  bind_mode   = each.value.ldap.bind_mode
  search_mode = each.value.ldap.search_mode
  mfa_support = each.value.ldap.mfa_support

  certificate     = each.value.ldap.certificate ? data.authentik_certificate_key_pair.generated.id : null
  tls_server_name = each.value.ldap.tls_server_name

  uid_start_number = each.value.ldap.uid_start_number
  gid_start_number = each.value.ldap.gid_start_number
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
    each.value.type == "ldap" ? tonumber(authentik_provider_ldap.ldap[each.key].id) :
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
    authentik_host_browser  = "https://${local.applications["authentik_external"].dns_hostname}"
    authentik_host_insecure = false
    object_naming_template  = "ak-outpost-%(name)s"
    kubernetes_namespace    = "authentik"
    kubernetes_replicas     = 1
    kubernetes_service_type = "ClusterIP"
    kubernetes_disabled_components = ["ingress", "traefik middleware"]
  })
}


# Outpost serving LDAP
resource "authentik_outpost" "ldap" {
  count              = length(local.ldap_apps) > 0 ? 1 : 0
  name               = "ldap"
  type               = "ldap"
  service_connection = data.authentik_service_connection_kubernetes.local.id
  protocol_providers = [
    for k in sort(keys(local.ldap_apps)) : tonumber(authentik_provider_ldap.ldap[k].id)
  ]
  config = jsonencode({
    log_level               = "info"
    refresh_interval        = "minutes=5"
    authentik_host          = "http://authentik-server.authentik.svc.cluster.local"
    authentik_host_browser  = ""
    authentik_host_insecure = false
    object_naming_template  = "ak-outpost-%(name)s"
    kubernetes_namespace    = "authentik"
    kubernetes_replicas     = 1
    kubernetes_service_type = "ClusterIP"
  })
}

resource "authentik_policy_binding" "ldap_search_access" {
  for_each = local.ldap_apps
  target   = authentik_application.apps[each.key].uuid
  group    = authentik_group.ldapsearch.id
  order    = 200
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
