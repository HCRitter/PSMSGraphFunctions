try {
    $MgContext = Get-MgContext
    if ( -not ($MgContext) -or -not ($MgContext.Scopes -contains "User.Read.All") -or -not ($MgContext.Scopes -contains "User.EnableDisableAccount.All") ) {
        Connect-MgGraph -Scopes "User.Read.All","User.EnableDisableAccount.All"
    }
} catch {
    # Show the error and stop the script if unable to connect to the Microsoft Graph with the required scopes.
    Write-Error "Failed to connect to Microsoft Graph with the required scopes 'User.Read.All' and 'User.EnableDisableAccount.All'."
    throw $_
}

function Set-UserAccountStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserName,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Active', 'Inactive')]
        [string]$Status
    )
    
    begin {
        
    }
    
    process {
        switch ($Status) {
            'Inactive' {
                $body = @{
                    accountEnabled = $false
                } | ConvertTo-Json
                try{
                    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/users/$($UserName)" -Body $body -ErrorAction Stop
                    Write-Verbose "User account $UserName has been disabled"
                }catch{
                    Write-Error "Failed to disable user account $UserName"
                    Write-Error $_.Exception.Message
                }
            }
            'Active' {
                $body = @{
                    accountEnabled = $true
                } | ConvertTo-Json
                try {
                    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/users/$($UserName)" -Body $body
                    Write-Verbose "User account $UserName has been enabled"
                }
                catch {
                    Write-Error "Failed to enable user account $UserName"
                    Write-Error $_.Exception.Message
                }
            }
        }
    }
    
    end {
        
    }
}

function Get-AllUserAccounts {
    [CmdletBinding()]
    param (

    )

    # Connect to the Microsoft Graph if not already connected.
    try {
        $MgContext = Get-MgContext
        if ( -not ($MgContext) -or -not ($MgContext.Scopes -contains "User.Read.All") -or -not ($MgContext.Scopes -contains "User.EnableDisableAccount.All") ) {
            Connect-MgGraph -Scopes "User.Read.All","User.EnableDisableAccount.All"
        }
    } catch {
        # Show the error and stop the script if unable to connect to the Microsoft Graph with the required scopes.
        Write-Error "Failed to connect to Microsoft Graph with the required scopes 'User.Read.All' and 'User.EnableDisableAccount.All'."
        throw $_
    }

    # Get all user accounts from Microsoft Graph
    $userAccounts = @()
    $uri = 'https://graph.microsoft.com/v1.0/users'
    
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $userAccounts += $response.value | Select-Object -ExpandProperty userPrincipalName
        $uri = $response.'@odata.nextLink'
    } while ($uri)
    return $userAccounts
}

Register-ArgumentCompleter -CommandName Set-UserAccountStatus -ParameterName UserName -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
    
    $userAccounts = Get-AllUserAccounts
    $userAccounts | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
