.NOTPARALLEL:

apply: tofu-apply artifacts

tofu-apply:
	tofu init; tofu apply

artifacts:
	mkdir -p generated
	tofu output -show-sensitive -raw helm_apps_summary > generated/generated.apps-summary.yaml
	tofu output -show-sensitive -raw helm_oidc > generated/generated.oidc.yaml
	tofu output -show-sensitive -raw applications > generated/generated.applications.yaml
