<#
    .SYNOPSIS
        Runbook for creating Azure Resource Groups

    .DESCRIPTION
        This Runbook will create Resource Groups based on user input parameters

    .PARAMETER ResourceGroupName
        Specify the Resource Group name

    .PARAMETER ResourceGroupRegion
        Region Resource Group will reside in

    .PARAMETER SvcName
        SvcName Tag value

    .PARAMETER SvcOwner
        SvcOwner Tag value

    .PARAMETER CrgCostCode
        CrgCostCode Tag value

    .PARAMETER Environment
        Environment Tag value

    .EXAMPLE
        Run the Runbook through Azure and specify the name/region/tags with parameters

    .NOTES
        Owner:  TSO N&H Cloud and Automation Team (TSONHCloudandAutomation@tfl.co.uk)
        VSTS:   TSO-NH-Automation/azure/runbooks/new-resourcegroup.ps1

        | Author            | QC                | VSTS Story ID     | Release Date  |
        -----------------------------------------------------------------------------
        | Richard Weston    |                   | User Story 777    | 26/07/18      |
#>

## Parameters for RunBook
Param(
    [Parameter( Mandatory = $true )]
    [string]$ResourceGroupName,

    [Parameter()]
    [string]$ResourceGroupRegion = "NorthEurope",

    [Parameter( Mandatory = $true )]
    [ValidateNotNullOrEmpty()]
    [string]$SvcName,

    [Parameter( Mandatory = $true )]
    [ValidateNotNullOrEmpty()]
    [string]$SvcOwner,

    [Parameter( Mandatory = $true )]
    [ValidateNotNullOrEmpty()] 
    [string]$CrgCostCode,

    [Parameter( Mandatory = $true )]
    [ValidateNotNullOrEmpty()]  
    [string]$Environment
)

