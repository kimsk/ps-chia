param (
    [Parameter(mandatory)]
    $Fingerprint,   # fingerprint of your wallet
    [Parameter(mandatory)]
    $WalletId    # NFT Wallet Id
)

. ../chia_functions.ps1

$imgcat_result = Get-Command imgcat 2>&1
if ($NULL -eq $imgcat_result.Source) {
    Throw "Please install imgcat."
}

Wait-SyncedWallet -Fingerprint $Fingerprint
$json = [PSCustomObject]@{
    wallet_id = $WalletId
} 
| ConvertTo-Json
| Edit-ChiaRpcJson

$nfts = chia rpc wallet nft_get_nfts $json | ConvertFrom-Json
if (-not $nfts.Success) {
    Throw "Error getting nfts." 
}

$ProgressPreference = 'SilentlyContinue'
foreach ($nft in $nfts.nft_list) {
    $launcher_id = $nft.launcher_id
    $nft_id = cdv encode $launcher_id --prefix nft
    Write-Host $nft_id
    $img_file = New-TemporaryFile
    $uri = $nft.data_uris[0]
    Invoke-WebRequest -Uri $uri -OutFile $img_file
    imgcat --width=30 $img_file
}
