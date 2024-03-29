# Simple PowerShell Scripts Used with Chia Blockchain 

> `chia rpc` and `cdv rpc` requires a full node and wallet.

## Prerequisites
1. `chia`
2. `chia-dev-tools` (`cdv`)

## Coins

- [Break XCH coins](coins/xch_breaking.ps1)
```sh
ps-chia/coins
❯ ./xch_breaking.ps1 -Fingerprint 4108344430 -Num 200 -Amount 500000000                     
```

- [Break CAT coins](coins/cats_breaking.ps1)
```sh
ps-chia/coins
./cats_breaking.ps1 -Fingerprint 2111922937 -WalletId 3 -Num 5 -ToAddress txch15ghtr05dduculwrlxr969623wwfqfrmstqxp67307ge5ge3ed66smxya0f 
```

- [Get Singleton Lineage](coins/get-singleton-lineage.ps1)
```sh
❯ ./get-singleton-lineage.ps1 -Launcher_id 0x7dc07df2dd088ffdfcbe5a273825ac55565e536ed06604df55b3afa67e44b107
```

## Offers

- [Create Multiple Offers](offers/create_multiple_offers.ps1)

```sh
ps-chia/offers
❯ ./create_multiple_offers.ps1 -Fingerprint 3239424902 -OfferWalletId 3 -OfferAmount 1000 -RequestWalletId 1 -RequestAmount 1000000000000 -OfferFilePrefix "1TDBX_x_1XCH" -OfferFilePath "/mnt/e/offers/tdbx" -Num 5
```

- [Cancel All Offers](offers/cancel_offers.ps1)
```sh
ps-chia/offers
❯ ./cancel_offers.ps1 -Fingerprint 3239424902
```

## Keys/Wallets

- [Delete Key and Database](keys-wallets/delete_key.ps1)
```sh
ps-chia/keys-wallets
❯ ./delete_key.ps1 4108344430
```

- [Get Synthetic Secret Key From Synthetic Public Key](keys-wallets/get-syn-sk-from-syn-pk)

## References

- [Chia RPC API](https://docs.chia.net/docs/12rpcs/rpcs)
- [Chia RPC API Documentation | dkackman](https://dkackman.github.io/chia-api/static/)

- [The Ultimate Guide to Terminal User Interfaces in PowerShell](https://blog.ironmansoftware.com/tui-powershell/)