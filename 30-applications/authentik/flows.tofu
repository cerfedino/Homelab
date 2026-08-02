


# USER SETTINGS FLOW
# name and email self-service

resource "authentik_flow" "user_settings" {
  name           = "homelab-user-settings"
  title          = "Update details"
  slug           = "homelab-user-settings"
  designation    = "stage_configuration"
  authentication = "require_authenticated"
}

resource "authentik_stage_prompt_field" "settings_name" {
  name                     = "settings-field-name"
  field_key                = "name"
  label                    = "Full name"
  type                     = "text"
  required                 = true
  order                    = 0
  initial_value            = "return user.name"
  initial_value_expression = true
}

resource "authentik_stage_prompt_field" "settings_email" {
  name                     = "settings-field-email"
  field_key                = "email"
  label                    = "Email"
  type                     = "email"
  required                 = true
  order                    = 1
  initial_value            = "return user.email"
  initial_value_expression = true
}

resource "authentik_stage_prompt" "user_settings" {
  name = "user-settings-prompt"
  fields = [
    authentik_stage_prompt_field.settings_name.id,
    authentik_stage_prompt_field.settings_email.id,
  ]
}

resource "authentik_stage_user_write" "user_settings" {
  name               = "user-settings-write"
  user_creation_mode = "never_create"
}

resource "authentik_stage_email" "user_settings" {
  name                     = "user-settings-email-confirm"
  use_global_settings      = true
  activate_user_on_success = false
  subject                  = "Confirm your email change"
  template                 = "email/account_confirmation.html"
  token_expiry             = "minutes=14"
}

resource "authentik_flow_stage_binding" "user_settings_prompt" {
  target = authentik_flow.user_settings.uuid
  stage  = authentik_stage_prompt.user_settings.id
  order  = 10
}

resource "authentik_flow_stage_binding" "user_settings_email" {
  target = authentik_flow.user_settings.uuid
  stage  = authentik_stage_email.user_settings.id
  order  = 20
  evaluate_on_plan     = false
  re_evaluate_policies = true
}


resource "authentik_policy_expression" "settings_pending_user" {
  name       = "user-settings-pending-user"
  expression = <<-EOT
    user = request.user
    plan = request.context.get("flow_plan")
    if plan:
        new_email = plan.context.get("prompt_data", {}).get("email")
        if new_email:
            user.email = new_email
        plan.context["pending_user"] = user
    request.context["pending_user"] = user
    return True
  EOT
}

resource "authentik_policy_binding" "user_settings_email_pending_user" {
  target = authentik_flow_stage_binding.user_settings_email.id
  policy = authentik_policy_expression.settings_pending_user.id
  order  = 0
}

resource "authentik_flow_stage_binding" "user_settings_write" {
  target = authentik_flow.user_settings.uuid
  stage  = authentik_stage_user_write.user_settings.id
  order  = 30
}

resource "authentik_brand" "homelab_lan" {
  branding_favicon    = "/static/dist/assets/icons/icon.png"
  branding_logo       = "/static/dist/assets/icons/icon_left_brand.svg"
  domain              = "authentik.${local.generated.domain_lan}"
  default             = false
  flow_authentication = authentik_flow.homelab_login.uuid
  flow_recovery       = authentik_flow.homelab-recovery.uuid
  flow_user_settings  = authentik_flow.user_settings.uuid
}

resource "authentik_brand" "homelab_external" {
  branding_favicon    = "/static/dist/assets/icons/icon.png"
  branding_logo       = "/static/dist/assets/icons/icon_left_brand.svg"
  domain              = "authentik.${local.generated.domain}"
  default             = false
  flow_authentication = authentik_flow.homelab_login.uuid
  flow_recovery       = authentik_flow.homelab-recovery.uuid
  flow_user_settings  = authentik_flow.user_settings.uuid
}

# TODO: FInd a way to undefault the default one in favour of one branding

# RECOVERY FLOW

resource "authentik_flow" "homelab-recovery" {
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
  token_expiry             = "minutes=14"
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
  target = authentik_flow.homelab-recovery.uuid
  stage  = authentik_stage_identification.recovery.id
  order  = 10
}

resource "authentik_flow_stage_binding" "recovery_email" {
  target = authentik_flow.homelab-recovery.uuid
  stage  = authentik_stage_email.recovery.id
  order  = 20
}

resource "authentik_flow_stage_binding" "recovery_prompt" {
  target = authentik_flow.homelab-recovery.uuid
  stage  = authentik_stage_prompt.recovery.id
  order  = 30
}

resource "authentik_flow_stage_binding" "recovery_write" {
  target = authentik_flow.homelab-recovery.uuid
  stage  = authentik_stage_user_write.recovery.id
  order  = 40
}


# LOGIN FLOW

resource "authentik_flow" "homelab_login" {
  name           = "homelab_login"
  title          = "Sign in"
  slug           = "homelab_login"
  designation    = "authentication"
  authentication = "require_unauthenticated"
}

resource "authentik_stage_identification" "login" {
  name          = "login-identification"
  user_fields   = ["username"]
  recovery_flow = authentik_flow.homelab-recovery.uuid
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
  session_duration = "days=30"
}

resource "authentik_flow_stage_binding" "login_identification" {
  target = authentik_flow.homelab_login.uuid
  stage  = authentik_stage_identification.login.id
  order  = 10
}

resource "authentik_flow_stage_binding" "login_2fa" {
  target = authentik_flow.homelab_login.uuid
  stage  = authentik_stage_authenticator_validate.login.id
  order  = 20
}

resource "authentik_flow_stage_binding" "login_user_login" {
  target = authentik_flow.homelab_login.uuid
  stage  = authentik_stage_user_login.login.id
  order  = 30
}
