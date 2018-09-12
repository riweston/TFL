## Helper Functions
<#
    Helper function for merging hashtables
    <https://stackoverflow.com/questions/8800375/merging-hashtables-in-powershell-how>
#>

function Merge-HashTable {
    param(
        [hashtable] $OriginTable, # your original set
        [hashtable] $Append # the set you want to update/Append to the original set
    )

    # clone for idempotence
    $OriginTable1 = $OriginTable.Clone() ;

    # we need to remove any key-value pairs in $OriginTable1 that we will
    # be replacing with key-value pairs from $uppend
    foreach ($key in $Append.Keys) {
        if ($OriginTable1.ContainsKey($key)) {
            $OriginTable1.Remove($key) ;
        }
    }

    # union both sets
    return $OriginTable1 + $Append ;
}

## Runbook Variables
# Resource types that are untaggable
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
    "Microsoft.StorageSync/storageSyncServices"
    "microsoft.insights/activityLogAlerts"
)

# Counters for results
$tagCounterSuccess      = 0
$tagCounterFail         = 0
$tagCounterSkip         = 0
$tagCounterNull         = 0
$tagCounterUntaggable   = 0
$tagCounterError        = 0

# Debugging Var
$untaggableresourcesList = @{}

## Connect to Azure with Run As account
$Conn = Get-AutomationConnection -Name AzureRunAsConnection
$azRMAccountParams = @{
    ServicePrincipal        = $true
    Tenant                  = $Conn.TenantID
    ApplicationId           = $Conn.ApplicationID
    CertificateThumbprint   = $Conn.CertificateThumbprint
}
Add-AzureRMAccount @azRMAccountParams | Out-Null

