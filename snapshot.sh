#!/bin/bash -e

# # # # #
# Init vars:
SCRIPT_NAME="$(basename $0)"

# # # # #
# Init funcs:
help_menu() {
    printf "\
  Crypto Chemistry Snapshot Uploader
  Usage: snapshot.sh [FLAGS]

  Flags:
  -b, --bucket string           (Required) The S3 Bucket name
  -e, --endpoint string         (Required) The S3 endpoint
  -i, --id string               (Required) The tenant ID
  -n, --network string          (Required) The cosmos-sdk network name
  -d, --daemon string           (Required) The folder location of the daemon data
  -u, --userdir                 (Required) The user's home director
  -s, --service                 (Optional) The service name that controls the chain's deamon
  -r, --rpc_port                (Optional) The RPC port of the snapshot node
  -h, --help                    (Optional) Help for the Crypto Chemistry Snapshot Uploader
"
}

make_opts() {
    # getopt boilerplate for argument parsing
    local _OPTS=$(getopt -o b:e:i:n:t:d:u:s:r:pc:h --long bucket:,endpoint:,id:,network:,net_type:,daemon:,userdir:,service:,rpc_port:,healthcheck,healthcheck_url:,help \
            -n 'Crypto Chemistry Snapshot Uploader' -- "$@")
    [[ $? != 0 ]] && { echo "Terminating..." >&2; exit 51; }
    eval set -- "${_OPTS}"
}

parse_args() {
    while true; do
    case "$1" in
        -b | --bucket ) S3_BUCKET="$2"; shift 2 ;;
        # Ensure endpoint URL does not have a single trailing '/'
        -e | --endpoint ) S3_ENDPOINT="${2%/}"; shift 2 ;;
        -i | --id ) S3_TENANT_ID="$2"; shift 2 ;;
        -n | --network ) NETWORK="$2"; shift 2 ;;
        -t | --net_type ) NET_TYPE="$2"; shift 2 ;;
        -d | --daemon ) DAEMON="$2"; shift 2 ;;
        -u | --userdir ) USER_DIR="$2"; shift 2 ;;
        -s | --service ) SERVICE="$2"; shift 2 ;;
        -r | --rpc_port) RPC_PORT="$2"; shift 2 ;;
        -p | --healthcheck ) HEALTHCHECK="True"; shift ;;
        -c | --healthcheck_url ) HEALTHCHECK_URL="$2"; shift 2 ;;
        -h | --help ) HELP_MENU="True"; shift ;;
        -- ) shift; break ;;
        * ) break ;;
    esac
    done

    [[ ! -z $HELP_MENU ]] && { help_menu; exit 0; }

    if [[ -z $S3_BUCKET || -z $S3_ENDPOINT || -z $S3_TENANT_ID || -z $NETWORK || -z $DAEMON || -z $USER_DIR ]]; then
        printf "\
        ${SCRIPT_NAME}: Error - Missing Arguments
        The following arguments are required:
            -b, --bucket
            -e, --endpoint
            -i, --id
            -n, --network
            -d, --daemon
    "
        exit 52
    fi
    if [[ -z $SERVICE ]]; then
        SERVICE="cosmovisor.service"
    fi
    if [[ -z $RPC_PORT ]]; then
        RPC_PORT="26657"
}

parse_prereqs() {
    for _svc in "jq" "aws" "pv"; do
      which "$_svc" >/dev/null || {
        help_menu
        printf "\n==> %s\n" "Missing package: $_svc"
        exit 53
      }
    done
    if [[ ! $(grep "${SERVICE}" <(systemctl list-unit-files)) ]]; then
        help_menu
        printf "\n==> %s\n" "Missing unit: ${SERVICE}"
        exit 54
    fi
}

get_block_height() {
    # Service must be running to get block height:
    systemctl start "${SERVICE}" >/dev/null && \
    BLOCK_HEIGHT=$(curl -s http://localhost:${RPC_PORT}/status | jq -r .result.sync_info.latest_block_height)
    if [[ -z $BLOCK_HEIGHT ]]; then
        printf "\n==> %s\n" "Unable to get block height"
        exit 55
    fi
    # Stop the service here to avoid potential corruption:
    systemctl stop "${SERVICE}"
}

compress_and_ship() {
    if [[ ! -z ${NET_TYPE} ]]; then
        local _filename=$(echo "${NETWORK}_${NET_TYPE}_${BLOCK_HEIGHT}.tar.lz4")
        local _s3_path="s3://${S3_BUCKET}/${NETWORK}_${NET_TYPE}/"
        local _url="${S3_ENDPOINT}/${S3_TENANT_ID}:${S3_BUCKET}/${NETWORK}_${NET_TYPE}%2F${_filename}"
    else
        local _filename=$(echo "${NETWORK}_${BLOCK_HEIGHT}.tar.lz4")
        local _s3_path="s3://${S3_BUCKET}/${NETWORK}/"
        local _url="${S3_ENDPOINT}/${S3_TENANT_ID}:${S3_BUCKET}/${NETWORK}%2F${_filename}"
    fi
    cd "${USER_DIR}/.${DAEMON}/"
    printf "\n==> %s\n" "Compressing ${USER_DIR}/.${DAEMON}/data to ${_filename}"
    tar cf - data | pv -s $(du -sb "${USER_DIR}/.${DAEMON}/data" | awk '{print $1}') | lz4 -9 > "${USER_DIR}/${_filename}"
    sleep 5
    systemctl start "${SERVICE}"

    # Transfer the file and then remove the file
    cd "${USER_DIR}"
    retry=0
    until [ "$retry" -ge 3 ]; do
        aws s3 --endpoint-url="${S3_ENDPOINT}" cp "${_filename}" "${_s3_path}" && break
        retry=$((retry+1)) 
        sleep 15
    done
    rm "${_filename}"

    printf "%s\n" "Object URL: ${_url}"

    # Uploads a file "latest" to the bucket and folder with the snapshot image
    # The "latest" file contains the URL to the snapshot
    # Allows for easier access to it in scripts eg:
    # To download the latest snapshot w/o knowing the URL:
    # wget $(wget -q -O - STATIC_URL_TO_LATEST)
    printf "%s\n" "${_url}" > /tmp/latest
    aws s3 --endpoint-url="$S3_ENDPOINT" cp "/tmp/latest" "${_s3_path}"
}

healthcheck() {
    if [[ ! -z ${HEALTHCHECK} && ! -z ${HEALTHCHECK_URL} ]]; then
        curl -m 5 --retry 3 ${HEALTHCHECK_URL}
    fi
}

# # # # #
# Main:
make_opts
parse_args "${@}"
parse_prereqs
get_block_height
compress_and_ship
healthcheck
exit "${?}"
