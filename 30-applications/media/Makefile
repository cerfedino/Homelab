.NOTPARALLEL:

apply: helmfile-apply

helmfile-apply:
	cd ..; helmfile apply --skip-refresh -l name=media-extras
	cd ..; helmfile apply --skip-refresh -l name=jellyfin
	cd ..; helmfile apply --skip-refresh -l name=seerr