## Script main
try {
    # Capture Tags from Resource Group
    $azResourceGroups = Get-AzureRmResourceGroup

    # Iterate through groups and set tags
    foreach ($azResourceGroup in $azResourceGroups) {
        # Get Resources in the Resource Group
        $azResources = Get-AzureRmResource | Where-Object {
            $_.ResourceGroupName -like $azResourceGroup.ResourceGroupName
        }
        # Standard TFL tags
        $tflTags = @{
            "SvcName"       = $null
            "SvcOwner"      = $null
            "CrgCostCode"   = $null
            "Environment"   = $null
        }
        # Temp var to store RG tags before merge
        $tempTable = @{}
        # Test for Tags property
        switch ($azResourceGroup.PSObject.Properties['Tags']) {
            # If Tags property is present
            ({$PSItem.Value})
            {
                # Iterate through Resource Group Tags
                foreach ($kvpRG in $azResourceGroup.Tags.GetEnumerator()) {
                    # Iterate through TFL Tags
                    foreach ($kvpTag in $tflTags.GetEnumerator()) {
                        # If match is found add Resource Group Tag/Value to $tempTable
                        if ($kvpTag.Key -like $kvpRG.Key) {
                            $tempTable.Add($kvpRG.Key,$kvpRG.Value)
                        }
                    }
                }
            }
            # If Tags property is not present
            ({!($PSItem.Value)})
            {
                $tagCounterNull++
                # Log this for informational purposes
                Write-Warning "No Tags set on $($azResourceGroup.ResourceGroupName)"
            }
        }

        # Merge TFL Tags with the Resource Group Tags
        # We do it this way so that even if it's blank the key is added
        $mergeTableRGParams = @{
            "OriginTable"   = $tflTags
            "Append"        = $tempTable
        }
        $mergeTableRG = Merge-HashTable @mergeTableRGParams

        # Iterate through the Resources
        foreach ($azResource in $azResources) {
            # Reset resource tagging skip variables
            $untaggableResource = $false
            $skipResource = $false
            # Variables used in loop / To be cleared
            @(
                "azResourceTags"
                "newTags"
                "currentTags"
                "mergeTable"
                "verifyTagsTest"
                "mergeTableParams"
                "compareObjectParams"
                "getAzureRmResourceParams"
                "setAzureRmResourceParams"
                "verifyCompareObjectParams"
            ).ForEach({if (Get-Variable $PSItem -ErrorAction SilentlyContinue) {Clear-Variable $PSItem}})
            # Excluded resource tests
            $exTest1 = $azResource.ResourceType -in $exAzureResources
            $exTest2 = ($azResource.Kind -like "*system") -and ($azResource.ResourceType -like "Microsoft.Sql/servers/*")
            # Test if resourceType is classic
            switch ($azResource) {
                # If in the exclude list ignore
                ({$exTest1 -or $exTest2})
                {
                    $tagCounterUntaggable++
                    $untaggableResource = $true
                    # Uncomment for debugging purposes
                    #Write-Output "$($azResource.ResourceName) is not a taggable resource"
                    $Key = $azResource.ResourceName
                    $Value = $azResource.ResourceType
                    $untaggableresourcesList.Add($Key,$Value)
                    break
                }
                # If not in the exclude list 
                ({!($exTest1 -or $exTest2)})
                {
                    break
                }
            } # End Classic Resource test
            # Test if resource is taggable
            if ($untaggableResource) {
                # Move on to next item
                continue
            }
            # Test each Resource for Tags property
            switch ($azResource.PSObject.Properties['Tags']) {
                # If Tags property is present
                ({$PSItem})
                {
                    # Capture Tags hashtable to var
                    $azResourceTags = $azResource.Tags
                }
                # If Tags property is not present
                ({!($PSItem)})
                {
                    # Create blank/dummy hashtable for the merge
                    $azResourceTags = @{}
                }
            }
            # Parameters for the merge table below
            $mergeTableParams = @{
                OriginTable = $mergeTableRG
                Append      = $azResourceTags
            }
            # Final merge with all tags for resource
            $mergeTable = Merge-HashTable @mergeTableParams
            if ($azResourceTags.Count -eq 0) {
                $azResourceTags = @{
                    (Get-Date).ToString('sshhddmmyy') = (Get-Date).ToString('sshhddmmyy')
                }
            }
            # Test if tags are up to date
            # Convert hastables to PSCustomObject so that we can use Compare-Object
            $currentTags = ([PSCustomObject]$azResourceTags).PSObject.Properties | Sort-Object Name
            $newTags = ([PSCustomObject]$mergeTable).PSObject.Properties | Sort-Object Name
            # Parameters for the Compare-Object
            $compareObjectParams = @{
                ReferenceObject     = $currentTags
                DifferenceObject    = $newTags
            }
            # Compare objects to test if any action should be taken
            switch (!(Compare-Object @compareObjectParams)) {
                # If tags match skip
                ({$PSItem})
                {
                    $tagCounterSkip++
                    $skipResource = $true
                    # Commented out to avoid noise
                    # Uncomment for debugging purposes
                    #Write-Output "Skip $($azResource.ResourceName)"
                    break
                }
                # If mismatch then tag
                ({!($PSItem)})
                {
                    break
                }
            } # End Tagging switch
            # Test if resource can be skipped
            if ($skipResource) {
                # Move on to next item
                continue
            }
            try {
                # Get-AzureRmResource Paramaters
                $getAzureRmResourceParams = @{
                    ResourceName        = $azResource.ResourceName
                    ResourceGroupName   = $azResourceGroup.ResourceGroupName
                }
                # Set-AzureRmResource Parameters
                $setAzureRmResourceParams = @{
                    ResourceName        = $azResource.ResourceName
                    ResourceGroupName   = $azResource.ResourceGroupName
                    ResourceType        = $azResource.ResourceType
                    Tag                 = $mergeTable
                    Force               = $true
                }
                # Run tagging command
                Write-Output "Tagging $($azResource.ResourceName)..."
                $taggingJob = Start-Job -ScriptBlock {
                    Set-AzureRmResource @setAzureRmResourceParams | Out-Null
                }
                # Tagging runs as a job with 2 min timeout
                $taggingJob | Wait-Job -Timeout 120 | Out-Null
                # End job
                if (!($taggingJob | Where-Object {$_.State -eq "Completed"})) {
                    $PSItem | Stop-Job
                    Write-Warning -Message "$($azResource.ResourceName) tagging job timed out after 2 minutes"
                }
                # Verify Tagging was successful
                # Grab new Tags
                $verifyTagsTest = [PSCustomObject](Get-AzureRmResource @getAzureRmResourceParams).Tags
                $verifyTagsTest = $verifyTagsTest.PSObject.Properties | Sort-Object Name
                $verifyCompareObjectParams = @{
                    ReferenceObject     = $verifyTagsTest
                    DifferenceObject    = $newTags
                }
                # Compare current tags to what *SHOULD* have been applied
                switch (!(Compare-Object @verifyCompareObjectParams)) {
                    # If match, log successfull
                    ({$PSItem})
                    {
                        $tagCounterSuccess++
                        Write-Output "$($azResource.ResourceName) was tagged successfully"
                    }
                    # If they don't match log and log last error for debugging
                    ({!($PSItem)})
                    {
                        $tagCounterFail++
                        Write-Warning -Message "$($azResource.ResourceName) failed tagging"
                        Write-Warning -Message "Error message: $($_.Exception.Message)"
                    }
                }
            }
            catch {
                $tagCounterError++
                Write-Warning -Message "Unable to set tag"
                Write-Warning -Message "Error message: $($_.Exception.Message)"
            }
        } # End Resource loop
    } # End Resource Group loop

    ## Final Script Output
    $outputTable = @{
        "Resources Tagged"          = $tagCounterSuccess
        "Resources Failed Tagging"  = $tagCounterFail
        "Resources Skipped Tagging" = $tagCounterSkip
        "Resource Groups w/o Tags"  = $tagCounterNull
        "Resources Untaggable"      = $tagCounterUntaggable
        "Errors"                    = $tagCounterError
    }
    $Output = [PSCustomObject]$outputTable
    return $Output
}
catch {
    # Capture all errors
    $errorMessage = @(
        "Error in Runbook: Unhandled exception ::"
        "Line: $($_.InvocationInfo.ScriptLineNumber)"
        "Line: $($_.InvocationInfo.Line.Trim())"
        "Error message: $($_.Exception.Message)"
    )
    # Output errors for debugging and halt runbook
    Write-Error -Message ($errorMessage -join " ") -ErrorAction Stop
}