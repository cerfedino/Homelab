
resource "authentik_user" "users" {
  for_each = var.users
  name = each.key
  username = each.key
  email    = each.value.init_email
  is_active = each.value.enabled

  lifecycle {
    ignore_changes = [name, email]
  }
}

resource "authentik_group" "groups" {
  for_each     = var.groups
  name         = each.key
  is_superuser = each.value.is_superuser
  users        = [for u in each.value.users : authentik_user.users[u].id]
}
