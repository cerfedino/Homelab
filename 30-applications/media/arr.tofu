
resource "sonarr_download_client_qbittorrent" "seedbox" {
  name                       = "seedbox"
  enable                     = true
  host                       = var.seedbox.host
  port                       = var.seedbox.port
  use_ssl                    = var.seedbox.use_ssl
  url_base                   = var.seedbox.url_base
  username                   = var.seedbox.username
  password                   = var.seedbox.password
  tv_category                = "tvshows"
  remove_completed_downloads = false
  remove_failed_downloads    = false
  priority = 1
}

resource "radarr_download_client_qbittorrent" "seedbox" {
  name                       = "seedbox"
  enable                     = true
  host                       = var.seedbox.host
  port                       = var.seedbox.port
  use_ssl                    = var.seedbox.use_ssl
  url_base                   = var.seedbox.url_base
  username                   = var.seedbox.username
  password                   = var.seedbox.password
  movie_category             = "movies"
  remove_completed_downloads = false
  remove_failed_downloads    = false
  priority = 1
}





resource "sonarr_root_folder" "tvshows" {
  path = "/media/tvshows"
}

resource "radarr_root_folder" "movies" {
  path = "/media/movies"
}

resource "sonarr_remote_path_mapping" "seedbox" {
  host        = var.seedbox.host
  remote_path = var.seedbox.downloads_path
  local_path  = "/mnt/seedbox/"
}

resource "radarr_remote_path_mapping" "seedbox" {
  host        = var.seedbox.host
  remote_path = var.seedbox.downloads_path
  local_path  = "/mnt/seedbox/"
}
