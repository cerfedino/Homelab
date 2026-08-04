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

variable "seedbox" {
  type = object({
    host           = string
    port           = number
    use_ssl        = bool
    url_base       = string
    username       = string
    password       = string
    # absolute path of qbittorrent's download dir, with trailing slash
    downloads_path = string
  })
  sensitive = true
}

