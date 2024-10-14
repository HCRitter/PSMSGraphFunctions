<#
.SYNOPSIS
Retrieves Microsoft Graph audit log sign-in events filtered by type.

.DESCRIPTION
The Get-MSGraphAuditLogSignInByType function queries Microsoft Graph to retrieve audit log sign-in events and filters them based on the specified type. This can be useful for monitoring and analyzing sign-in activities within an organization.

.PARAMETER Type
Specifies the type of sign-in events to retrieve. This parameter is required.

.EXAMPLE
Get-MSGraphAuditLogSignInByType -Type "Interactive" -AppID "00000000-0000-0000-0000-000000000000"
This example retrieves all interactive sign-in events from the Microsoft Graph audit logs.

.EXAMPLE
Get-MSGraphAuditLogSignInByType -Type "NonInteractive" -AppID "00000000-0000-0000-0000-000000000000"
This example retrieves all non-interactive sign-in events from the Microsoft Graph audit logs.

.NOTES
Author: Christian Ritter
#>
function Get-MSGraphAuditLogSignInByType {
    [CmdletBinding()]
    param (
        
        $AppID,
        [ValidateSet('servicePrincipal', 'interactiveUser', 'nonInteractiveUser')]
        [string[]]$SignInType,
        [int]$Top = 100,
        [switch]$All    
    )
    
    begin {
        $ReturnCollection = new-object System.Collections.Generic.List[pscustomobject] # Creates a collection to store the app objects
        $OriginalTop = $Top # Stores the original value of $Top
    }
    
    process {
        
        if($All){
            $Top = 999 # Sets $Top to a high value if $All switch is used
        }
        if($Top -gt 999){
            $Top = 999 # Sets $Top to 999 if it exceeds the maximum value
        }

        $URIs = switch($SignInType){
            'servicePrincipal'{
                $Filter = "signInEventTypes/any(t:t eq 'servicePrincipal') and AppId eq '$($AppID)'"
                'https://graph.microsoft.com/beta/auditLogs/signIns?$Top={0}&$Filter={1}' -f $Top,$Filter # Constructs the URI for the API request
                
            }
            'interactiveUser'{
                $Filter = "AppId eq '$($AppID)'"
                'https://graph.microsoft.com/beta/auditLogs/signIns?$Top={0}&$Filter={1}' -f $Top,$Filter # Constructs the URI for the API request

            }
            'nonInteractiveUser'{
                $Filter = "signInEventTypes/any(t: t ne 'interactiveUser') and AppId eq '$($AppID)'"
                'https://graph.microsoft.com/beta/auditLogs/signIns?$Top={0}&$Filter={1}' -f $Top,$Filter # Constructs the URI for the API request

            }
        }
        @($URIs).ForEach({
            $Return = (Invoke-MgGraphRequest -Method GET -Uri $_ -OutputType PSObject) # Sends the API request and stores the response
            $($Return.value.ForEach({ 
                $ReturnCollection.Add($_) # Adds each app object to the collection
            }))
            while(-not([string]::IsnullorEmpty($Return.'@odata.nextlink')) -and (($ReturnCollection.Count -lt $OriginalTop) -or $All)){
                $Return = (Invoke-MgGraphRequest -Method GET -Uri $Return.'@odata.nextlink' -OutputType PSObject) # Sends additional requests to retrieve remaining apps if $All switch is used
                $($Return.value.ForEach({
                    $ReturnCollection.Add($_) # Adds each app object to the collection
                    if($ReturnCollection.Count -eq $OriginalTop -and -not $All){
                        break 
                    }
                }))
            }
        })
    }
    
    end {
        if($All){
            return $ReturnCollection # Returns all app objects
        }
        if($ReturnCollection.count -lt $OriginalTop){
            return $OriginalTop = $ReturnCollection.count   
        }
        return $ReturnCollection[0..$($OriginalTop-1)] # Returns the specified number of app objects
    }
}
