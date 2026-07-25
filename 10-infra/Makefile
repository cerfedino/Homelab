.PHONY: all tofu-apply artifacts

all: tofu-apply artifacts



tofu-apply:
	tofu init; tofu apply



artifacts: generated/generated.inventory.yaml generated/generated.infra.yaml

generated/generated.inventory.yaml: tofu-apply generated/
	tofu output -show-sensitive -raw ansible_yaml_inventory  > $@
generated/generated.infra.yaml: tofu-apply generated/
	tofu output -show-sensitive -raw helmfile_values  > $@

generated/:
	mkdir -p generated
