. ../chia_functions.ps1

$offer = @{}
$offer.Add("1", -1) # 1 mojo
$offer.Add("2", -1000) # 1 TDBX
$offer.Add("3", 1000)  # 1 TCHM
$offerRequestPayload = @{
    offer = $offer
    fee = 0
    validate_only = $true
} | ConvertTo-Json 
Invoke-Expression '$offerRequestPayload | jq -C'

$offerRequestPayload = $offerRequestPayload | Edit-ChiaRpcJson

$alice = 2101386534
Wait-SyncedWallet $alice

$offer_json = chia rpc wallet create_offer_for_ids $offerRequestPayload
Invoke-Expression '$offer_json | jq -C'
$offer = $offer_json | ConvertFrom-Json
# Set-Content -Value $offer -Path "./$($offer)"
Write-Host $offer.offer

$bob = 4090159833
Wait-SyncedWallet $bob

chia wallet take_offer -f $bob -e $offer.offer