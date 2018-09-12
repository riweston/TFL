#Requires -modules AzureRM.Resources,AzureRM.profile,AzureRM.profile

#Get public and private function definition files.
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )
$Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )

#Dot source the files
Foreach($import in @($Private + $Public))
{
    Try
    {
        . $import.fullname
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

# Export Public functions ($Public.BaseName) for WIP modules
# Set variables visible to the module and its functions only

Export-ModuleMember -Function $Public.Basename