param (
    # fingerprint of your wallet
    [Parameter(mandatory)]
    $Fingerprint,
    [Parameter(mandatory)]
    $WalletId,
    [Parameter(mandatory)]
    $Num,
    [Parameter(mandatory)]
    $ToAddress, # Have to be different from the fingerprint wallet
    $Amount = 1000, # Each CAT is 1000 mojos
    # fee 50_000_000 mojos is 0.00005 XCH
    $Fee = 50000000
)

. ../chia_functions.ps1

Write-Host "CATs breaking: $Num coin(s)"
$sw = new-object system.diagnostics.stopwatch
$sw.Start()

Wait-SyncedWallet -Fingerprint $Fingerprint

# break coin one-by-one
for($i=0;$i -lt $Num;$i++)
{
    # Wait for CAT and Fee balance
    Wait-EnoughSpendable -WalletId $WalletId -Amount $Amount
    Wait-EnoughSpendable -WalletId 1 -Amount $Fee

    $cat_spend_json = [PSCustomObject]@{ 
        fingerprint = $Fingerprint
        wallet_id = $WalletId
        amount = $Amount
        fee = $Fee
        inner_address = $ToAddress
    } 
    | ConvertTo-Json
    | Edit-ChiaRpcJson

    $result = chia rpc wallet cat_spend $cat_spend_json | ConvertFrom-Json
    Write-Host "($($i)) txn_id: $($result.transaction_id)"
}

$sw.Stop()
Write-Host "CATs breaking: $($sw.Elapsed.TotalMinutes) minutes"
