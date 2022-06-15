param (
    # fingerprint of your wallet
    [Parameter(mandatory)]
    $Fingerprint,
    $Secure = $false
)
. ../chia_functions.ps1

Write-Host "Cancel Offers: $Fingerprint $Secure" 
$sw = new-object system.diagnostics.stopwatch
$sw.Start()

Wait-SyncedWallet $Fingerprint

while($True){
    # only get 10 offers max for each call
    $offers = (chia rpc wallet get_all_offers | ConvertFrom-Json).trade_records
    if ($offers.Length -le 0) {
        break
    }

    foreach ($offer in $offers) {
        $payload = @{
            trade_id = $offer.trade_id
            secure = $Secure
        } 
        | ConvertTo-Json
        | Edit-ChiaRpcJson

        Write-Host $offer.trade_id
        chia rpc wallet cancel_offer $payload | Out-Null
    }
}

$sw.Stop()
Write-Host "Cancel Offers: $($sw.Elapsed.TotalMinutes) minutes"