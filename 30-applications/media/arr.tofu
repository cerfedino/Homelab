resource "sonarr_root_folder" "tvshows" {
  path = "/media/tvshows"
}

resource "radarr_root_folder" "movies" {
  path = "/media/movies"
}

# qbittorrent itself removes a torrent and its download once the limits are met
resource "sonarr_download_client_qbittorrent" "qbittorrent" {
  name                       = "qbittorrent"
  enable                     = true
  host                       = "qbittorrent.media.svc.cluster.local"
  port                       = 8080
  use_ssl                    = false
  username                   = var.qbittorrent.username
  password                   = var.qbittorrent.password
  tv_category                = "tvshows"
  initial_state              = 0
  remove_completed_downloads = false
  remove_failed_downloads    = true
  priority = 1
}

resource "radarr_download_client_qbittorrent" "qbittorrent" {
  name                       = "qbittorrent"
  enable                     = true
  host                       = "qbittorrent.media.svc.cluster.local"
  port                       = 8080
  use_ssl                    = false
  username                   = var.qbittorrent.username
  password                   = var.qbittorrent.password
  movie_category             = "movies"
  initial_state              = 0
  remove_completed_downloads = false
  remove_failed_downloads    = true
  priority = 1
}
