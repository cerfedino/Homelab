


resource "authentik_brand" "homelab" {
  branding_favicon    = "/static/dist/assets/icons/icon.png"
  branding_logo       = "/static/dist/assets/icons/icon_left_brand.svg"
  domain              = "authentik.${local.generated.domain_lan}"
  default             = false
  flow_authentication = authentik_flow.login.uuid
  flow_recovery       = authentik_flow.recovery.uuid
}


# RECOVERY FLOW

resource "authentik_flow" "recovery" {
  name           = "homelab-recovery"
  title          = "Set your password"
  slug           = "homelab-recovery"
  designation    = "recovery"
  authentication = "require_unauthenticated"
}

resource "authentik_stage_identification" "recovery" {
  name        = "recovery-identification"
  user_fields = ["username", "email"]
}

resource "authentik_stage_email" "recovery" {
  name                     = "recovery-email"
  use_global_settings      = true
  activate_user_on_success = false
  subject                  = "Set your password"
  template                 = "email/password_reset.html"
  token_expiry             = "minutes=30"
}

resource "authentik_stage_prompt_field" "name" {
  name      = "recovery-field-name"
  field_key = "name"
  label     = "Full name"
  type      = "text"
  required  = true
  order     = 0
}

resource "authentik_stage_prompt_field" "password" {
  name      = "recovery-field-password"
  field_key = "password"
  label     = "Password"
  type      = "password"
  required  = true
  order     = 1
}

resource "authentik_stage_prompt_field" "password_repeat" {
  name      = "recovery-field-password-repeat"
  field_key = "password_repeat"
  label     = "Repeat password"
  type      = "password"
  required  = true
  order     = 2
}

resource "authentik_stage_prompt" "recovery" {
  name = "recovery-prompt"
  fields = [
    authentik_stage_prompt_field.name.id,
    authentik_stage_prompt_field.password.id,
    authentik_stage_prompt_field.password_repeat.id,
  ]
}

resource "authentik_stage_user_write" "recovery" {
  name               = "recovery-write"
  user_creation_mode = "never_create"
}

resource "authentik_flow_stage_binding" "recovery_identification" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_identification.recovery.id
  order  = 10
}

resource "authentik_flow_stage_binding" "recovery_email" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_email.recovery.id
  order  = 20
}

resource "authentik_flow_stage_binding" "recovery_prompt" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_prompt.recovery.id
  order  = 30
}

resource "authentik_flow_stage_binding" "recovery_write" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_user_write.recovery.id
  order  = 40
}


# LOGIN FLOW

resource "authentik_flow" "login" {
  name           = "homelab-login"
  title          = "Sign in"
  slug           = "homelab-login"
  designation    = "authentication"
  authentication = "require_unauthenticated"
}

resource "authentik_stage_identification" "login" {
  name          = "login-identification"
  user_fields   = ["username"]
  recovery_flow = authentik_flow.recovery.uuid
  password_stage = authentik_stage_password.login.id
  enable_remember_me = true
}

resource "authentik_stage_password" "login" {
  name     = "login-password"
  backends = ["authentik.core.auth.InbuiltBackend"]
}

resource "authentik_stage_authenticator_totp" "setup" {
  name = "login-totp-setup"
}

resource "authentik_stage_authenticator_validate" "login" {
  name                  = "login-2fa-validate"
  device_classes        = ["totp"]
  not_configured_action = "configure"
  configuration_stages  = [authentik_stage_authenticator_totp.setup.id]
}

resource "authentik_stage_user_login" "login" {
  name = "login-user-login"
}

resource "authentik_flow_stage_binding" "login_identification" {
  target = authentik_flow.login.uuid
  stage  = authentik_stage_identification.login.id
  order  = 10
}

resource "authentik_flow_stage_binding" "login_2fa" {
  target = authentik_flow.login.uuid
  stage  = authentik_stage_authenticator_validate.login.id
  order  = 20
}

resource "authentik_flow_stage_binding" "login_user_login" {
  target = authentik_flow.login.uuid
  stage  = authentik_stage_user_login.login.id
  order  = 30
}
