apply: configure helmfile-apply

configure: tofu-apply artifacts


helmfile-apply: configure
	cd ..; helmfile apply -l name=cloudflare-tunnel
tofu-apply:
	tofu init; tofu apply



artifacts: generated/generated.cloudflare-tunnel-token.yaml

generated/generated.cloudflare-tunnel-token.yaml: generated/
	tofu output -show-sensitive -raw helm_cloudflare_tunnel_token > $@



generated/:
	mkdir -p generated
