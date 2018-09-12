function Test-AzureLogin {
    $needLogin = $true
    try {
        $content = Get-AzureRmContext
        if ($content) {
            $needLogin = ([string]::IsNullOrEmpty($content.Account))
        } 
    } 
    catch {
        if ($_ -like "*Login-AzureRmAccount to login*") {
            $needLogin = $true
        } 
        else {
            throw
        }
    }
    if ($needLogin) {
        Login-AzureRmAccount | Out-Null
    }
}