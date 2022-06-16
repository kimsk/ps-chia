param (
    [Parameter(mandatory)]
    $Fingerprint
)

chia keys delete -f $Fingerprint

$walletDbPath = "$env:CHIA_ROOT/wallet/db"
$dbFile = "blockchain_wallet_v2_testnet10_$($Fingerprint).sqlite"
$dbFullPath = "$walletDbPath/$dbFile"
Write-Host "delete $dbFullPath"
if (Test-Path $dbFullPath) {
    Write-Host "$dbFullPath"
    Remove-Item $dbFullPath
}
