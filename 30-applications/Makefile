
APPS := app-registry authentik backrest cert-manager cloudflare-tunnel csi-proxmox k8up kuma pihole traefik

apps: $(APPS)

csi-proxmox cert-manager traefik authentik kuma pihole cloudflare-tunnel k8up backrest: app-registry repos
traefik: csi-proxmox cert-manager
authentik: csi-proxmox traefik k8up
kuma: csi-proxmox traefik authentik k8up
pihole: csi-proxmox traefik authentik k8up
backrest: csi-proxmox traefik authentik
cloudflare-tunnel: csi-proxmox authentik

repos:
	helmfile repos

$(APPS):
	$(MAKE) -C $@

.PHONY: apps repos $(APPS)
