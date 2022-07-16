$fingerprint = 34445566
$wallet_id = 2
$addresses = @(
    'txch11...'
    'txch12...'
    'txch13...'
    'txch14...'

)
#Write-Output ($addresses | ConvertTo-Json)
$random_addresses = $addresses | Get-Random -Count $addresses.Count
#Write-Output ($random_addresses | ConvertTo-Json)


$nft_coin_ids = @(
    '1...'
    '2...'
    '3...'
    '4...'

)

if ($addresses.Length -ne $nft_coin_ids.Length) {
    throw "Addresses and NFTs must have same length."
}

for($i=0;$i -lt $nft_coin_ids.Length;$i++){
    $nft_coin_id = $nft_coin_ids[$i]
    $address = $random_addresses[$i]
    $command = "chia wallet nft transfer -f $($fingerprint) -i $($wallet_id) -ni $($nft_coin_id) -ta $($address)"
    Write-Output $command
    #Invoke-Expression $command
    Start-Sleep -s 5
}