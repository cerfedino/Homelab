
export REPO_ROOT="$(git rev-parse --show-toplevel)"
export TF_VAR_REPO_ROOT="$REPO_ROOT"

export KUBECONFIG="$REPO_ROOT/20-bootstrap/generated.kubeconfig.yaml"
export KUBE_EDITOR="code --wait"

export SOPS_AGE_KEY_FILE="$REPO_ROOT/.sops/keys.txt"

command -v pre-commit >/dev/null && [ ! -f "$(git rev-parse --git-path hooks/pre-commit 2>/dev/null)" ] && pre-commit install >/dev/null 2>&1 || true

helm plugin list 2>/dev/null | grep -q '^diff' || helm plugin install --verify=false https://github.com/databus23/helm-diff >/dev/null 2>&1 || true

[ -n "$BASH_VERSION" ] && case "$-" in *i*) eval 'source <(kubectl completion bash) && source <(helm completion bash) && source <(helmfile completion bash) && alias k=kubectl && complete -o default -F __start_kubectl k' ;; esac || true