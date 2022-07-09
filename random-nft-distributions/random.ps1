$addresses = 1..10
Write-Output ($addresses | ConvertTo-Json)
$random_addresses = $addresses | Get-Random -Count $addresses.Count
Write-Output ($random_addresses | ConvertTo-Json)

$nfts = 1..10

for($i=0;$i -lt $nfts.Length;$i++){
    Write-Output "Send $($nfts[$i]) to $($random_addresses[$i])."
}
