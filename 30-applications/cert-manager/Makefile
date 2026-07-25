apply: helmfile-apply configure

configure: helmfile-apply


helmfile-apply:
	cd ..; helmfile apply -l name=cert-manager
	cd ..; helmfile apply -l name=cert-manager-issuers

