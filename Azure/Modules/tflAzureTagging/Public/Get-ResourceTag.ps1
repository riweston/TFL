<#
.SYNOPSIS
    TFL function for getting Resource tags
.DESCRIPTION
    Function for getting the resource tags in Azure for the Network and Hosting team
    Filters classic/untaggable Resources
.PARAMETER azSubscription
    Azure subcription to search within
.PARAMETER azResourceGroup
    Azure resource group to search within
.PARAMETER azResource
    Azure resource to collect tags from
.EXAMPLE
    C:\PS>  Get-ResourceTag -azSubscription "My Azure Subscipription" -azResourceGroup "My Azure Resource Group"
            -azResource "vNet001"
        Example of how to use this cmdlet
.FUNCTIONALITY
    Internal tool for TFL to retrieve resource tags from Azure resources
#>
function Get-ResourceTag {
    [CmdletBinding()]
    ## Function parameters
    Param (
        [Parameter(Mandatory = $false)]
        $azSubscription = $null,
        [Parameter(Mandatory = $false)]
        $azResourceGroup = $null,
        [Parameter(Mandatory = $false)]
        $azResource = $null
    )
    
    try {
        ## Function variables start ##
        # Output variable
        $Output = @()
        # Test if connected to Azure
        Test-AzureLogin
        ## Function variables end ##

        ## Parameter tests start ##
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
                $azSubscriptionTest = Get-AzureRmSubscription -SubscriptionName $azSubscription -ErrorVariable Output -ErrorAction SilentlyContinue
                if (!($azSubscriptionTest)) {
                    return $Output.Exception
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
                $azResourceGroupTest = Get-AzureRmResourceGroup -Name $azResourceGroup -ErrorVariable Output -ErrorAction SilentlyContinue
                if (!($azResourceGroupTest)) {
                    return $Output.Exception
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
                $azResourceTest = Get-AzureRmResource -ResourceGroupName $azResourceGroup -ResourceName $azResource -ErrorVariable Output -ErrorAction SilentlyContinue
                if (!($azResourceTest)) {
                    return $Output.Exception                    
                }
            }
        }
        ## Parameter tests end ##

        ## Script main start ##
        # Use the validated parameters to collect the tags of the resource
        $azResourceTags = (Get-AzureRmResource -ResourceName $azResource -ResourceGroupName $azResourceGroup).tags
        # Convert to custom object
        $Output = [PSCustomObject]$azResourceTags
        # Final function output
        return $Output
        ## Script main end ##
        }

    catch {
        $Output += "ERROR in Set-ResourceTag: Unhandled exception :: (Line: $($_.InvocationInfo.ScriptLineNumber) Line: $($_.InvocationInfo.Line) Error message: $($_.exception.message)" 
        return $Output
    }
}
