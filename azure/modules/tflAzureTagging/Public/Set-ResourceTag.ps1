<#
.SYNOPSIS
    TFL function for setting Resource tags
.DESCRIPTION
    Function for setting the resource tags in Azure for the Network and Hosting team
    Filters classic/untaggable Resources
.PARAMETER azSubscription
    Azure subscription to process
.PARAMETER azResourceGroup
    Azure resource group to process
.PARAMETER azResource
    Azure resource to process
.PARAMETER azTagSvcNameValue
    Value to apply to the SvcName tag
.PARAMETER azTagSvcOwnerValue
    Value to apply to the SvcOwner tag
.PARAMETER azTagCrgCostCodeValue
    Value to apply to the CrgCostCode tag
.PARAMETER azTagEnvironmentValue
    Value to apply to the Environment tag
.PARAMETER Force
    If enabled, skip the check for a blank value in the tag parameters
.EXAMPLE
    C:\PS>  Set-ResourceTag -azResourceGroup "My Azure Resource Group"
            -azSubscription "Subscription" -azResource "vNet001"
            -azTagSvcNameValue "BatMobile" -azTagSvcOwnerValue "BatMan"
            -azTagCrgCostCodeValue "Alfred001" -azTagEnvironmentValue "BatCave"
        Example of how to use this cmdlet
.EXAMPLE
    C:\PS>  Get-ResourceTag @params | Set-ResourceTag -Force $true
        Another example of how to use this cmdlet
.FUNCTIONALITY
    Internal tool for TFL to assign tags to Azure resources via the resource group name
