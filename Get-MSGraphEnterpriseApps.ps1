<#
.SYNOPSIS
Retrieves enterprise apps using the Microsoft Graph API.

.DESCRIPTION
The Get-MSGraphEnterpriseApps function retrieves enterprise apps by sending requests to the Microsoft Graph API. It allows you to specify various parameters such as using the beta version of the API, selecting specific properties from the response, retrieving all enterprise apps, and setting the maximum number of apps to retrieve.

.PARAMETER Beta
Specifies whether to use the beta version of the Graph API.

.PARAMETER Selects
Specifies the properties to select from the response.

.PARAMETER All
Specifies whether to retrieve all enterprise apps.

.PARAMETER Top
Specifies the maximum number of apps to retrieve. The default value is 100.

.EXAMPLE
Get-MSGraphEnterpriseApps -Beta -Selects "displayName", "appId" -Top 50
Retrieves the top 50 enterprise apps using the beta version of the Graph API and selects the "displayName" and "appId" properties from the response.

.OUTPUTS
System.Collections.Generic.List[pscustomobject]
A collection of app objects retrieved from the Microsoft Graph API.

.NOTES
This function requires the Invoke-MgGraphRequest function to be available.

.LINK
https://docs.microsoft.com/graph/api/serviceprincipal-list?view=graph-rest-1.0&tabs=http

#>
function Get-MSGraphEnterpriseApps {
    param (
        [switch] $Beta, # Specifies whether to use the beta version of the Graph API
        [string[]] $Selects, # Specifies the properties to select from the response
        [switch] $All, # Specifies whether to retrieve all enterprise apps
        [int] $Top = 100 # Specifies the maximum number of apps to retrieve
    )
    begin{
        $Filter = "tags/Any(x: x eq 'WindowsAzureActiveDirectoryIntegratedApp')" # Specifies the filter to apply to the apps
        $OriginalTop = $Top # Stores the original value of $Top
    }
    process{
        $Route = $Beta ? "beta" : "v1.0" # Determines the API route based on the $Beta switch
        if($All){
            $Top = 999 # Sets $Top to a high value if $All switch is used
        }
        $URI = 'https://graph.microsoft.com/{0}/servicePrincipals?$Top={1}&$Filter={2}' -f $Route,$Top,$Filter # Constructs the URI for the API request
        if(-not ([string]::IsNullOrEmpty($Selects))){
            $URI += '&$select={0}' -f $($Selects -join ',') # Appends the $select query parameter to the URI if $Selects is not empty
        }
        $ReturnCollection = new-object System.Collections.Generic.List[pscustomobject] # Creates a collection to store the app objects
        $Return = (Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject) # Sends the API request and stores the response
        $($Return.value.ForEach({ 
            $ReturnCollection.Add($_) # Adds each app object to the collection
        }))
        if($All){
            while(-not([string]::IsnullorEmpty($Return.'@odata.nextlink')) -and $ReturnCollection.Count -lt $Top){
                $Return = (Invoke-MgGraphRequest -Method GET -Uri $Return.'@odata.nextlink' -OutputType PSObject) # Sends additional requests to retrieve remaining apps if $All switch is used
                $($Return.value.ForEach({
                    $ReturnCollection.Add($_) # Adds each app object to the collection
                    if($ReturnCollection.Count -eq $Top){
                        break # Breaks the loop if the desired number of apps is reached
                    }
                }))
            }
        }
        
    }
    end{
        if($All){
            return $ReturnCollection # Returns all app objects
        }
        return $ReturnCollection[0..$($OriginalTop-1)] # Returns the specified number of app objects
    }
}
