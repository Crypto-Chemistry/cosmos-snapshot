#!/bin/bash -x

API_KEY=
HEALTHCHECK_URL=

# Create payload. Daily timeout, 2 hour grace period
PAYLOAD='{"name": "'$(hostname)'-state-sync", "timeout": 86400, "grace": 7200, "unique": ["name"]}'

# Creates the payload if non-existent
# Returns the URL to ping
URL=$(curl -s $HEALTHCHECK_URL -H "X-Api-Key: $API_KEY" -d "$PAYLOAD" | jq -r .ping_url)

# Send a ping
curl -m 10 --retry 5 $URL

if [[ ! -z ${HEALTHCHECK_URL} ]]; then
    echo "export HEALTHCHECK_URL=$URL" >> $HOME/.bashrc
    source $HOME/.bashrc
fi

exit 0