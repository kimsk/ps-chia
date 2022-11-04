$pattern = "(?:^\|\s{1})(?<fingerprint>\d+)(?:\s+\|\s{1})(?<label>\w*)"
$lines = chia keys label show | Select-Object -Skip 2

foreach ($line in $lines) {
    $regex_matches = Select-String -Pattern $pattern -InputObject $line
    $fingerprint = $regex_matches.Matches[0].Groups['fingerprint'].Value
    $label = $regex_matches.Matches[0].Groups['label'].Value
    if ($label -ne "No") {
        New-Variable -Name "$($label)" -Value $fingerprint -Force -Scope Global 
        Write-Host "$fingerprint`t => `t`$$($label)"
    }
}