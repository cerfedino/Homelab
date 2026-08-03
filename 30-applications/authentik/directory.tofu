
resource "authentik_user" "users" {
  for_each = var.users
  name = each.key
  username = each.key
  email    = each.value.init_email
  is_active = each.value.enabled

  lifecycle {
    ignore_changes = [name, email]
    prevent_destroy = true
  }
}

resource "authentik_group" "groups" {
  for_each     = var.groups
  name         = each.key
  is_superuser = each.value.is_superuser
  users        = [for u in each.value.users : authentik_user.users[u].id]
}

# service account LDAP applications bind with to search the directory
resource "authentik_user" "ldapsearch" {
  username = "ldapsearch"
  name     = "ldapsearch"
  type     = "service_account"
  password = local.values.ldap_search_password
}

resource "authentik_rbac_role" "ldap_search" {
  name = "ldap-search"
}

resource "authentik_rbac_permission_role" "ldap_search" {
  role       = authentik_rbac_role.ldap_search.id
  permission = "authentik_providers_ldap.search_full_directory"
}

resource "authentik_group" "ldapsearch" {
  name  = "ldapsearch"
  users = [authentik_user.ldapsearch.id]
  roles = [authentik_rbac_role.ldap_search.id]
}
