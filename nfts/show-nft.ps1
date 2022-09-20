param (
    [Parameter(mandatory)]
    $Fingerprint,   # fingerprint of your wallet
    [Parameter(mandatory)]
    $CoinId    # nft_coin_id
)

. ../chia_functions.ps1

#Wait-SyncedWallet -Fingerprint $Fingerprint
$json = [PSCustomObject]@{
    coin_id = $CoinId
} 
| ConvertTo-Json
| Edit-ChiaRpcJson

$nft = chia rpc wallet nft_get_info $json | ConvertFrom-Json
if (-not $nft.Success) {
    Throw "Error getting nft." 
} else {
    $nft = $nft.nft_info
}
$nft_id = cdv encode $nft.launcher_id --prefix nft
if ($nft.owner_did) {
    $owner_did = cdv encode $nft.owner_did --prefix did:chia:
} else {
    $owner_did = "N/A"
}

Write-Output "[1;32mnft_id    :[1;37m $nft_id[0m"
Write-Output "[1;32mowner_did :[1;37m $owner_did[0m"
$imgcat_result = Get-Command imgcat 2>&1

if ($NULL -ne $imgcat_result.Source) {
    $ProgressPreference = 'SilentlyContinue'
    $img_file = New-TemporaryFile
    $uri = $nft.data_uris[0]
    Invoke-WebRequest -Uri $uri -OutFile $img_file
    imgcat --width=30 $img_file
}