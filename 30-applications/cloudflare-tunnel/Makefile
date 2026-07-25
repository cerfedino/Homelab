.NOTPARALLEL:

apply: tofu-apply artifacts helmfile-apply

tofu-apply:
	tofu init; tofu apply

artifacts:
	mkdir -p generated
	tofu output -show-sensitive -raw helm_cloudflare_tunnel_token > generated/generated.cloudflare-tunnel-token.yaml

helmfile-apply:
	cd ..; helmfile apply -l name=cloudflare-tunnel
