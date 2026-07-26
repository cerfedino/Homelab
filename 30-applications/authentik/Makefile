.NOTPARALLEL:

apply: helmfile-apply tofu-apply

helmfile-apply:
	cd ..; helmfile apply -l name=authentik

tofu-apply:
	tofu init; tofu apply
