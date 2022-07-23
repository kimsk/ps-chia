# PowerShell object to Json for chia rpc
function Edit-ChiaRpcJson {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, mandatory)]
        [string] $Json
    )
    $Json -replace '"', '\""'
}

# Verify that wallet with the $FINGERPRINT is synced
function Wait-SyncedWallet {
    param(
        [Parameter(mandatory)]
        [Int64] $Fingerprint
    )
    Write-Host "Wait-SyncedWallet: $fingerprint "
    $sw = new-object system.diagnostics.stopwatch
    $sw.Start()

    chia wallet show -f $Fingerprint | Out-Null

    do {
        Start-Sleep -s 5
        $sync_status = chia rpc wallet get_sync_status | ConvertFrom-Json
        Write-Host "." -NoNewline
    } until ($sync_status.synced) 

    $sw.Stop()
    Write-Host ""
    Write-Host "Wait-SyncedWallet: $($sw.Elapsed.TotalMinutes) minutes"
}

function Show-WalletBalance {
    param(
        [Parameter(mandatory)]
        [Int64] $Fingerprint
    )
    Wait-SyncedWallet -Fingerprint $Fingerprint
    chia wallet show -f $Fingerprint
}



# Derive Keys and Decode to Puzzle Hashes
function Get-DerivedPuzzleHashes {
    param(
        [Parameter(mandatory)]
        [Int64] $Fingerprint,
		[Parameter(mandatory)]
        [Int] $Num
    )
    Write-Host "Get-DerivedPuzzleHashes: $fingerprint $num "
    $sw = new-object system.diagnostics.stopwatch
    $sw.Start()

    $puzzleHashes = 
        chia keys derive -f $Fingerprint wallet-address -n $Num 
        | ForEach-Object { $_ -replace '(^Wallet address )(.*)(: )', "" }
        | ForEach-Object { Write-Host "." -NoNewline; cdv decode $_ }

    $sw.Stop()
    Write-Host ""
    Write-Host "Get-DerivedPuzzleHashes: $($sw.Elapsed.TotalMinutes) minutes"
    $result = $puzzleHashes
    return $result
}

# Wait until spendable is greater or equal to the amount
function Wait-EnoughSpendable {
    param(
        [Parameter(mandatory)]
		[int] $WalletId,
        [Parameter(mandatory)]
        [int64] $Amount,
        [Int64] $Fingerprint
	)

    if ($Fingerprint) {
        Wait-SyncedWallet -Fingerprint $Fingerprint
    }

    Write-Host "Wait-EnoughSpendable: $WalletId $Amount "
    $sw = new-object system.diagnostics.stopwatch
    $sw.Start()

    $walletIdJson = 
        [PSCustomObject]@{ wallet_id = $WalletId } 
        | ConvertTo-Json
        | Edit-ChiaRpcJson


    do {
        Start-Sleep -s 5
        $spendableAmount = (chia rpc wallet get_wallet_balance $walletIdJson | ConvertFrom-Json).wallet_balance.spendable_balance
        Write-Host "." -NoNewline
    } until ($spendableAmount -ge $Amount) 

    Write-Host ""
    Write-Host "Wait-EnoughSpendable: Spendable: $spendableAmount"
    $sw.Stop()
    Write-Host "Wait-EnoughSpendable: $($sw.Elapsed.TotalMinutes) minutes"
}

# Get coins to spend
function Get-Coins {
    param(
		[Parameter(mandatory)]
        [int] $WalletId,
        [Parameter(mandatory)]
        [int64] $Amount,
        [Int64] $Fingerprint
	)

    if ($Fingerprint) {
        Wait-SyncedWallet -Fingerprint $Fingerprint
    }

    Write-Host "Get-Coins: $WalletId $Amount"
    $json = [PSCustomObject]@{ 
        wallet_id = $WalletId
        amount = $Amount
    }
    | ConvertTo-Json
    | Edit-ChiaRpcJson

    $result = chia rpc wallet select_coins $json 2>&1

    if ($result -like "Request failed:*"){
        # $match = select-string "Request failed: (.*)" -inputobject $result
        # $error_json = $match.Matches.groups[1].value -replace "'", """"
        throw $result
    } else {
        # success
        $coins = ($result | ConvertFrom-Json).coins
        return $coins
    }
}

# Wait for transaction to be done
function Wait-Transaction {
    param(
        [Parameter(Mandatory)]
        [string] $TxnId,
        [Int64] $Fingerprint
    )

    if ($Fingerprint) {
        Wait-SyncedWallet -Fingerprint $Fingerprint
    }

    Write-Host "Wait-Transaction: $TxnId "
    $sw = new-object system.diagnostics.stopwatch
    $sw.Start()
    $json = [PSCustomObject]@{
        transaction_id = $TxnId
    }   
    | ConvertTo-Json
    | Edit-ChiaRpcJson

    do {
        Start-Sleep -s 5
        $result = chia rpc wallet get_transaction $json | ConvertFrom-Json
        $confirmed = $result.transaction.confirmed
        Write-Host "." -NoNewline
    } until ($confirmed)

    $sw.Stop()
    Write-Host ""
    Write-Host "Wait-Transaction: $($sw.Elapsed.TotalMinutes) minutes"
}

# Get CAT Sender Info from Parent-CoinSpend's solution
function Get-CAT-Sender-Info {
    param(
        [Parameter(Mandatory)]
        $ParentCoinSpendSolution
    )

    $sender_puzzle_hash = brun '(f (r (f (r (r (r (r 1)))))))' $ParentCoinSpendSolution
    $amount = brun '(f (r (r (f (r (r (r (r 1))))))))' $ParentCoinSpendSolution

    return @{ puzzle_hash = $sender_puzzle_hash; amount = $amount}
}

# Wait for Full Node to be Synced with Progress Bar
function Wait-SyncedFullNode {
    $PSStyle.Progress.View = 'Minimal'
    Write-Host "Syncing Full Node..."

    $is_synced = $false
    $synced_height = 0
    do {
        $response = chia rpc full_node get_blockchain_state | ConvertFrom-Json

        $sync = $response.blockchain_state.sync

        if ($sync.synced) {
            $synced_height = $response.blockchain_state.peak.height
            $is_synced = $true
        } else {
            $height_status = "$($sync.sync_progress_height)/$($sync.sync_tip_height)"
            if ($sync.sync_tip_height -le 0) {
                continue
            }

            if ($sync.sync_progress_height -eq $sync.sync_tip_height) {
                continue
            }
        
            $percentage = ($sync.sync_progress_height/$sync.sync_tip_height) * 100
            Write-Progress -Activity "Syncing in Progress" -Status $height_status -PercentComplete $percentage
            Start-Sleep -s 5
        }
    }
    until ($is_synced)

    Write-Host "Full Node Synced at $($synced_height)."
}
