.NOTPARALLEL:
.PHONY: all tofu-apply artifacts

all: tofu-apply artifacts

tofu-apply:
	tofu init; tofu apply

artifacts:
	mkdir -p generated
	tofu output -show-sensitive -raw ansible_yaml_inventory  > generated/generated.inventory.yaml
	tofu output -show-sensitive -raw helmfile_values  > generated/generated.infra.yaml
