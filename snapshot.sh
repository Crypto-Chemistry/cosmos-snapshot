#!/bin/bash -e

function help_menu() {
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

NETWORK=
S3_TENANT_ID=
S3_ENDPOINT=
S3_BUCKET=
DAEMON=
USER_DIR=

# getopt boilerplate for argument parsing
OPTS=$(getopt -o b:e:i:n:d:u:h --long bucket:,endpoint:,id:,network:,daemon:,userdir:,help \
            -n 'Crypto Chemistry Snapshot Uploader' -- "$@")

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

#Handle argument parsing/assignment
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

if [[ ! -z $HELP_MENU ]]; then
    help_menu
    exit 0
fi

if [[ -z $S3_BUCKET || -z $S3_ENDPOINT || -z $S3_TENANT_ID || -z $NETWORK || -z $DAEMON || -z $USER_DIR ]]; then
    printf "\
    Error - Missing Arguments
    The following arguments are required:
        -b,--bucket
        -e,--endpoint
        -i,--id
        -n,--network
        -d,--daemon
"
    exit 1
fi

# Trim endpoint URL if it end is trailing '/'
if [[ ${S3_ENDPOINT:0-1} == "/" ]]; then
    S3_ENDPOINT=${S3_ENDPOINT::-1}
fi

# Make sure the service is running
systemctl start cosmovisor.service
sleep 5

# Get block height
block_height=$(curl -s http://localhost:26657/status | jq -r .result.sync_info.latest_block_height)

# Stop service
systemctl stop cosmovisor.service

# Compress the folder
filename=$(echo "${NETWORK}_${block_height}.tar.lz4")
cd ${USER_DIR}/.${DAEMON}/
tar cvf - data | lz4 > "/home/relyte/$filename"

# Restart the service
systemctl start cosmovisor.service

# Transfer the file and then remove the file
cd ${USER_DIR}
aws s3 --endpoint-url="$S3_ENDPOINT" cp "$filename" "s3://${S3_BUCKET}/${NETWORK}/"
rm $filename
url="${S3_ENDPOINT}/${S3_TENANT_ID}:${S3_BUCKET}/${NETWORK}%2F${filename}"
echo "Object URL: $url"

exit 0