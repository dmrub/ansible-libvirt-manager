ROOT_DIR=$THIS_DIR/..
CFG_CONFIG_FILE=${CFG_CONFIG_FILE:-$ROOT_DIR/config.yml}
CFG_CONFIG_FILE_DIR=$(dirname "$CFG_CONFIG_FILE")

ANSIBLE_DIR=$ROOT_DIR/ansible
ANSIBLE_PLAYBOOKS_DIR=$ANSIBLE_DIR/playbooks
ANSIBLE_INVENTORY_DIR=$ROOT_DIR/inventory
ANSIBLE_INVENTORY=$ANSIBLE_INVENTORY_DIR/inventory.cfg

CFG_CONFIG_DIR=${CFG_CONFIG_DIR:-~/.ansible}
CFG_VAULT_FILE=${CFG_VAULT_FILE:-$ROOT_DIR/ansible-vault.yml}
CFG_VARS_FILE=${CFG_VARS_FILE:-$ROOT_DIR/ansible-vars.yml}

export ANSIBLE_PRIVATE_KEY_FILE=${ANSIBLE_PRIVATE_KEY_FILE:-~/.ssh/cluster_id_rsa}
export ANSIBLE_VAULT_PASSWORD_FILE=${ANSIBLE_VAULT_PASSWORD_FILE:-${CFG_CONFIG_DIR}/vault_pass.txt}
export ANSIBLE_CONFIG=$ANSIBLE_DIR/ansible.cfg
export ANSIBLE_FILTER_PLUGINS=$ANSIBLE_DIR/filter_plugins
export ANSIBLE_ROLES_PATH=$ANSIBLE_DIR/roles

error() {
    echo >&2 "Error: $@"
}

fatal() {
    error "$@"
    exit 1
}

abspath() {
    readlink -f "${1}" 2>/dev/null || \
        python -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "${1}" 
}

print-info() {
    echo "Current Configuration:"
    echo "Configuration file:            $(abspath "$CFG_CONFIG_FILE")"
    echo
    echo "Ansible inventory file:        $(abspath "$ANSIBLE_INVENTORY")"
    echo "Config directory:              $(abspath "$CFG_CONFIG_DIR")"
    echo "Ansible vault password file:   $(abspath "$ANSIBLE_VAULT_PASSWORD_FILE")"
    echo "Ansible remote user:           $ANSIBLE_REMOTE_USER"
    echo "Ansible private SSH key file:  $(abspath "$ANSIBLE_PRIVATE_KEY_FILE")"
    echo
}

check-config() {
    if [[ ! -d "$CFG_CONFIG_DIR" ]]; then
        fatal "Configuration directory does not exist, run $(abspath "$THIS_DIR/configure.sh")"
    fi
    if [[ ! -e "$ANSIBLE_VAULT_PASSWORD_FILE" ]]; then
        fatal "Ansible vault password file does not exist, run $(abspath "$THIS_DIR/configure.sh")"
    fi
    #if [[ -z "$ANSIBLE_REMOTE_USER" ]]; then
    #    fatal "Remote user name is not configured, run $THIS_DIR/configure.sh"
    #fi
    if [[ -n "${ANSIBLE_PRIVATE_KEY_FILE}" ]]; then
        if [[ ! -e "${ANSIBLE_PRIVATE_KEY_FILE}" || ! -e "${ANSIBLE_PRIVATE_KEY_FILE}.pub" ]]; then
            fatal "SSH keys ${ANSIBLE_PRIVATE_KEY_FILE} or ${ANSIBLE_PRIVATE_KEY_FILE}.pub missing, run $(abspath "$THIS_DIR/configure.sh")"
        fi
    fi
}

check-inventory() {
    local inv_dir=$(dirname "$1")
    #if [[ ! -e "${inv_dir}/group_vars" ]]; then
    #    fatal "group_vars directory is missing in ${inv_dir} inventory directory"
    #fi
}

