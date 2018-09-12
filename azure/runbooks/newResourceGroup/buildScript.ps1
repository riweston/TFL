## Set Azure subscription context
$azSubscriptionContextTest = (Get-AzureRmContext).Subscription.Name
switch ($azSubscriptionContextTest) {
    "Model Office"              { $runBookSub = "MO"        }
    "T&D Shared NonProd"        { $runBookSub = "NonProd"   }
    "T&D Shared Prod"           { $runBookSub = "Prod"      }
    "T&D Shared Dev"            { $runBookSub = "Dev"       }
    "Enterprise Management Hub" { $runBookSub = "EMHub"     }
    Default                     { $runBookSub = $null       }
}

## Script variables
# Constant vars
[string]$runBookName        = (Get-ChildItem -Path "*.ps1" -Exclude "buildScript.ps1").Name
[string]$runBookDisplayName = "Create New Resource Group"
[string]$runBookRG          = "TSO-NH-Automation-" + $runBookSub + "-rg"
[string]$runBookAA          = "TSO-NH-Automation-" + $runBookSub + "-acc"

## Test Azure subscription is valid
if (!($runBookSub -eq $null)) {
    ## Import runbook
    $ImportAzureRmAutomationRunbookParam = @{
        Path                    = $runBookName
        ResourceGroupName       = $runBookRG
        AutomationAccountName   = $runBookAA
        Type                    = 'PowerShell'
        Force                   = $true
    }
    Import-AzureRmAutomationRunbook @ImportAzureRmAutomationRunbookParam

    ## Publish runbook
    $PublishAzureRmAutomationRunbookParam = @{
        ResourceGroupName       = $runBookRG
        AutomationAccountName   = $runBookAA
        Name                    = $runBookName.Split(".")[0]
    }
    Publish-AzureRmAutomationRunbook @PublishAzureRmAutomationRunbookParam
}
else {
    Write-Error -Message "Azure subscription context not valid, exiting"
}