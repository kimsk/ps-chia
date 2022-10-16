# PowerShell object to Json for chia rpc

function Edit-DoubleToSingleQuote {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, mandatory)]
        [string] $Value
    )
    $Value -replace "`"", "'" 
}

function Edit-ChiaRpcJson {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, mandatory)]
        [string] $Json
    )
    $Json -replace '"', '\""'
}

function ConvertTo-ChiaRpcJson {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, mandatory)]
        [PSCustomObject] $object
    )
    $object | ConvertTo-Json | Edit-ChiaRpcJson
}

function Set-AddressPSVariables {
    $keys = chia keys show --json | ConvertFrom-Json

    foreach ($key in $keys) {
        $label = $key.label
        $address = $key.wallet_address
        New-Variable -Name "addr_$($label)" -Value $address -Force -Scope 1
        Write-Host "$address`t => `t`$addr_$($label)"
    }
}

function Set-FingerprintPSVariables {
    $pattern = "(?:^\|\s{1})(?<fingerprint>\d+)(?:\s+\|\s{1})(?<label>\w*)"
    $lines = chia keys label show | Select-Object -Skip 2

    foreach ($line in $lines) {
        $regex_matches = Select-String -Pattern $pattern -InputObject $line
        $fingerprint = $regex_matches.Matches[0].Groups['fingerprint'].Value
        $label = $regex_matches.Matches[0].Groups['label'].Value
        New-Variable -Name "fp_$($label)" -Value $fingerprint -Force -Scope 1
        Write-Host "$fingerprint`t => `t`$fp_$($label)"
    }
}

function Set-ChiaPSVariables {
    . Set-FingerprintPSVariables
    . Set-AddressPSVariables
}

function Reset-Simulator {
    $env:CHIA_ROOT = "~/.chia/simulator/main"
    $env:CHIA_KEYS_ROOT = "~/.chia_keys_sim_main"
    cdv sim stop -wd

    Remove-Item -Path "$($env:CHIA_ROOT)/db" -Recurse -Force
    Remove-Item -Path "$($env:CHIA_ROOT)/wallet" -Recurse -Force

    chia keys label show

    cdv sim start -w
    #cdv sim autofarm on
}

# Verify that wallet with the $FINGERPRINT is synced
function Wait-SyncedWallet {
    param(
        [Parameter(mandatory)]
        [Int64] $Fingerprint
    )
    Write-Host "Wait-SyncedWallet: $fingerprint " -NoNewline
    $sw = new-object system.diagnostics.stopwatch
    $sw.Start()

    chia wallet show -f $Fingerprint | Out-Null
    [console]::CursorVisible = $false
    $cursors = "\|/-"
    $cursor_idx = 0
    Write-Host "[" -NoNewline
    $cursor_pos = $host.UI.RawUI.CursorPosition
    Write-Host " ]" -NoNewline

    do {
        $sync_status = chia rpc wallet get_sync_status | ConvertFrom-Json
        $host.UI.RawUI.CursorPosition = $cursor_pos
        $cursor_idx++
        if ($cursor_idx -ge $cursors.Length) {
            $cursor_idx = 0
        }

        Write-Host $cursors[$cursor_idx] -NoNewline
        Start-Sleep -Milliseconds 200
    } until ($sync_status.synced) 

    $sw.Stop()
    $cursor_pos.X -= 1
    $host.UI.RawUI.CursorPosition = $cursor_pos
    Write-Host "   "
    Write-Host "Wait-SyncedWallet: $($sw.Elapsed.TotalMinutes) minutes"

    [console]::CursorVisible = $true
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
    
    $walletIdJson = 
        [PSCustomObject]@{ wallet_id = $WalletId } 
        | ConvertTo-Json
        | Edit-ChiaRpcJson

    Write-Host "Wait-EnoughSpendable: $WalletId $Amount " -NoNewline

    [console]::CursorVisible = $false
    $cursors = "\|/-"
    $cursor_idx = 0
    Write-Host "[" -NoNewline
    $cursor_pos = $host.UI.RawUI.CursorPosition
    Write-Host " ]" -NoNewline

    $sw = new-object system.diagnostics.stopwatch
    $sw.Start()


    do {
        $spendableAmount = (chia rpc wallet get_wallet_balance $walletIdJson | ConvertFrom-Json).wallet_balance.spendable_balance
        $host.UI.RawUI.CursorPosition = $cursor_pos
        $cursor_idx++
        if ($cursor_idx -ge $cursors.Length) {
            $cursor_idx = 0
        }

        Write-Host $cursors[$cursor_idx] -NoNewline
        Start-Sleep -Milliseconds 200
    } until ($spendableAmount -ge $Amount) 

    $sw.Stop()
    
    $cursor_pos.X -= 1
    $host.UI.RawUI.CursorPosition = $cursor_pos
    Write-Host "   "
    Write-Host "Wait-EnoughSpendable: Spendable: $spendableAmount"
    Write-Host "Wait-EnoughSpendable: $($sw.Elapsed.TotalMinutes) minutes"

    [console]::CursorVisible = $true
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

    Write-Host "Wait-Transaction: $TxnId " -NoNewline
    [console]::CursorVisible = $false
    $cursors = "\|/-"
    $cursor_idx = 0
    Write-Host "[" -NoNewline
    $cursor_pos = $host.UI.RawUI.CursorPosition
    Write-Host " ]" -NoNewline


    $sw = new-object system.diagnostics.stopwatch
    $sw.Start()
    $json = [PSCustomObject]@{
        transaction_id = $TxnId
    }   
    | ConvertTo-Json
    | Edit-ChiaRpcJson

    do {
        $result = chia rpc wallet get_transaction $json | ConvertFrom-Json
        $confirmed = $result.transaction.confirmed
        $host.UI.RawUI.CursorPosition = $cursor_pos
        $cursor_idx++
        if ($cursor_idx -ge $cursors.Length) {
            $cursor_idx = 0
        }

        Write-Host $cursors[$cursor_idx] -NoNewline
    } until ($confirmed)

    $sw.Stop()
    $cursor_pos.X -= 1
    $host.UI.RawUI.CursorPosition = $cursor_pos
    Write-Host "   "
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
    $PSStyle.Progress.View = 'Classic'
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
            if ($sync.sync_tip_height -le 0) {
                continue
            }

            if ($sync.sync_progress_height -eq $sync.sync_tip_height) {
                continue
            }

            $percentage = [Math]::floor(($sync.sync_progress_height/$sync.sync_tip_height) * 100)
            $height_status = "$($sync.sync_progress_height)/$($sync.sync_tip_height) ($($percentage)%)"        
            Write-Progress -Activity "Syncing in Progress" -Status $height_status -PercentComplete $percentage
            Start-Sleep -Milliseconds 50 
        }
    }
    until ($is_synced)

    Write-Host "Full Node Synced at $($synced_height)."
}
