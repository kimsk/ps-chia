param (
    # fingerprint of your wallet
    [Parameter(mandatory)]
    $Fingerprint,
    [Parameter(mandatory)]
    $Num,
    [Parameter(mandatory)]
    $Amount,
    # fee 50_000_000 mojos is 0.00005 XCH
    $Fee = 50000000
)

. ../chia_functions.ps1

$sw = new-object system.diagnostics.stopwatch
$sw.Start()

Wait-SyncedWallet $Fingerprint

$WALLET_ID = 1
$AMOUNT = $Amount
$txnFee = $Fee * $Num # fee for send_transaction_multi transaction
$total = ($AMOUNT * $Num) + $txnFee

Wait-EnoughSpendable -WalletId $WALLET_ID -Amount $total

$puzzleHashes = Get-DerivedPuzzleHashes -fingerprint $FINGERPRINT -num $Num

$additions = foreach($puzzleHash in $puzzleHashes) {
    [PSCustomObject]@{
        amount = $AMOUNT
        puzzle_hash = $puzzleHash
    }
}

$coins = Get-Coins -WalletId $WALLET_ID -Amount $total
Write-Host "XCH Breaking: $($coins.Length) coin(s) -> $($Num) coins"
$json = [PSCustomObject]@{
        wallet_id = $WALLET_ID
        additions = @($additions)
        fee = $txnFee
        coins = @($coins)
    } 
    | ConvertTo-Json
    | Edit-ChiaRpcJson

$json = 
    (chia rpc wallet create_signed_transaction $json | ConvertFrom-Json).signed_tx 
    | ConvertTo-Json -Depth 4 
    | Edit-ChiaRpcJson

$result = chia rpc wallet send_transaction_multi $json
$transaction_id = ($result | ConvertFrom-Json).transaction_id
Wait-Transaction $transaction_id

$sw.Stop()
Write-Host "XCH Breaking: $($sw.Elapsed.TotalMinutes) minutes"