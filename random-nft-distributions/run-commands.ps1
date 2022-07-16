foreach($command in Get-Content .\commands.txt) {
    # Write-Host $command
    Invoke-Expression $command
    Start-Sleep -s 5
}
