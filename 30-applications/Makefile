
APPS := app-registry authentik backrest cert-manager cloudflare-tunnel csi-proxmox immich k8up kuma nextcloud paperless pihole syncthing traefik vaultwarden woodpecker

apps: $(APPS)

csi-proxmox cert-manager traefik authentik kuma pihole cloudflare-tunnel k8up backrest immich vaultwarden paperless syncthing nextcloud woodpecker: app-registry repos
traefik: csi-proxmox cert-manager
authentik: csi-proxmox traefik k8up
kuma: csi-proxmox traefik authentik k8up
pihole: csi-proxmox traefik authentik k8up
backrest: csi-proxmox traefik authentik
cloudflare-tunnel: csi-proxmox authentik
immich: csi-proxmox traefik authentik k8up
vaultwarden: csi-proxmox traefik authentik k8up
paperless: csi-proxmox traefik authentik k8up
syncthing: csi-proxmox traefik authentik k8up
nextcloud: csi-proxmox traefik authentik k8up
woodpecker: csi-proxmox traefik authentik k8up

repos:
	helmfile repos

$(APPS):
	$(MAKE) -C $@

.PHONY: apps repos $(APPS)
