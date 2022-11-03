# Crypto Chemistry - Cosmos Snapshot State-Sync Scripts

### About

This portion of the repo configures periodic state-syncs on a snapshot node to reduce the total snapshot size. As a result, much less storage space is required long-term for running a snapshot node for any given

### Available Parameters

  -r, --rpc string              (Required) The RPC server to state-sync with
  -n, --network string          (Required) The cosmos-sdk network name
  -d, --daemon string           (Required) The folder location of the daemon data
  -u, --userdir                 (Required) The user's home director
  --user                        (Required) The user that should own the tendermint data directory
  -p, --healthcheck             (Optional) Enables sending Healthcheck pings
  -c, --healthcheck_url         (Optional) Sets the Healtcheck URL to ping
  -s, --service                 (Optional) The service name that controls the chain's deamon
  -h, --help                    (Optional) Help for the Crypto Chemistry Snapshot Uploader

| Parameter            | Type   | Required | Description                                     |
|----------------------|--------|----------|-------------------------------------------------|
| -r, --rpc            | String | Yes      | The RPC server to state-sync with               |
| -n,--network         | String | Yes      | The cosmos-sdk network name                     |
| -d,--daemon          | String | Yes      | The chain's daemon name (kujirad, strided, etc) |
| -u,--userdir         | String | Yes      | The user's home directory                       |
| --user               | String | Yes      | The user that should own the Tendermint data directory|
| -p,--healthcheck     | None   | No       | Enables sending Healthcheck pings               |
| -c,--healthcheck_url | String | No       | Sets the Healtcheck URL to ping                 |
| -s,--service         | String | No       | The service name that controls the chain's deamon (defaults to cosmovisor.service)|
| -h,--help            | None   | No       | Help for the Crypto Chemistry Snapshot Uploader |

## State-Sync Usage
All state-sync related scripts and services can be found in the `state-sync/` directory.

The `snapshot_state_sync.service.j2` script needs to be edited to provide user, path to the `snapshot_state_sync.sh` script, and optionally the healthcheck url.