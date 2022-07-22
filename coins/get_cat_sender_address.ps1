. ../chia_functions.ps1

$senders = @(3410185846, 2257320143, 1612911332)
$receiver = 230530675
$receiver_address = (chia keys derive -f $receiver wallet-address -n 1) -replace 'Wallet address 0: ', ''
$receiver_puzzle_hash = cdv decode $receiver_address
# TCHM
$asset_id = 'af4a9c1a4bdc6fd9b38c406be37ef4ba642036679c220767929c0e0ee6466144'
$receiver_tchm_puzzle_hash = cdv clsp cat_puzzle_hash --tail $asset_id $receiver_puzzle_hash 
$wallet_id = 2


# foreach($sender in $senders) {
#     Wait-SyncedWallet -Fingerprint $sender
#     $payload = @{ wallet_id = $wallet_id } | ConvertTo-Json | Edit-ChiaRpcJson
#     $response = chia rpc wallet get_wallet_balance $payload | ConvertFrom-Json
#     $balance = $response.wallet_balance.confirmed_wallet_balance
#     Write-Host $balance
# }

Wait-SyncedWallet -Fingerprint $receiver
Write-Host $receiver_address
Write-Host $receiver_puzzle_hash
Write-Host $receiver_tchm_puzzle_hash

$coin_records = cdv rpc coinrecords --by puzzlehash $receiver_tchm_puzzle_hash | ConvertFrom-Json
$coin_records[0].coin.parent_coin_info
foreach ($cr in $coin_records){
    $parent_coin_info = $cr.coin.parent_coin_info
    $parent_coin_record = cdv rpc coinrecords --by id $parent_coin_info | ConvertFrom-Json
    $spent_block_index = $parent_coin_record.spent_block_index
    $payload = @{ coin_id = $parent_coin_info; height = $spent_block_index } | ConvertTo-Json | Edit-ChiaRpcJson
    $coin_spend = chia rpc full_node get_puzzle_and_solution $payload | ConvertFrom-Json
    $solution = opd $coin_spend.coin_solution.solution.Substring(2)
    $sender_puzzle_hash = brun '(f (r (f (r (r (r (r 1)))))))' $solution
    $sender_address = cdv encode $sender_puzzle_hash.Substring(2) --prefix txch
    $amount = brun '(f (r (r (f (r (r (r (r 1))))))))' $solution
    Write-Host "$($sender_address) sent $($amount)"
}



