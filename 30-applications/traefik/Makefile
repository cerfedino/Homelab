apply: helmfile-apply configure 

configure: helmfile-apply


helmfile-apply:
	cd ..; helmfile apply -l name=traefik



artifacts: 


generated/:
	mkdir -p generated
