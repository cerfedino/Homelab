provider "minio" {
  minio_server   = var.hetzner_s3.endpoint
  minio_region   = var.hetzner_s3.region
  minio_user     = var.hetzner_s3.access_key # gitleaks:allow
  minio_password = var.hetzner_s3.secret_key # gitleaks:allow
  minio_ssl      = true
}

resource "minio_s3_bucket" "backups" {
  bucket = var.backup_bucket
  acl    = "private"
}
