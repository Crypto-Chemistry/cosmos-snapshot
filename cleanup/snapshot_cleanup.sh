#!/bin/bash -e

S3_ENDPOINT=""
S3_BUCKET=""

# Chains can be added as strings here, no comma is needed on line separations.
active_chains=(
                "kujira"
                "clan"
                "empowerchain"
                "stride"
            )

for chain in ${active_chains[@]}; do
    # Find number of backups, including the `latest` object
    echo "[${chain}]"
    object_count=$(aws s3 --endpoint-url=$S3_ENDPOINT ls "s3://${S3_BUCKET}/${chain}/" | grep -v latest | wc -l)
    echo "[${chain}]: Object Count $object_count"
    # Assumes a `latest` object is present. Without this file, 2 snapshots by default would be stored. 
    if [[ $object_count == 0 ]]; then
        echo "[${chain}]: snapshots are not active"
    elif [[ $object_count == 1 ]]; then
        echo "[${chain}]: no snapshots found"
    elif [[ $object_count == 2 ]]; then
        echo "[${chain}]: no cleanup needed"
    elif [[ $object_count > 2 ]]; then
        echo "[${chain}]: old snapshots found"
        echo "[${chain}]: List of objects:"
        aws s3 --endpoint-url=$S3_ENDPOINT ls "s3://${S3_BUCKET}/${chain}/" | awk '{print $4}' | sort -r | grep . | grep -v latest
        old_snapshots=$(aws s3 --endpoint-url=$S3_ENDPOINT ls "s3://${S3_BUCKET}/${chain}/" | awk '{print $4}' | sort -r | grep . | grep -v latest | tail -n +2)
        for file in $old_snapshots; do
                aws s3 --endpoint-url=$S3_ENDPOINT rm "s3://${S3_BUCKET}/${chain}/${file}"
        done
    fi
done