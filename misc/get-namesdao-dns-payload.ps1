# https://twitter.com/BenAtreidesVing/status/1590418829750194177
# '{"wallet_id": FILL_ME_IN, "metadata": {"namesdao":"{\"FILL_ME_IN.xch\":{\"dns\":{\"default\":[{\"type\":\"CNAME\",\"host\":\"@\",\"value\":\"www.FILL_ME_IN\",\"ttl\":3600,\"priority\":1}]}}}"}, "fee": 5}'

param(
    [parameter(mandatory)]
    $WALLET_ID,
    [parameter(mandatory)]
    [string] $NAME,
    [parameter(mandatory)]
    [string] $URL,
    [parameter()]
    [Int32]$FEE = 5
)

$namesdao_metadata = @{
    "$NAME.xch" = @{
        "dns" = @{
            "default" = @(
                @{
                    "type" = "CNAME"
                    "host" = "@"
                    "value" = "$URL"
                    "ttl" = 3600
                    "priority" = 1
                }
            )
        }
    }
}

$payload = @{
    wallet_id = $WALLET_ID
    metadata = @{
        namesdao = $namesdao_metadata | ConvertTo-Json -Compress -Depth 4
    }
    fee = $FEE
}

$payload | ConvertTo-Json