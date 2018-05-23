<#
.SYNOPSIS
    TFL function for getting Resource Group tags
.DESCRIPTION
    Function for getting the resource group tags in Azure for the Network and Hosting team
    Filters classic/untaggable Resources
.PARAMETER azSubscription
    Azure subcription to search within
.PARAMETER azResourceGroup
    Azure resource group to search within
.EXAMPLE
    C:\PS>  Get-ResourceGroupTag -azSubscription "My Azure Subscipription" -azResourceGroup "My Azure Resource Group"
        Example of how to use this cmdlet
.FUNCTIONALITY
    Internal tool for TFL to retrieve tags from Azure resource groups
#>
function Get-ResourceGroupTag {
    [CmdletBinding()]
    ## Function parameters
    Param (
        [Parameter(Mandatory = $false)]
        $azSubscription = $null,
        [Parameter(Mandatory = $false)]
        $azResourceGroup = $null
    )
    
    try {
        ## Function variables start ##
        # Output variable
        $Output = @()
        # Temp table for outputting to
        $outputTable = @()
        # TFL cost tags
        $tflCostTags = @(
            "SvcName"
            "SvcOwner"
            "CrgCostCode"
            "Environment"
        )
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
                $azSubscriptionTestParams = @{
                    SubscriptionName    = $azSubscription
                    ErrorVariable       = "Output"
                    ErrorAction         = "SilentlyContinue"
                }
                $azSubscriptionTest = Get-AzureRmSubscription @azSubscriptionTestParams
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
                $azResourceGroupTestParams = @{
                    Name            = $azResourceGroup
                    ErrorVariable   = "Output"
                    ErrorAction     = "SilentlyContinue"
                }
                $azResourceGroupTest = Get-AzureRmResourceGroup @azResourceGroupTestParams
                if (!($azResourceGroupTest)) {
                    return $Output.Exception
                }
            }
        }
        ## Parameter tests end ##

        ## Script main start ##
        # Use the validated parameters to collect the tags of the resource
        $azResourceGroupTags = (Get-AzureRmResourceGroup -ResourceGroupName $azResourceGroup).tags
        # Iterate through key-value-pairs
        foreach ($kvp in $azResourceGroupTags.GetEnumerator()) {
            # Temp table to store enumberated variables
            $tempTable = @{
                [string]$kvp.Key = $kvp.Value
            }
            # Match name against TFL tags and add to output table
            if ($kvp.Key -in $tflCostTags) {
                $outputTable += $tempTable
            }
        }
        # Convert to custom object
        $Output = [PSCustomObject]$outputTable
        # Final function output
        return $Output
        ## Script main end ##
        }

    catch {
        $Output +=  "ERROR in Get-ResourceGroupTag: Unhandled exception :: " +
                    "(Line: $($_.InvocationInfo.ScriptLineNumber) " +
                    "Line: $($_.InvocationInfo.Line) " +
                    "Error message: $($_.exception.message)" 
        return $Output
    }
}
