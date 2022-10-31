#!/bin/bash -e

# # # # #
# Init vars:
SCRIPT_NAME="$(basename $0)"

# # # # #
# Init funcs:
help_menu() {
    printf "\
  Crypto Chemistry State Sync Service
  Usage: snapshot_state_sync.sh [FLAGS]

  Flags:
  -r, --rpc string              (Required) The RPC server to state-sync with
  -n, --network string          (Required) The cosmos-sdk network name
  -d, --daemon string           (Required) The folder location of the daemon data
  -u, --userdir                 (Required) The user's home director
  -p, --healthcheck             (Optional) Enables sending Healthcheck pings
  -c, --healthcheck_url         (Optional) Sets the Healtcheck URL to ping
  -s, --service                 (Optional) The service name that controls the chain's deamon
  -h, --help                    (Optional) Help for the Crypto Chemistry Snapshot Uploader
"
}

make_opts() {
    # getopt boilerplate for argument parsing
    local _OPTS=$(getopt -o r:n:d:u:s:pc:h --long rpc:,network:,daemon:,userdir:,service:,healthcheck,healthcheck_url:,help \
            -n 'Crypto Chemistry Snapshot State-Sync' -- "$@")
    [[ $? != 0 ]] && { echo "Terminating..." >&2; exit 51; }
    eval set -- "${_OPTS}"
}

parse_args() {
    while true; do
    case "$1" in
        -r | --rpc ) RPC="$2"; shift 2 ;;
        -n | --network ) NETWORK="$2"; shift 2 ;;
        -d | --daemon ) DAEMON="$2"; shift 2 ;;
        -u | --userdir ) USER_DIR="$2"; shift 2 ;;
        -s | --service ) SERVICE="$2"; shift 2 ;;
        -p | --healthcheck ) HEALTHCHECK="True"; shift ;;
        -c | --healthcheck_url ) STATE_SYNC_HEALTHCHECK_URL="$2"; shift 2 ;;
        -h | --help ) HELP_MENU="True"; shift ;;
        -- ) shift; break ;;
        * ) break ;;
    esac
    done

    [[ ! -z $HELP_MENU ]] && { help_menu; exit 0; }

    if [[ -z $RPC || -z $NETWORK || -z $DAEMON || -z $USER_DIR ]]; then
        printf "\
        ${SCRIPT_NAME}: Error - Missing Arguments
        The following arguments are required:
            -r, --rpc
            -n, --network
            -d, --daemon
            -u, --userdir
    "
        exit 52
    fi
    if [[ -z $SERVICE ]]; then
        SERVICE="cosmovisor.service"
    fi
}

configure_state_sync() {
    #Stop daemon service
    sudo systemctl stop ${SERVICE}
    
    #Reset data
    printf "\n==> %s\n" "Resetting ${NETWORK} chain data"
    ${DAEMON} tendermint unsafe-reset-all --home ${USER_DIR}/.${NETWORK} > /dev/null || \
    ${DAEMON} unsafe-reset-all > /dev/null || \
    (printf "\n==> %s\n" "Unable to delete chain data" && exit 51)


    #Configure State Sync Settings
    LATEST_HEIGHT=$(curl -s $RPC/block | jq -r .result.block.header.height); \
    BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000)); \
    TRUST_HASH=$(curl -s "$RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

    sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
    s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$RPC,$RPC\"| ; \
    s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
    s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"|" ${USER_DIR}/.${NETWORK}/config/config.toml
}

sync_server() {
    printf "\n==> %s\n" "Starting state-sync"
    sudo systemctl start ${SERVICE}
    sleep 5
    #Check if still syncing
    while [[ $(${DAEMON} status 2> /dev/null | jq .SyncInfo.catching_up) != "false" ]]; do
        printf "\n==> %s\n" "Node is still syncing. Sleeping for 30 seconds."
        sleep 30
    done
    printf "\n==> %s\n" "State Sync is complete"
}

disable_state_sync() {
    printf "\n==> %s\n" "Disabling State-Sync in ${USER_DIR}/.${NETWORK}/config/config.toml"
    sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1false|" ${USER_DIR}/.${NETWORK}/config/config.toml
}

healthcheck() {
    printf "\n==> %s\n" "Sending healthcheck to ${STATE_SYNC_HEALTHCHECK_URL}"
    if [[ ! -z ${HEALTHCHECK} && ! -z ${STATE_SYNC_STATE_SYNC_HEALTHCHECK_URL} ]]; then
        curl -m 10 --retry 5 ${STATE_SYNC_HEALTHCHECK_URL}
    fi
}

# # # # #
# Main:
make_opts
parse_args "${@}"
configure_state_sync
sync_server
disable_state_sync
healthcheck
exit "${?}"