ansible_playbook() {
    local inventory=$1
    check-config
    check-inventory "$inventory"
    echo "+ ansible-playbook -i $@"
    ansible-playbook -i "$@"
}

run-ansible() {
    local opts
    opts=()
    if [[ -n "$ANSIBLE_REMOTE_USER" ]]; then
        opts+=(--user "$ANSIBLE_REMOTE_USER")
    fi
    if [[ -e "$CFG_VAULT_FILE" ]]; then
        opts+=(--extra-vars @"$CFG_VAULT_FILE")
    fi
    if [[ -e "$CFG_VARS_FILE" ]]; then
        opts+=(--extra-vars @"$CFG_VARS_FILE")
    fi

    echo "+ ansible -i \"$ANSIBLE_INVENTORY\" \
${opts[*]} \
$*"

    ansible -i "$ANSIBLE_INVENTORY" \
            "${opts[@]}" \
            "$@"
}

run-ansible-playbook() {
    check-config
    check-inventory "$ANSIBLE_INVENTORY"

    local opts
    opts=()
    if [[ -n "$ANSIBLE_REMOTE_USER" ]]; then
        opts+=(--user "$ANSIBLE_REMOTE_USER")
    fi
    if [[ -e "$CFG_VAULT_FILE" ]]; then
        opts+=(--extra-vars @"$CFG_VAULT_FILE")
    fi
    if [[ -e "$CFG_VARS_FILE" ]]; then
        opts+=(--extra-vars @"$CFG_VARS_FILE")
    fi
    echo "+ ansible-playbook --inventory \"$ANSIBLE_INVENTORY\" \
${opts[*]} \
$*"
    ansible-playbook --inventory "$ANSIBLE_INVENTORY" \
                     "${opts[@]}" \
                     "$@"
}

# $1 - filename
# $2 - variable prefix, CFG_ is used by default
read-config-file() {
    local configfile=$1
    local prefix=$2
    if [[ ! -f "$configfile" ]]; then echo >&2 "[read-config-file] '$configfile' is not a file"; return 1; fi
    if [[ -z "$prefix" ]]; then prefix=CFG_; fi

    local lhs rhs cfg exitcode

    cfg=$(tr -d '\r' < "$configfile")
    exitcode=$?
    if [ "$exitcode" != "0" ]; then return $exitcode; fi

    while IFS='=' read -rs lhs rhs;
    do
        if [[ "$lhs" =~ ^[A-Za-z_][A-Za-z_0-9]*$ && -n "$lhs" ]]; then
            rhs="${rhs%%\#*}"               # Del in line right comments
            rhs="${rhs%"${rhs##*[^ ]}"}"    # Del trailing spaces
            rhs="${rhs%\"*}"                # Del opening string quotes
            rhs="${rhs#\"*}"                # Del closing string quotes
            declare -g "${prefix}${lhs}"="${rhs}"
        fi
    done <<<"$cfg"
}


eval "$("$THIS_DIR/configure.py" --shell-config)"

#if [[ -e "$CFG_CONFIG_FILE" ]]; then
#    read-config-file "$CFG_CONFIG_FILE" "CFG_"
#    export ANSIBLE_REMOTE_USER=${CFG_ANSIBLE_REMOTE_USER:-$ANSIBLE_REMOTE_USER}
#    export ANSIBLE_PRIVATE_KEY_FILE=${CFG_ANSIBLE_PRIVATE_KEY_FILE:-$ANSIBLE_PRIVATE_KEY_FILE}
#    export ANSIBLE_INVENTORY=${CFG_ANSIBLE_INVENTORY:-$ANSIBLE_INVENTORY}
#    if [[ "$ANSIBLE_INVENTORY" != /* ]]; then
#        ANSIBLE_INVENTORY=$(abspath "${ROOT_DIR}/${ANSIBLE_INVENTORY}")
#    fi
#fi
