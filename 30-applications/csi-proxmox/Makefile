apply: helmfile-apply configure 

configure: helmfile-apply


helmfile-apply:
	cd ..; helmfile apply -l name=csi-proxmox



artifacts: 


generated/:
	mkdir -p generated
