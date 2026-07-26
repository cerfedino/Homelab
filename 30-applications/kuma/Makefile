.NOTPARALLEL:

apply: helmfile-apply tofu-apply

helmfile-apply:
	cd ..; helmfile apply --skip-refresh -l name=kuma

tofu-apply:
	tofu init; tofu apply
