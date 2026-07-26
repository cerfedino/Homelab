
APPS := app-registry authentik cert-manager cloudflare-tunnel csi-proxmox traefik

apps: $(APPS)

csi-proxmox cert-manager traefik authentik cloudflare-tunnel: app-registry
traefik: csi-proxmox cert-manager
authentik: csi-proxmox traefik
cloudflare-tunnel: csi-proxmox authentik

$(APPS):
	$(MAKE) -C $@

.PHONY: apps $(APPS)
