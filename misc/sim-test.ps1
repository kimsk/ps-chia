$cur_height = chia rpc full_node get_blockchain_state | jq ".blockchain_state.peak.height"
$expected_amount = 2000000000000

# arrange
cdv sim revert -fd --blocks ($cur_height - 1)
$addr = 'txch103xc9ghsjwpqww048cux65shjkjrddmn34wa487g2rmumvfwvq2qqx9ueh'

# act 
cdv sim farm --target-address $addr 
cdv sim farm
$measure = cdv rpc coinrecords --by puzzlehash (cdv decode $addr) 
            | jq ".[] | .coin.amount" 
            | Measure-Object -Sum

# assert
if ($expected_amount -eq $measure.Sum) {
    Write-Host "Pass!"
} else {
    throw "Fail!"
}
