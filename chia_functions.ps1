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
    # https://github.com/Chia-Network/chia-blockchain/pull/13637
    $keys = (chia keys show --json | ConvertFrom-Json).keys

    foreach ($key in $keys) {
        $label = $key.label
        $address = $key.wallet_address
        New-Variable -Name "addr_$($label)" -Value $address -Force -Scope 1
        Write-Host "$address`t => `t`$addr_$($label)"
    }
}

function Set-KeyPSVariable {
    $keys = (chia keys show --json | ConvertFrom-Json).keys
    foreach ($key in $keys) {
        $label = $key.label
        if ($label) {
            $fingerprint = $key.fingerprint
            $address = $key.wallet_address
            New-Variable -Name "$($label)_fp" -Value $fingerprint -Force -Scope 1
            Write-Host "`$$($label)_fp:`t`t$fingerprint"
            New-Variable -Name "$($label)_addr" -Value $address -Force -Scope 1
            Write-Host "`$$($label)_addr:`t`t$address"
        }
    } 
}

function Set-ChiaPSVariables {
    . Set-KeyPSVariable
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
        [Int] $Num,
        [string] $AssetId
    )
    Write-Host "Get-DerivedPuzzleHashes: $fingerprint $num $AssetId"
    $sw = new-object system.diagnostics.stopwatch
    $sw.Start()

    $puzzleHashes = 
        chia keys derive -f $Fingerprint wallet-address -n $Num 
        | ForEach-Object { $_ -replace '(^Wallet address )(.*)(: )', "" }
        | ForEach-Object { Write-Host "." -NoNewline; cdv decode $_ }

    $result = $puzzleHashes

    if ($AssetId) {
        $catPuzzleHashes =
            $puzzleHashes 
            | ForEach-Object { Write-Host "." -NoNewline; cdv clsp cat_puzzle_hash -t $AssetId $_ }
        $result = $catPuzzleHashes
    }

    $sw.Stop()
    Write-Host ""
    Write-Host "Get-DerivedPuzzleHashes: $($sw.Elapsed.TotalMinutes) minutes"
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

function ConvertTo-HexString{
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [string] $Text
    ) 
    (
        $Text
        | Format-Hex -Encoding utf8 
        | select -Expand Bytes | % { '{0:x2}' -f $_ }
    ) -join ''
}

# chia keys derive -f $alice_fp wallet-address -n 20
# | % { $_ | Get-ObservedDerivedWalletAddress }
function Get-ObservedDerivedWalletAddress{
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [string] $Text
    )
    $pattern = "^Wallet address (?<idx>\d{1,}): (?<address>\w*)$"
    $regex_matches = Select-String -Pattern $pattern -InputObject $Text
    $idx = $regex_matches.Matches[0].Groups['idx'].Value
    $address = $regex_matches.Matches[0].Groups['address'].Value
    return [pscustomobject]@{ index = $idx; address = $address }
}

# chia keys derive -f $alice_fp child-key -t wallet -n 20
# | % { $_ | Get-ObservedDerivedPublicKey }
function Get-ObservedDerivedWalletPublicKey{
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [string] $Text
    )
    $pattern = "^Wallet public key (?<idx>\d{1,}): (?<pk>\w*)$"
    $regex_matches = Select-String -Pattern $pattern -InputObject $Text
    $idx = $regex_matches.Matches[0].Groups['idx'].Value
    $address = $regex_matches.Matches[0].Groups['pk'].Value
    return [pscustomobject]@{ index = $idx; public_key = $address }
}


function Get-Chia-Mempool-Size{
    return chia rpc full_node get_blockchain_state | jq ".blockchain_state.mempool_size"
}

function Get-Chia-Block-Height{
    return chia rpc full_node get_blockchain_state | jq ".blockchain_state.peak.height"
}

# https://docs.chia.net/full-node-rpc/#get_fee_estimate
function Get-Chia-Fee-Estimate{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [ValidateSet("XCH", "CAT", "TAKE_OFFER", "CANCEL_OFFER", "NFT_SET_NFT_DID", "NFT_TRANSFER_NFT", "CREATE_NEW_POOL_WALLET", "PW_ABSORB_REWARDS", "CREATE_NEW_DID_WALLET")]
        [string]$Type = "XCH",
        [Parameter(Mandatory=$false)]
        [int]$Time = 60, # target_times in seconds,
        [Parameter(Mandatory=$false)]
        [switch]$Mojos = $false
    )
    # https://github.com/Chia-Network/chia-blockchain/blob/92499b64a26784081e76f2e1f00582033fe64da7/chia/rpc/full_node_rpc_api.py#L846
    $tx_cost_estimates = @{
            "xch" = 9401710
            "cat" = 36382111
            "take_offer" = 721393265
            "cancel_offer" = 212443993
            "nft_set_nft_did" = 115540006
            "nft_transfer_nft" = 74385541  # burn or transfer
            "create_new_pool_wallet" = 18055407
            "pw_absorb_rewards" = 82668466
            "create_new_did_wallet" = 57360396
        }
    $payload = @{cost = $tx_cost_estimates[$Type.ToLower()]; target_times = @($Time) } | ConvertTo-Json
    $fee = chia rpc full_node get_fee_estimate $payload | jq ".estimates.[0]"
    if ($Mojos) {
        return $fee
    } else {
        # use .ToString("N12") to format to 12 decimal places
        return ($fee / 1000000000000).ToString("N12")
    }
}

function Get-Chia-Fee-Ranges{
    $mempool_items = (chia rpc full_node get_all_mempool_items | ConvertFrom-Json).mempool_items
    $fees = $mempool_items.psobject.properties | % { $_.Value.fee }
    
    $groups = @(
        @{ name="0 mojo"; count = 0},
        @{ name="1-1,000,000 (0.000001)"; count = 0},
        @{ name="1,000,001-5,000,000 (0.000005)"; count = 0},
        @{ name="5,000,001-50,000,000 (0.00005)"; count = 0},
        @{ name="50,000,001-500,000,000 (0.0005)"; count = 0},
        @{ name="< 1 XCH"; count = 0},
        @{ name=">= 1 XCH"; count = 0},
        @{ name="Total"; count = 0}
    )

    foreach ($fee in $fees) {
        if ($fee -eq 0) {
            $groups[0].count++
        } elseif ($fee -le 1*1e6) {
            $groups[1].count++
        } elseif ($fee -le 5*1e6) {
            $groups[2].count++
        } elseif ($fee -le 5*1e7) {
            $groups[3].count++
        } elseif ($fee -le 5*1e8) {
            $groups[4].count++
        } elseif ($fee -lt 1e12) {
            $groups[5].count++
        } else {
            $groups[6].count++
        }
        $groups[7].count++
    }
    return $groups | % { [pscustomobject]$_ }
}

function Get-Chia-Mempool-Info-By-Coin{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline)]
        [string]$Name
    )
    $payload = @{coin_name = $Name} | ConvertTo-Json
    $mempool_items = (chia rpc full_node get_mempool_items_by_coin_name $payload | ConvertFrom-Json).mempool_items
    $mempool_info = $mempool_items | % { [PSCustomObject]@{
        name = $_.spend_bundle_name
        fee = $_.fee
        cost = $_.cost
        fee_per_cost = $_.fee / $_.cost
        additions = $_.additions.Length
        removals = $_.removals.Length
    }}
    return $mempool_info
}