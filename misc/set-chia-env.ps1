[CmdletBinding(DefaultParameterSetName = 'sim')]
param(
    # environment
    [parameter(
        mandatory,
        ParameterSetName="mainnet"
    )]
    [switch] $mainnet,
    [parameter(
        mandatory,
        ParameterSetName="testnet"
    )]
    [switch] $testnet,
    [parameter(
        ParameterSetName="sim"
    )]
    [String] $sim = "main"
)

if($mainnet) {
    $env:CHIA_ROOT = "~/.chia/mainnet"
    $env:CHIA_KEYS_ROOT = "~/.chia_keys"
    chia configure -t false
} 
elseif($testnet) {
    $env:CHIA_ROOT = "~/.chia/testnet10"
    $env:CHIA_KEYS_ROOT = "~/.chia_keys_testnet10"
    chia configure -t true
} 
elseif($sim) {
    $env:CHIA_ROOT = "~/.chia/simulator/$($sim)"
    $env:CHIA_KEYS_ROOT = "~/.chia_keys_sim_$sim"
    New-Variable -Name "sim" -Value $sim -Force -Scope 1
}

Write-Output $env:CHIA_ROOT
Write-Output $env:CHIA_KEYS_ROOT
. Set-ChiaPSVariables