resource "prowlarr_sync_profile" "standard" {
  name                      = "standard"
  enable_rss                = true
  enable_automatic_search   = true
  enable_interactive_search = true
  minimum_seeders           = 1
}

resource "prowlarr_tag" "flaresolverr" {
  label = "flaresolverr"
}

resource "prowlarr_indexer_proxy_flaresolverr" "flaresolverr" {
  name            = "flaresolverr"
  host            = "http://flaresolverr.media.svc.cluster.local:8191/"
  request_timeout = 60
  tags            = [prowlarr_tag.flaresolverr.id]
}

resource "prowlarr_application_sonarr" "sonarr" {
  name         = "Sonarr"
  sync_level   = "fullSync"
  prowlarr_url = "http://prowlarr.media.svc.cluster.local:9696"
  base_url     = "http://sonarr.media.svc.cluster.local:8989"
  api_key      = var.sonarr_api_key
}

resource "prowlarr_application_radarr" "radarr" {
  name         = "Radarr"
  sync_level   = "fullSync"
  prowlarr_url = "http://prowlarr.media.svc.cluster.local:9696"
  base_url     = "http://radarr.media.svc.cluster.local:7878"
  api_key      = var.radarr_api_key
}
