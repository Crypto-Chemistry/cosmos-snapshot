#!/bin/bash -e

# Needs:
# 1. A "parse_prereqs()" func that bails when lacking prereqs: e.g. aws cli, jq, cosmovisor.service

# # # # #
# Init vars:
NETWORK=
S3_TENANT_ID=
S3_ENDPOINT=
S3_BUCKET=
DAEMON=
USER_DIR=
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
  -u, --userdir                 (Required) The user's home directory
  -h, --help                    (Optional) Help for the Crypto Chemistry Snapshot Uploader
"
}

make_opts() {
    # getopt boilerplate for argument parsing
    OPTS=$(getopt -o b:e:i:n:d:u:h --long bucket:,endpoint:,id:,network:,daemon:,userdir:,help \
            -n 'Crypto Chemistry Snapshot Uploader' -- "$@")
    [[ $? != 0 ]] && { echo "Terminating..." >&2; exit 51; }
    eval set -- "${OPTS}"
}

parse_args() {
    while true; do
    case "$1" in
        -b | --bucket ) S3_BUCKET="$2"; shift 2 ;;
        -e | --endpoint ) S3_ENDPOINT="$2"; shift 2 ;;
        -i | --id ) S3_TENANT_ID="$2"; shift 2 ;;
        -n | --network ) NETWORK="$2"; shift 2 ;;
        -d | --daemon ) DAEMON="$2"; shift 2 ;;
        -u | --userdir ) USER_DIR="$2"; shift 2 ;;
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

    # Ensure endpoint URL does not have a single trailing '/'
    S3_ENDPOINT="${S3_ENDPOINT%/}"
}

get_block_height() {
    # Service must be running to get block height:
    systemctl start cosmovisor.service >/dev/null && \
    BLOCK_HEIGHT=$(curl -s http://localhost:26657/status | jq -r .result.sync_info.latest_block_height)
    # Stop the service here to avoid potential corruption:
    systemctl stop cosmovisor.service
}

compress_and_ship() {
    local _filename=$(echo "${NETWORK}_${BLOCK_HEIGHT}.tar.lz4")
    cd "${USER_DIR}/.${DAEMON}/"
    tar cvf - data | lz4 > "${USER_DIR}/${_filename}"
    systemctl start cosmovisor.service

    # Transfer the file and then remove the file
    cd "${USER_DIR}"
    aws s3 --endpoint-url="${S3_ENDPOINT}" cp "${_filename}" "s3://${S3_BUCKET}/${NETWORK}/"
    rm "${_filename}"
    local _url="${S3_ENDPOINT}/${S3_TENANT_ID}:${S3_BUCKET}/${NETWORK}%2F${_filename}"

    printf "%s\n" "Object URL: ${_url}"

    # Uploads a file "latest" to the bucket and folder with the snapshot image
    # The "latest" file contains the URL to the snapshot
    # Allows for easier access to it in scripts eg:
    # To download the latest snapshot w/o knowing the URL:
    # wget $(wget -q -O - STATIC_URL_TO_LATEST)
    printf "%s\n" "${_url}" > /tmp/latest
    aws s3 --endpoint-url="$S3_ENDPOINT" cp "/tmp/latest" "s3://${S3_BUCKET}/${NETWORK}/"
}

# # # # #
# Main:
make_opts
parse_args "${@}"
get_block_height
compress_and_ship
exit "${?}"
