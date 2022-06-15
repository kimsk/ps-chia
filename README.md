# Simple PowerShell Scripts Used with Chia Blockchain 

> `chia rpc` and `cdv rpc` requires a full node and wallet.

## Prerequisites
1. `chia`
2. `chia-dev-tools` (`cdv`)

## Coins

- [Break XCH coins](coins/xch_breaking.ps1)
```sh
❯ ./xch_breaking.ps1 -Fingerprint 4108344430 -Num 200 -Amount 500000000                     
Wait-SyncedWallet: 4108344430 
.
Wait-SyncedWallet: 0.11276579 minutes
Wait-EnoughSpendable: 1 110000000000 
.
Wait-EnoughSpendable: Spendable: 
Wait-EnoughSpendable: 0.09319251 minutes
Get-DerivedPuzzleHashes: 4108344430 200 
........................................................................................................................................................................................................
Get-DerivedPuzzleHashes: 1.68732569833333 minutes
Get-Coins: 1 110000000000
XCH Breaking: 1 coin(s) -> 200 coins
Wait-Transaction: 0xcf1bf6bdaa9659e6a06ae5aefca4c71cd12b338fb1d0de4e282a282d8df8bb87 
...........
Wait-Transaction: 1.04156176 minutes
XCH Breaking: 3.008692485 minutes
```

## References

- [Chia RPC API](https://docs.chia.net/docs/12rpcs/rpcs)
- [Chia RPC API Documentation | dkackman](https://dkackman.github.io/chia-api/static/)
