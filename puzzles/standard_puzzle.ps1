$p2_delegated_puzzle_or_hidden_puzzle = "ff02ffff01ff02ffff03ff0bffff01ff02ffff03ffff09ff05ffff1dff0bffff1effff0bff0bffff02ff06ffff04ff02ffff04ff17ff8080808080808080ffff01ff02ff17ff2f80ffff01ff088080ff0180ffff01ff04ffff04ff04ffff04ff05ffff04ffff02ff06ffff04ff02ffff04ff17ff80808080ff80808080ffff02ff17ff2f808080ff0180ffff04ffff01ff32ff02ffff03ffff07ff0580ffff01ff0bffff0102ffff02ff06ffff04ff02ffff04ff09ff80808080ffff02ff06ffff04ff02ffff04ff0dff8080808080ffff01ff0bffff0101ff058080ff0180ff018080"

$temp_file = New-TemporaryFile

Set-Content -Path $temp_file -Value $p2_delegated_puzzle_or_hidden_puzzle

$pk = "0x97c6c9f4e251dd874156c2b49344285258e45f9e10797612b90baecef8da69b3fda76f9889ff97a90fc82cc8dfde7f99"

$GetSyntheticPublicKey = {
    param($key)
    $expr = "cdv inspect keys --synthetic --public-key $key"
    $response = Invoke-Expression $expr
    return ($response | Select-Object -First 1) -replace "Public Key: ", ""
}

$synthetic_pk = &$GetSyntheticPublicKey $pk
write-host $synthetic_pk
$cdv_clsp_curry_expr = "cdv clsp curry $temp_file -a 0x$synthetic_pk"
Write-Host $cdv_clsp_curry_expr
Invoke-Expression $cdv_clsp_curry_expr