try {
    ######################################
    ##### SUPPORTING FUNCTIONS START #####
    ######################################

    <#
        .SYNOPSIS
            Validate tag key/value pair against an Azure Blob Table

        .DESCRIPTION
            This function should be used as a helper to validate user entered Azure
            Resource Tags. It requires a storage account and resource group for the
            storage account the Blob Table is stored in. If run successfully the
            casing will be crrected and output to the "Result" property with an Exit
            Code of '0' otherwise '1' will be returned with the last message from the
            "Log" property.

        .PARAMETER resourceGroup
            The Resource Group that the Blob Table resides on must be supplied.

        .PARAMETER storageAccount
            The Storage Account that the Blob Table resides on must be supplied.

        .PARAMETER tagKey
            User entered Tag Key to be validated.

        .PARAMETER tagValue
            User entered Tag Value to be validated.

        .EXAMPLE
            Test-ValidTags @Params

        .NOTES
            Owner:  TSO N&H Cloud and Automation Team (TSONHCloudandAutomation@tfl.co.uk)
            VSTS:   azure/functions/test-ValidTags.ps1

            | Author            | QC                | VSTS Story ID     | Release Date  |
            -----------------------------------------------------------------------------
            | Richard Weston    | Will White        |  | 29/08/18      |
    #>
    function Test-ValidTags {
        param(
            ## Resource Group Storage account resides in
            [Parameter( Mandatory = $true )]
            [ValidateNotNullOrEmpty()]
            [string]$resourceGroup,
            ## Storage Account name
            [Parameter( Mandatory = $true )]
            [ValidateNotNullOrEmpty()]
            [string]$storageAccount,
            ## Name of the tag to validate
            [Parameter( Mandatory = $true )]
            [ValidateNotNullOrEmpty()]
            [string]$tagKey,
            ## Value the tag contains to validate
            [Parameter( Mandatory = $true )]
            [ValidateNotNullOrEmpty()]
            [string]$tagValue
        )
        try {
            #################
            ##### BEGIN #####
            #################
            ## Output Declaration
            class TFL_Output {
                ################
                ### PROPERTY ###
                ################
                # Output successful execution result
                [string]
                $Result = $null
            
                # Execution exit code
                [int]
                hidden
                $ExitCode  = $null
            
                # Capture script details here
                [array]
                hidden
                $Log = @()
            
                ################
                ###  METHOD  ###
                ################
                # Method to append to log property
                AddLogEntry( [string]$Message ) {
                    # Append to array
                    $This.Log       += [pscustomobject] @{
                        # User logged message
                        Message     = $Message
                        # Generate timestamp for the log
                        TimeStamp   = ( Get-Date -Format hh:mm:ss.ffff )
                    }
                }
            
                # Method to return the last entry in $Log
                [pscustomobject]
                LastLogEntry() {
                    # Select last entry in $Log
                    return $This.Log[-1]
                }
            
                # Return a specified Log entry as a string with timestamp
                [string]
                LogToString([int]$logRef) {
                    #Capture Log details as array
                    $logString = @(
                        $This.log[$logRef].TimeStamp
                        $This.log[$logRef].Message
                    )
                    # Stitch strings together and return
                    return ( $logString -join " - " )
                }
            }

            $Output = [TFL_Output]::new()


            ## Output Declaration
            #################
            #####  END  #####
            #################

            #################
            ##### BEGIN #####
            #################
            ## Paramater validation

            # $resourceGroup validation
            $validationTestParam = @{
                Name = $resourceGroup
            }
            $validationTest = Get-AzureRmResourceGroup @validationTestParam
            if ( ! ( $validationTest ) ) {
                # Set output variables
                $Output."ExitCode" = 1
                $Output.AddLogEntry( "Resource Group parameter invalid" )
                # Break and return output
                return
            } else {
                # Log validation pass
                $Output.AddLogEntry( "Resource Group parameter valid" )
            }
            # Santise test variables
            Clear-Variable -Name validationTest,validationTestParam

            # $storageAccount validation
            $validationTestParam = @{
                ResourceGroupName   = $resourceGroup
                Name                = $storageAccount
            }
            $validationTest = Get-AzureRmStorageAccount @validationTestParam
            if ( ! ( $validationTest ) ) {
                # Set output variables
                $Output."ExitCode" = 2
                $Output.AddLogEntry( "Storage Account parameter invalid" )
                # Break and return output
                return
            } else {
                # Log validation pass
                $Output.AddLogEntry( "Storage Account parameter valid" )
            }
            # Santise test variables
            Clear-Variable -Name validationTest,validationTestParam

            ## Paramater validation
            #################
            #####  END  #####
            #################

            #################
            ##### BEGIN #####
            #################
            ## Script Main

            ## Get the storage account context
            $saContextParam = @{
                ResourceGroupName   = $resourceGroup
                Name                = $storageAccount
            }
            $saContext = (Get-AzureRmStorageAccount @saContextParam).Context
            # Validate $saContext
            if ( ! ( $saContext ) ) {
                # Set output variables
                $Output."ExitCode" = 3
                $Output.AddLogEntry( "Unable to get storage account context" )
                # Break and return output
                return
            } else {
                # Log validation pass
                $Output.AddLogEntry( "Storage account context verified" )
            }
            ## Capture the Blob Table as a variable
            $GetAzureStorageTableCrgCostCodeParam = @{
                Name    = "AzureTags"
                Context = $saContext
            }
            $blbTblTag = Get-AzureStorageTable @GetAzureStorageTableCrgCostCodeParam
            # Validate Storage Table
            if ( ! ( $blbTblTag ) ) {
                # Set output variables
                $Output."ExitCode" = 4
                $Output.AddLogEntry( "Unable to get storage table" )
                # Break and return output
                return
            } else {
                # Log validation pass
                $Output.AddLogEntry( "Storage table verified" )
            }
            ## Capture all rows in the table
            $tblTag = Get-AzureStorageTableRowAll -table $blbTblTag
            if ( ! ( $tblTag ) ) {
                # Set output variables
                $Output."ExitCode" = 5
                $Output.AddLogEntry( "Table is blank or inaccessible" )
                # Break and return output
                return            
            } else {
                # Log validation pass
                $Output.AddLogEntry( "Storage table contents verified" )
            }
            $tblTagTagKeyTest = $tblTag.$TagKey -contains $tagValue
            ## Test if the value is contained in the Blob Table
            if ( ! ( $tblTagTagKeyTest ) ) {
                # Tag value NOT an exact match
                $Output."ExitCode" = 6
                $Output.AddLogEntry( "$( $tagKey ) tag is invalid" )
                # Break and return output
                return
            } else {
                # Log validation pass
                $Output.AddLogEntry( "Tag validated" )
            }

            ## Script Main
            #################
            #####  END  #####
            #################

            ## Result
            # Tag value IS an exact match, additional code just captures the casing
            $Output.Result      = $tblTag.$TagKey | Where-Object { $PSItem -contains $tagValue }
            $Output."ExitCode"  = 0
            return

        }
        catch {
            $errorMessage = @(
                "Error in function: Unhandled exception ::"
                "Line: $($_.InvocationInfo.ScriptLineNumber)"
                "Line: $($_.InvocationInfo.Line.Trim())"
                "Error message: $($_.Exception.Message)"
            )   
            # Output errors for debugging and halt runbook
            Write-Error -Message ( $errorMessage -join " " )
            return
        }
        finally {
            ## Return $Output object
            $Output
        }

    }

    ### TAG VALIDATIONS ARRAYS
    ## CRGCOSTCODE
    $crgTagTbl = @(
        "RCE02.CT.AZURE"
        "10935"
        "RX01MOBSUPP.02"
        "10940"
        "RXCHG.012.002"
        "RCE02.BD.HOST.PIL.P4"
        "10745"
        "10950"
        "10951"
        "10949"
        "AMCPP04.002.001"
        "RX01CPL.006.006.03"
        "CX01HR.01.001"
        "10790"
        "RCE02.BD.HOST.PIL.P2"
        "SC.3371.001"
        "10952"
        "SC.3487.005"
        "10197"
        "2400107"
        "39035"
        "RX01INF.APPS.004"
        "10859"
        "1017465"
        "2403348"
    )
    ## ENVIRONMENT
    $envTagTbl = @(
        "Production"
        "Development"
        "Pre-Production"
        "Test"
    )

    ######################################
    ##### SUPPORTING FUNCTIONS END   #####
    ######################################

    ## Connect to Azure with Run As Account
    $Conn = Get-AutomationConnection -Name AzureRunAsConnection
    [hashtable]$AddAzureRMAccountParam = @{
        ServicePrincipal        = $true
        Tenant                  = $Conn.TenantID
        ApplicationId           = $Conn.ApplicationID
        CertificateThumbprint   = $Conn.CertificateThumbprint
    }
    [hashtable]$ConnectAzureADParam = @{
        Tenant                  = $Conn.TenantID
        ApplicationId           = $Conn.ApplicationID
        CertificateThumbprint   = $Conn.CertificateThumbprint
    }
    [void]@( 
        Add-AzureRMAccount @AddAzureRMAccountParam
        Set-AzureRmContext -SubscriptionId $Conn.SubscriptionId
        Enable-AzureRmContextAutosave
        Connect-AzureAD @ConnectAzureADParam
    )
    ## Script Main
    ## Test if Resource Group Already Exists
    if ( Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue ) {
        Write-Error -Message "Resource group already exists"
        return
    }
    ## Test if SvcOwner is a Group
    <# DISABLED TEST
    $SvcOwnerGroup = Get-AzureADGroup -Filter "mail eq '$SvcOwner'"
    if ( ! ( $SvcOwnerGroup ) ) {
        Write-Error -Message "SvcOwner tag is not a distribution list"
        return
    }
    DISABLED TEST #>
    # Complete tests
    $crgTagTest = $crgTagTbl -contains $CrgCostCode
    if ( ! ( $crgTagTest ) ) {
        Write-Error -Message "The tag for CrgCostCode entered is invalid"
        Write-Error -Message "Please check the tag or contact the team who manages this"
        return
    } else {
        # Set the variable as the output to correct any casing issues
        $CrgCostCode = $crgTagTbl | Where-Object { $PSItem -contains $CrgCostCode }
    }
    $envTagTest = $envTagTbl -contains $Environment
    if ( ! ( $envTagTest ) ) {
        Write-Error -Message "The tag for Environment entered is invalid"
        Write-Error -Message "Please check the tag or contact the team who manages this"
        return
    } else {
        # Set the variable as the output to correct any casing issues
        $Environment = $envTagTbl | Where-Object { $PSItem -contains $Environment }
    }

    <# TAG VALIDATION FUNCTION TEST
    ## Tag validation variables
    $resourceGroup = "TSO-NH-Automation-MO-rg"
    $storageAccount = "tsonhautomationmoblob"
    # CrgCostCode test parameters
    $TestValidTagsParam = @{
        resourceGroup   = $resourceGroup
        storageAccount  = $storageAccount
        tagKey          = "CrgCostCode"
        tagValue        = $CrgCostCode
    }
    # Environment test parameters
    $TestValidTagsParam = @{
        resourceGroup   = $resourceGroup
        storageAccount  = $storageAccount
        tagKey          = "Environment"
        tagValue        = $Environment
    }
    # Complete tests
    $crgTagTest = Test-ValidTags @TestValidTagsParam
    if ( ! ( $crgTagTest ).ExitCode -eq 0 ) {
        Write-Error -Message "The tag for CrgCostCode entered is invalid"
        Write-Error -Message "Please double-check the tag or contact the team who manages this"
        return
    } else {
        # Set the variable as the output to correct any casing issues
        $CrgCostCode = ( $crgTagTest ).Result
    }
    $envTagTest = Test-ValidTags @TestValidTagsParam
    if ( ! ( $envTagTest ).ExitCode -eq 0 ) {
        Write-Error -Message "The tag for Environment entered is invalid"
        Write-Error -Message "Please double-check the tag or contact the team who manages this"
        return
    } else {
        # Set the variable as the output to correct any casing issues
        $Environment = ( $envTagTest ).Result
    }
    TAG VALIDATION FUNCTION TEST #>
    # Assemble hashtable for new RG
    [hashtable]$azRGTagTable = @{
        SvcName     = $SvcName
        SvcOwner    = $SvcOwner
        CrgCostCode = $CrgCostCode
        Environment = $Environment
    }

    # New Resource Group creation
    [hashtable]$NewAzureRmResourceGroupParam = @{
        Name        = $ResourceGroupName
        Location    = $ResourceGroupRegion
        Tags        = $azRGTagTable
    }
    $azNewRG = New-AzureRmResourceGroup @NewAzureRmResourceGroupParam
    # RBAC settings
    [hashtable]$NewAzureRmRoleAssignment = @{
        ResourceGroupName   = $azNewRG.ResourceGroupName
        RoleDefinitionName  = "Owner"
        ObjectId            = $SvcOwnerGroup.ObjectId
    }
    New-AzureRmRoleAssignment @NewAzureRmRoleAssignment

}
catch {
    $errorMessage = @(
        "Error in Runbook: Unhandled exception ::"
        "Line: $($_.InvocationInfo.ScriptLineNumber)"
        "Line: $($_.InvocationInfo.Line.Trim())"
        "Error message: $($_.Exception.Message)"
    )
    # Output errors for debugging and halt runbook
    Write-Error -Message ( $errorMessage -join " " ) -ErrorAction Stop
}
