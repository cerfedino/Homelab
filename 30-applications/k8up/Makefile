.NOTPARALLEL:

apply: helmfile-apply

helmfile-apply:
	cd ..; helmfile apply --skip-refresh -l name=k8up-globals
	cd ..; helmfile apply --skip-refresh -l name=k8up
