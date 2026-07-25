apply: helmfile-apply configure

configure: tofu-apply artifacts


helmfile-apply:
	cd ..; helmfile apply -l name=authentik
tofu-apply: helmfile-apply
	tofu init; tofu apply






artifacts: generated/generated.exposed-apps.yaml

generated/generated.exposed-apps.yaml: generated/
	tofu output -show-sensitive -raw helm_exposed_apps > $@

generated/:
	mkdir -p generated