.NOTPARALLEL:

apply: helmfile-apply

helmfile-apply:
	cd ..; helmfile apply --skip-refresh -l name=immich-extras
	cd ..; helmfile apply --skip-refresh -l name=immich
