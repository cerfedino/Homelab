
APPS := authentik cert-manager cloudflare-tunnel csi-proxmox kuma traefik

apps: $(APPS)

traefik: csi-proxmox cert-manager
authentik: csi-proxmox traefik
kuma: csi-proxmox traefik
cloudflare-tunnel: csi-proxmox authentik

$(APPS):
	$(MAKE) -C $@

.PHONY: apps $(APPS)