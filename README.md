# Crypto Chemistry - Cosmos Snapshot

## About

This repo provides a simple script and systemd service setup to enable uploading a cosmos-sdk based chain's blockchain data snapshot to an S3 compatible storage provider. The `snapshot.service.j2` file is provided for easy integration with Ansible playbooks, but the instructions will cover how to modify this file for use without Ansible.

## Usage

### Prerequisites 
 - `awscli` is installed
 - `jq` is installed
 - `pv` is installed
 - Cosmovisor is being used, or the systemd service that controls the chain daemon is called `cosmovisor.service`
 - A remote S3 compatible storage account is set up

**NOTE: This has only been tested using Contabo's S3 storage service at this time. Compatibility with other S3 storage providers is not guaranteed**

### Installation

First, clone the repo and enter it:

```
git clone https://github.com/Crypto-Chemistry/cosmos-snapshot.git
cd cosmos-snapshot
```

Move the `snapshot.service.j2` file to `snapshot.service`:

```
mv snapshot.service.j2 snapshot.service
```

Edit the `snapshot.service` file and replace the variables for the intended usage:

```
nano snapshot.service
```

An example completed `snapshot.service` file is provided below:

```
[Unit]
Description=Snapshot Upload Service

[Service]
Type=simple
ExecStart=/home/relyte/cosmos-snapshot/snapshot.sh \
            -b snapshots \
            -e "https://eu2.contabostorage.com/" \
            -i "abcdefghijklmnopqrstuv1234567890" \
            -n kujira \
            -d kujira \
            -u "/home/relyte"

[Install]
WantedBy=default.target
```

A breakdown of each variable is provided in the [Available Parameters](#available-parameters) section

The ExecStart line in the example specifies the following:
- `-b snapshots` - The bucket name is "snapshots"

- `-e "https://eu2.contabostorage.com/"` - The S3 storage URL endpoint to upload to is "https://eu2.contabostorage.com/"

- `-i "abcdefghijklmnopqrstuv1234567890"` - The ID of the account that is being used for storage is "abcdefghijklmnopqrstuv1234567890"

- `-n kujira` - The folder name to upload to is "kujira"

- `-d kujira` - The daemon folder is ".kujira". The "." is not needed. This is usually in the user's home directory (/home/user/.kujira)

- `-u /home/relyte` - The user's home directory that runs the cosmovisor service is "/home/relyte"

After this, edit the desired runtime in the `snapshot.timer` by modifying the `OnCalendar=` line. The default is to run once every 24 hours at midnight system time.

Make sure the script is executable:

```
chmod +x snapshot.sh
```

Symlink the systemd files to the systemd directory:
```
ln -s snapshot.service /etc/systemd/system/snapshot.service
ln -s snapshot.timer /etc/systemd/system/snapshot.timer
```

Enable the timer and service
```
sudo systemctl enable snapshot.service
sudo systemctl enable snapshot.timer
```

### Testing the Installation

To test the setup, simply run:

```
sudo systemctl start snapshot.service
```

The results can be viewed by monitoring the service:

```
sudo journalctl -f -u snapshot.service
```

### Available Parameters

| Parameter            | Type   | Required | Description                                     |
|----------------------|--------|----------|-------------------------------------------------|
| -b,--bucket          | String | Yes      | S3 Bucket name                                  |
| -e,--endpoint        | String | Yes      | S3 endpoint URL                                 |
| -i,--id              | String | Yes      | The S3 tenant ID                                |
| -n,--network         | String | Yes      | The cosmos-sdk network name                     |
| -d,--daemon          | String | Yes      | The folder location of the daemon data          |
| -u,--userdir         | String | Yes      | The user's home directory                       |
| -p,--healthcheck     | None   | No       | Enable health checks (uses ${HEALTHCHECKS_URL} if -c is not specified)|
| -c,--healthcheck_url | String | No       | The healthchecks.io URL to send health checks   |
| -h,--help            | None   | No       | Help for the Crypto Chemistry Snapshot Uploader |

## Cleanup Usage
The cleanup script is currently only tested against Contabo's S3 Object Storage.

The `snapshot_cleanup.sh` script needs to be edited to provide the S3 endpoint and bucket name. Additionally, all chains need to be specified as strings in the script within the `active_chains` array.

This cleanup script assumes that the `latest` object is in each chain's snapshot folder. If this doesn't exist, the script will always leave 2 snapshots present at a time.