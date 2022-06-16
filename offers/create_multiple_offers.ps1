param (
    [Parameter(mandatory)]
    $Fingerprint,
    [Parameter(mandatory)]
    $OfferWalletId,
    [Parameter(mandatory)]
    $OfferAmount,
    [Parameter(mandatory)]
    $RequestWalletId,
    [Parameter(mandatory)]
    $RequestAmount,
    [Parameter(mandatory)]
    $OfferFilePrefix, # 1TDBX_x_1XCH
    [Parameter(mandatory)]
    $OfferFilePath, # /mnt/e/offers/tdbx
    [Parameter(mandatory)]
    $Num,
    # fee 50_000_000 mojos is 0.00005 XCH
    $Fee = 50000000
)

. ../chia_functions.ps1

Write-Host "Create Offers: $Num of $($OfferWalletId):$($OfferAmount) for $($RequestWalletId):$($RequestAmount)"

$sw = new-object system.diagnostics.stopwatch
$sw.Start()

$offer = @{}
$offer.Add("$($OfferWalletId)", -1 * $OfferAmount)
$offer.Add("$($RequestWalletId)", $RequestAmount)
$offerRequestPayload = [PSCustomObject]@{
        offer = $offer
        fee = $Fee
    }
    | ConvertTo-Json
    | Edit-ChiaRpcJson

Wait-SyncedWallet $Fingerprint

for($i=0;$i -lt $Num;$i++)
{
    # Wait for Offer and Fee balance
    Wait-EnoughSpendable -WalletId $OfferWalletId -Amount $OfferAmount
    Wait-EnoughSpendable -WalletId 1 -Amount $Fee

    # create offer
    $offerFileName = "$OfferFilePrefix-$($i + 1).offer"
    $offerFullPath = "$OfferFilePath/$offerFileName"
    Write-Host "create: $offerFullPath"
    $offer = (chia rpc wallet create_offer_for_ids $offerRequestPayload | ConvertFrom-Json).offer
    $offer | Out-File -FilePath $offerFullPath
}

$sw.Stop()
Write-Host "Create Offers: $($sw.Elapsed.TotalMinutes) minutes"