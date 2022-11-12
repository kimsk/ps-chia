# ❯ ./get-singleton-lineage.ps1 -Launcher_id 0x7dc07df2dd088ffdfcbe5a273825ac55565e536ed06604df55b3afa67e44b107
param(
    [parameter(mandatory)]
    $Launcher_Id
)

$GetSingletonByParentIdPayload = { 
    param($parent_id) 
    
    @{ parent_ids = @($parent_id); include_spent_coins = $True }
    |ConvertTo-Json -Depth 2
}

$GetCoinId = {
param($parent_coin_info, $puzzle_hash, $amount)
    $coin_id = run "(sha256 $parent_coin_info $puzzle_hash $amount)"
    return $coin_id
}

filter Get-OneOddCoinRecord
{
    $odd_coin_record = $null
    foreach ($cr in $_.coin_records) {
        if ($cr.coin.amount % 2 -eq 1) {
            if ($null -ne $odd_coin_record) {
                Write-Error "More Than One Coins With Odd Amount Found!"
            }
            $odd_coin_record = $cr 
        }
    }

    if ($null -eq $odd_coin_record) {
        Write-Error "Odd Coin Not Found!"
    }

    return $odd_coin_record
}

$GetSingletonCoinRecordByParent = {
    param($parent_id)

    $payload = &$GetSingletonByParentIdPayload $parent_id
    $response = 
        chia rpc full_node get_coin_records_by_parent_ids $payload 
        | ConvertFrom-Json
    $odd_coin_record = $response | Get-OneOddCoinRecord
    return $odd_coin_record
}

$coin_id = $Launcher_id
$unspent_not_found = $True
$coin_records = New-Object System.Collections.ArrayList

while ($unspent_not_found) {
    $odd_coin_record = &$GetSingletonCoinRecordByParent $coin_id 
    $coin_records.Add($odd_coin_record) | Out-Null
    $parent_coin_info = $odd_coin_record.coin.parent_coin_info
    $puzzle_hash = $odd_coin_record.coin.puzzle_hash
    $amount = $odd_coin_record.coin.amount

    $coin_id = &$GetCoinId $parent_coin_info $puzzle_hash $amount
    $unspent_not_found = $odd_coin_record.spent_block_index -ne 0
}

$coin_records