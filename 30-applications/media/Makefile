.NOTPARALLEL:

apply: helmfile-apply tofu-apply

tofu-apply:
	tofu init; tofu apply

helmfile-apply:
	cd ..; helmfile apply --skip-refresh -l name=media-extras
	cd ..; helmfile apply --skip-refresh -l name=jellyfin
	cd ..; helmfile apply --skip-refresh -l name=seerr
	cd ..; helmfile apply --skip-refresh -l name=sonarr
	cd ..; helmfile apply --skip-refresh -l name=radarr
	cd ..; helmfile apply --skip-refresh -l name=prowlarr
	cd ..; helmfile apply --skip-refresh -l name=flaresolverr
