.NOTPARALLEL:

apply: helmfile-apply

helmfile-apply:
	cd ..; helmfile apply --skip-refresh -l name=windmill-extras
	cd ..; helmfile apply --skip-refresh -l name=windmill