#>
function Set-ResourceTag {
    [CmdletBinding()]
    ## Function parameters
    Param (
        [Parameter(Mandatory = $false)]
        $azSubscription = $null,
        [Parameter(Mandatory = $false)]
        $azResourceGroup = $null,
        [Parameter(Mandatory = $false)]
        $azResource = $null,
        [Parameter(Mandatory = $false)]
        $azTagSvcNameValue = $null,
        [Parameter(Mandatory = $false)]
        $azTagSvcOwnerValue = $null,
        [Parameter(Mandatory = $false)]
        $azTagCrgCostCodeValue = $null,
        [Parameter(Mandatory = $false)]
        $azTagEnvironmentValue = $null,
        [Parameter(Mandatory = $false)]
        [bool]$Force = $false
    )

    try {
        ## Function variables start ##
        # Test if connected to Azure
        Test-AzureLogin
        # Untaggable resources
        $exAzureResources = @(
            "Microsoft.ClassicNetwork/virtualNetworks"
            "Microsoft.ClassicStorage/storageAccounts"
            "Microsoft.ClassicCompute/domainNames"
            "Microsoft.ClassicCompute/virtualMachines"
            "Microsoft.OperationsManagement/solutions"
            "Microsoft.DomainRegistration/domains"
            "microsoft.insights/alertrules"
            "microsoft.insights/webtests"
            "TrendMicro.DeepSecurity/accounts"
            "Microsoft.Automation/automationAccounts/configurations"
        )
        
        $Log = $null
        $ErrorMessage = $null
        $Output = @()
        ## Function variables end ##

        ## Parameter test start ##
        # Test Azure subscription parameter
        switch ($azSubscription) {
            # If null prompt for user input
            ($null)
            {
                $azSubscription = ( Get-AzureRmSubscription |
                                    Select-Object -Property Name |
                                    Sort-Object -Property Name |
                                    Out-GridView -Title "Select Azure Subscription..." -PassThru).Name
            }
            # Validate specified parameter
            ({!($null)})
            {
                $azSubscriptionTestParams = @{
                    SubscriptionName = $azSubscription
                    ErrorVariable = "ErrorOutput"
                    ErrorAction = "SilentlyContinue"
                }
                $azSubscriptionTest = Get-AzureRmSubscription @azSubscriptionTestParams
                if (!($azSubscriptionTest)) {
                    return $ErrorOutput.Exception
                }
            }
        }

        # Set Azure subscription context
        Set-AzureRmContext -SubscriptionName $azSubscription | Out-Null

        # Test Azure resource group parameter
        switch ($azResourceGroup) {
            ($null)
            {
                $azResourceGroup = (    Get-AzureRmResourceGroup |
                                        Select-Object -Property ResourceGroupName |
                                        Sort-Object -Property ResourceGroupName |
                                        Out-GridView -Title "Select Azure Resource Group..." -PassThru).ResourceGroupName
            }
            # Validate specified parameter
            ({!($null)})
            {
                $azResourceGroupTestParams = @{
                    Name = $azResourceGroup
                    ErrorVariable = "ErrorOutput"
                    ErrorAction = "SilentlyContinue"
                }
                $azResourceGroupTest = Get-AzureRmResourceGroup @azResourceGroupTestParams
                if (!($azResourceGroupTest)) {
                    return $ErrorOutput.Exception
                }
            }
        }
        # Test Azure resource parameter
        switch ($azResource) {
            # If null prompt for user input
            ($null)
            {
                $azResource = ( Get-AzureRmResource |
                                Where-Object {$_.ResourceGroupName -eq $azResourceGroup} |
                                Select-Object -Property ResourceName |
                                Sort-Object -Property ResourceName |
                                Out-GridView -Title "Select Azure Resource..." -PassThru).ResourceName
            }
            # Validate specified parameter
            ({!($null)})
            {
                $azResourceTestParams = @{
                    ResourceGroupName = $azResourceGroup
                    ResourceName = $azResource
                    ErrorVariable = "ErrorOutput"
                    ErrorAction = "SilentlyContinue"
                }
                $azResourceTest = Get-AzureRmResource @azResourceTestParams
                if (!($azResourceTest)) {
                    return $ErrorOutput.Exception                    
                }
            }
        }
        # Set resource object var
        $azResourceParams = @{
            ResourceGroupName = $azResourceGroup
            ResourceName = $azResource
        }
        $azResource = Get-AzureRmResource @azResourceParams
        # Test for SvcName tag
        # If blank prompt user for input
        if (!($azTagSvcNameValue) -and !($Force)) {
            $tagName = "SvcName"
            $azTagSvcNameValue = Read-Host -Prompt "Please enter the value for the $tagName tag"
            switch ($azTagSvcNameValue) {
                ({[string]::IsNullOrEmpty($PSItem)})
                {
                    Write-Output "$tagName `= `$null"
                }
                ({!([string]::IsNullOrEmpty($PSItem))})
                {
                    Write-Output "$tagName `= $azTagSvcNameValue"
                }
            }
        }
        # Test for SvcOwner tag
        # If blank prompt user for input
        if (!($azTagSvcOwnerValue) -and !($Force)) {
            $tagName = "SvcOwner"
            $azTagSvcOwnerValue = Read-Host -Prompt "Please enter the value for the $tagName tag"
            switch ($azTagSvcOwnerValue) {
                ({[string]::IsNullOrEmpty($PSItem)})
                {
                    Write-Output "$tagName `= `$null"
                }
                ({!([string]::IsNullOrEmpty($PSItem))})
                {
                    Write-Output "$tagName `= $azTagSvcOwnerValue"
                }
            }
        }
        # Test for CrgCostCode tag
        # If blank prompt user for input
        if (!($azTagCrgCostCodeValue) -and !($Force)) {
            $tagName = "CrgCostCode"
            $azTagCrgCostCodeValue = Read-Host -Prompt "Please enter the value for the $tagName tag"
            switch ($azTagCrgCostCodeValue) {
                ({[string]::IsNullOrEmpty($PSItem)})
                {
                    Write-Output "$tagName `= `$null"
                }
                ({!([string]::IsNullOrEmpty($PSItem))})
                {
                    Write-Output "$tagName `= $azTagCrgCostCodeValue"
                }
            }
        }
        # Test for CrgCostCode tag
        # If blank prompt user for input
        if (!($azTagEnvironmentValue) -and !($Force)) {
            $tagName = "Environment"
            $azTagEnvironmentValue = Read-Host -Prompt "Please enter the value for the $tagName tag"
            switch ($azTagEnvironmentValue) {
                ({[string]::IsNullOrEmpty($PSItem)})
                {
                    Write-Output "$tagName `= `$null"
                }
                ({!([string]::IsNullOrEmpty($PSItem))})
                {
                    Write-Output "$tagName `= $azTagEnvironmentValue"
                }
            }
        }
        ## Parameter test end ##
   
        ## Function script start ##
        # Standard Network and Hosting tags
        $resourceTags = @{
            "SvcName"       = $azTagSvcNameValue
            "SvcOwner"      = $azTagSvcOwnerValue
            "CrgCostCode"   = $azTagCrgCostCodeValue
            "Environment"   = $azTagEnvironmentValue
        }
        # Get existing tags
        $azResourceExistingTags = $azResource.Tags

        # Merge hastables
        $azResourceExistingTags, $resourceTags | Merge-HashTables {$_[-1]}

        switch ($azResource.ResourceType) {
            # If no match to the exclusions proceed with tagging and log to $Output
            ({!($PSItem -in $exAzureResources)})
            {
                $Log = "Applying Tags to $($azResource.ResourceName)"
                $setAzureRMResourceParams = @{
                    ResourceId = $azResource.ResourceId
                    Tag = $resourcetags
                    Force = $true
                }
                Set-AzureRmResource @setAzureRMResourceParams | Out-Null
            }
            # If matches an exclusion skip and log to $Output
            ({$PSItem -in $exAzureResources})
            {
                $Log = "Skipping $($azResource.ResourceName), this is an untaggable resource"
            }
            # Log any unhandled exceptions
            default
            {
                $Log = "Error:"
                $ErrorMessage = "$($azResource.ResourceName) :: $($_)"
            }
        }
        $Output = [PSCustomObject]@{
            Log = $Log
            Error = $ErrorMessage
        }
        
        ## Function script end ##

        # Function output
        return $Output

    }

    catch {
        $ErrorMessage = "ERROR in Set-ResourceTag: Unhandled exception :: " +
                        "(Line: $($_.InvocationInfo.ScriptLineNumber) " +
                        "Line: $($_.InvocationInfo.Line) " +
                        "Error message: $($_.exception.message)" 
        $Log
        $Output = [PSCustomObject]@{
            Log = $Log
            Error = $ErrorMessage
        }
        return $Output
    }
}
