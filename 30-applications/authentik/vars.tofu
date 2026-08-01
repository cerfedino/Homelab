
variable "users" {
    type = map(object({
      init_email = string
      enabled = bool
    }))

    validation {
      condition     = length(distinct([for u in var.users : lower(u.init_email)])) == length(var.users)
      error_message = "users init_email addresses must be unique."
    }
}

variable "groups" {
    type = map(object({
      is_superuser = bool
      users = list(string)
    }))
}
