<#
.SYNOPSIS
Retrieves permissions for Microsoft Graph Enterprise Applications.

.DESCRIPTION
The Get-MSGraphEnterpriseApplicationPermission function retrieves the permissions assigned to Microsoft Graph Enterprise Applications. 
It supports filtering by Application ID, Display Name, or retrieving all enterprise applications. 
The function can also target either the beta or v1.0 endpoint of the Microsoft Graph API.

.PARAMETER AppID
Specifies the Application ID of the enterprise application to filter by. This parameter is mandatory when using the "AppIDSet" parameter set.

.PARAMETER DisplayName
Specifies the display name of the enterprise application to filter by. This parameter is mandatory when using the "DisplayNameSet" parameter set.

.PARAMETER All
Retrieves all enterprise applications. This parameter is mandatory when using the "AllSet" parameter set.

.PARAMETER Beta
Switch to use the beta endpoint of the Microsoft Graph API. If not specified, the v1.0 endpoint is used.

.EXAMPLE
Get-MSGraphEnterpriseApplicationPermission -AppID "your-app-id"

Retrieves permissions for the enterprise application with the specified Application ID.

.EXAMPLE
Get-MSGraphEnterpriseApplicationPermission -DisplayName "your-display-name"

Retrieves permissions for the enterprise application with the specified display name.

.EXAMPLE
Get-MSGraphEnterpriseApplicationPermission -All

Retrieves permissions for all enterprise applications.

.NOTES
This function requires the Microsoft Graph PowerShell SDK to be installed and authenticated.
#>
function Get-MSGraphEnterpriseApplicationPermission {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ParameterSetName="AppIDSet")]
        [string] $AppID,

        [Parameter(Mandatory=$true, ParameterSetName="DisplayNameSet")]
        [string] $DisplayName,

        [Parameter(Mandatory=$true, ParameterSetName="AllSet")]
        [switch] $All,

        [switch] $Beta
    )
    
    begin {
        # Determine the API endpoint version based on the $Beta switch
        $Endpoint = if($Beta){
            "beta"
        }else{
            "v1.0"
        }
    }
    
    process {
        # Fetch the AppRoles for a specific service principal (hardcoded AppID)
        $Approles = (Invoke-MgGraphRequest -Method Get -Uri "https://graph.microsoft.com/$Endpoint/servicePrincipals?`$filter=AppID eq '00000003-0000-0000-c000-000000000000'" -OutputType PSObject).Value.AppRoles
        
        # Construct the filter for enterprise applications based on the parameter set used
        $EnterpriseApplicationFilter = "tags/Any(x: x eq 'WindowsAzureActiveDirectoryIntegratedApp')$(switch ($PSCmdlet.ParameterSetName) {
            "appIDSet" { " and AppID eq '$AppID'" }
            "DisplayNameSet" { " and startswith(DisplayName, '$DisplayName')" }
        })"
        
        try {
            # Fetch enterprise applications matching the constructed filter
            $EnterpriseApplication = (Invoke-MgGraphRequest -Method Get -Uri "https://graph.microsoft.com/$Endpoint/servicePrincipals?`$filter=$EnterpriseApplicationFilter" -OutputType PSObject).Value
            
            # Check if no enterprise applications were found
            if(@($EnterpriseApplication).Count -eq 0){
                throw "No enterprise applications found"
                return
            }
        }
        catch {
            # Output the exception message if an error occurs
            $_.Exception.Message
            $_
            return
        }
        
        # Iterate over each enterprise application object found
        $Results = foreach($EnterpriseApplicationObject in @($EnterpriseApplication)){
            # Fetch the Service Principal ID for the current enterprise application
            $ServicePrincipalID = (Invoke-MgGraphRequest -Method Get -Uri "https://graph.microsoft.com/$Endpoint/servicePrincipals?`$filter=AppID eq '$($EnterpriseApplicationObject.AppID)'" -OutputType PSObject).Value.ID
            
            # Create a custom object with the display name, AppID, and permissions
            [PSCustomObject]@{
                DisplayName = $EnterpriseApplicationObject.displayName
                AppID = $EnterpriseApplicationObject.AppId
                Permission = (Invoke-MgGraphRequest -Method Get -Uri "https://graph.microsoft.com/$Endpoint/servicePrincipals/$ServicePrincipalID/appRoleAssignments" -OutputType PSObject).Value.AppRoleId.ForEach({
                    # Map the AppRoleId to the corresponding AppRole value
                    ($AppRoles | Where-Object Id -eq $_).Value
                })
            }
        }
    }
    
    end {
        # Return the results collected in the process block
        return $Results
    }
}
