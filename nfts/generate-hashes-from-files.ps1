$assets_folder = "/mnt/e/NFTs"
$json = "/mnt/e/NFTs/hashes.json"

if (Test-Path $assets_folder) {
    $assets = Get-ChildItem /mnt/e/NFTs
    $lines = [System.Collections.ArrayList]::new()
    foreach ($asset in $assets) {
        $hash = (Invoke-Expression "sha256sum '$($asset.FullName)'").Split(' ')[0]
        $lines.Add(@{
            name = $asset.Name
            hash = $hash
        }) | Out-Null
    }
    $lines | ConvertTo-Json | Set-Content $json
}