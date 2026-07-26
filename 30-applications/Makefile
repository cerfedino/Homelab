
APPS := app-registry authentik cert-manager cloudflare-tunnel csi-proxmox kuma traefik

apps: $(APPS)

csi-proxmox cert-manager traefik authentik kuma cloudflare-tunnel: app-registry repos
traefik: csi-proxmox cert-manager
authentik: csi-proxmox traefik
kuma: csi-proxmox traefik authentik
cloudflare-tunnel: csi-proxmox authentik

repos:
	helmfile repos

$(APPS):
	$(MAKE) -C $@

.PHONY: apps repos $(APPS)
