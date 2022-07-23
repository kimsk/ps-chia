. ../chia_functions.ps1

$receiver = 230530675
$receiver_address = (chia keys derive -f $receiver wallet-address -n 1) -replace 'Wallet address 0: ', ''
$receiver_puzzle_hash = cdv decode $receiver_address

# TCHM
$asset_id = 'af4a9c1a4bdc6fd9b38c406be37ef4ba642036679c220767929c0e0ee6466144'
$receiver_tchm_puzzle_hash = cdv clsp cat_puzzle_hash --tail $asset_id $receiver_puzzle_hash 

Wait-SyncedFullNode
$coin_records = cdv rpc coinrecords --by puzzlehash $receiver_tchm_puzzle_hash | ConvertFrom-Json

foreach ($cr in $coin_records){
    $parent_coin_info = $cr.coin.parent_coin_info
    $parent_coin_record = cdv rpc coinrecords --by id $parent_coin_info | ConvertFrom-Json
    $spent_block_index = $parent_coin_record.spent_block_index
    $payload = @{ coin_id = $parent_coin_info; height = $spent_block_index } | ConvertTo-Json | Edit-ChiaRpcJson
    $coin_spend = chia rpc full_node get_puzzle_and_solution $payload | ConvertFrom-Json
    $solution = opd $coin_spend.coin_solution.solution.Substring(2)

    $cat_sender_info = Get-CAT-Sender-Info -ParentCoinSpendSolution $solution

    $sender_address = cdv encode $cat_sender_info.puzzle_hash.Substring(2) --prefix txch
    $tokens = [math]::floor($cat_sender_info.amount/1000)
    Write-Host "$($sender_address) sent $($tokens) token(s)"
}



