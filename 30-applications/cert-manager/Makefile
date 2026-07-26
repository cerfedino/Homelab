apply: helmfile-apply

helmfile-apply:
	cd ..; helmfile apply --skip-refresh -l name=cert-manager
	cd ..; helmfile apply --skip-refresh -l name=cert-manager-issuers
