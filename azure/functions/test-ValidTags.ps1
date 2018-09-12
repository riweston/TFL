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
        | Richard Weston    | Will White        | User Story 949    | 29/08/18      |
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
                    $this.log[$logRef].TimeStamp
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
            $Output."ExitCode" = 1
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
            $Output."ExitCode" = 1
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
            $Output."ExitCode" = 1
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
            $Output."ExitCode" = 1
            $Output.AddLogEntry( "Table is blank or inaccessible" )
            # Break and return output
            return            
        } else {
            # Log validation pass
            $Output.AddLogEntry( "Storage table contents verified" )
        }
        ## Test if the value is contained in the Blob Table
        if ( ! ( $tblTag.$TagKey -contains $tagValue ) ) {
            # Tag value NOT an exact match
            $Output."ExitCode" = 1
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
