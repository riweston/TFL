$serviceCatDefs = Get-ChildItem -Directory

foreach ($i in $serviceCatDefs) {
    Set-Location $i.Path
}