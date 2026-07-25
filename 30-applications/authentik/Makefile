.NOTPARALLEL:

apply: helmfile-apply tofu-apply artifacts

helmfile-apply:
	cd ..; helmfile apply -l name=authentik

tofu-apply:
	tofu init; tofu apply

artifacts:
	mkdir -p generated
	tofu output -show-sensitive -raw helm_exposed_apps > generated/generated.exposed-apps.yaml
