<#
.SYNOPSIS
    Retrieves Conditional Access Sign-In logs from Microsoft Graph API.

.DESCRIPTION
    The Get-ConditionalAccessSignIn function retrieves Conditional Access Sign-In logs from the Microsoft Graph API within a specified date range. 
    It allows filtering by sign-in type (Interactive or Non-Interactive) and conditional access status (Success or NotApplied).

.PARAMETER Unprotected
    Switch to indicate if only unprotected sign-ins should be retrieved. If specified, the conditional access status is set to "NotApplied".

.PARAMETER StartDate
    The start date for the sign-in logs retrieval. This parameter is mandatory.

.PARAMETER EndDate
    The end date for the sign-in logs retrieval. This parameter is mandatory and must be at least 1 day after the StartDate.

.PARAMETER SignInType
    Specifies the type of sign-in events to retrieve. Valid values are "Interactive" and "Non-Interactive". The default is "Interactive".

.EXAMPLE
    Get-ConditionalAccessSignIn -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) -SignInType "Interactive"

    Retrieves interactive sign-in logs for the past week.

.EXAMPLE
    Get-ConditionalAccessSignIn -Unprotected -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) -SignInType "Non-Interactive"

    Retrieves non-interactive unprotected sign-in logs for the past week.

.NOTES
    Author: Christian Ritter
    Date: 10/21/2024
#>


function Get-ConditionalAccessSignIn {
    [CmdletBinding()]
    param (
        [switch] $Unprotected,
        [Parameter(Mandatory=$true)]
        [datetime] $StartDate,
        [Parameter(Mandatory=$true)]
        [datetime] $EndDate,
        [ValidateSet("Interactive", "Non-Interactive")]
        [string[]] $SignInType = "Interactive"
    
    )
    
    begin {
        
        
        if($Unprotected){
            $ConditionalAccessStatus = "NotApplied"
        }else{
            $ConditionalAccessStatus = "Success"
        }
        #Enddate must be at least 1 day after startdate
        if($EndDate -lt $StartDate.AddDays(1)){
            throw "End date must be at least 1 day after startdate"
            return
        }

        $IgnorableUnprotectedStatusErrorCodes = @(
            9002341, 502031, 50209, 
            50203, 52004, 51006, 
            50158, 50144, 50143, 
            50140, 50129, 50127, 
            50125, 50097, 50076, 
            50074, 50072, 50059, 
            50058, 50055, 50019, 
            29200, 165100, 16003, 
            16001, 16000, 81014, 
            81012, 81010, 65001
        )
    }
    
    process {
        $returnObject = foreach($SignInTypeObject in @($SignInType)){
            #region build the filter dynamically
            $Filter = "(createdDateTime ge $($StartDate.ToString("yyyy-MM-dd"))T22:00:00.000Z and createdDateTime lt $($EndDate.ToString("yyyy-MM-dd"))T22:00:00.000Z)"

            $Filter += " and (status/errorCode eq 0 or ($($IgnorableUnprotectedStatusErrorCodes.ForEach({
                "status/errorCode ne $_"
            })-join " and ")))"
            

            
            if($SignInTypeObject -eq 'Non-Interactive'){
                $Filter += " and (signInEventTypes/any(t: t ne 'interactiveUser'))"
            }else {
                $Filter += " and (signInEventTypes/any(t: t eq 'interactiveUser')"
            }
            

            $Filter += " and (conditionalAccessStatus eq '$ConditionalAccessStatus')"
            #endregion build the filter dynamically
            
            # perform the request
            Invoke-MgGraphRequest -Method Get -Uri ("https://graph.microsoft.com/beta/auditLogs/signIns?`$Filter=$Filter") -OutputType PSObject

            Write-Verbose "Path: https://graph.microsoft.com/beta/auditLogs/signIns"
            Write-Verbose "Filter: $Filter"
        }


    }
    
    end {
        return $returnObject.Value
    }
}
