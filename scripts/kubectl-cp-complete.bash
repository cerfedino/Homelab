__kubectl_cp_remote()
{
    local cur prev words cword split
    _init_completion -n =: || return
    if [[ " ${words[*]:1:cword-1} " != *" cp "* || $cur != *:* ]]; then
        __start_kubectl
        return
    fi
    compopt +o default
    local spec=${cur%%:*} path=${cur#*:} dir= base i name quoted
    local -a opts=()
    [[ $spec == */* ]] && opts=(-n "${spec%%/*}")
    for ((i = 1; i < cword; i++)); do
        case ${words[i]} in
            -n | --namespace | -c | --container) opts+=("${words[i]}" "${words[i + 1]}") ;;
            --namespace=* | --container=*) opts+=("${words[i]}") ;;
        esac
    done
    [[ $path == */* ]] && dir=${path%/*}/
    base=${path##*/}
    COMPREPLY=()
    while IFS= read -r name; do
        printf -v quoted %q "$name"
        [[ $quoted == "$base"* ]] && COMPREPLY+=("$spec:$dir$quoted")
    done < <(kubectl "${opts[@]}" exec "${spec##*/}" -- sh -c "cd ${dir:-.} && ls -1Ap" 2>/dev/null)
    [[ $COMP_WORDBREAKS == *:* ]] && COMPREPLY=("${COMPREPLY[@]#"$spec:"}")
    [[ ${#COMPREPLY[@]} == 1 && ${COMPREPLY[0]} == */ ]] && compopt -o nospace
}
complete -o default -F __kubectl_cp_remote kubectl k
