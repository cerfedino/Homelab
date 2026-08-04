variable "prowlarr_api_key" {
  type      = string
  sensitive = true
}

variable "sonarr_api_key" {
  type      = string
  sensitive = true
}

variable "radarr_api_key" {
  type      = string
  sensitive = true
}

variable "qbittorrent" {
  type = object({
    username = string
    password = string
  })
  sensitive = true
}

