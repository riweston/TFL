## Script variables
# User vars
Param(
    [string]$appDefAuthKey          = "2da78375-9a22-4b4c-a5be-7dad7ee0fa6e:8e3af657-a8ff-443c-a75c-2fe8c4bcb635", # 8e3af657-a8ff-443c-a75c-2fe8c4bcb635 : Owner Role ID
    [string]$appDefDisplayName      = "TFL Web Windows VM on Domain",
    [string]$appDefDescription      = "Domain joined Virtual Machine"
)
# Constant vars
[string]$appDefName                 = (Get-Item -Path ".\").Name
[string]$serviceDefStorageRG        = "Managed-Service-Definitions"
[string]$appDefRegion               = "NorthEurope"
[string]$zipFile                    = $appDefName + ".zip"
[string]$storageName                = "tflmsdstorage"
[string]$storageContainerName       = "tflmsdcontainer"

## Create archive
$compressArchiveParam = @{
    Path            = ".\*.json"
    DestinationPath = $zipFile
    Force           = $true
}
Compress-Archive @compressArchiveParam

## Get storage context
$getAzureRmStorageAccountParam = @{
    ResourceGroupName   = $serviceDefStorageRG
    Name                = $storageName
}
$storageAccountContext = (Get-AzureRmStorageAccount @getAzureRmStorageAccountParam).Context

## Create stroage container
$GetAzureStorageContainer = @{
    Name        = $storageContainerName
    Context     = $storageAccountContext
}
if (!(Get-AzureStorageContainer @GetAzureStorageContainer)) {
    $newAzureStorageContainerParam = @{
        Name        = $storageContainerName
        Context     = $storageAccountContext
        Permission  = "blob"
    }
    New-AzureStorageContainer @newAzureStorageContainerParam
}

## Upload archive
$setAzureStorageBlobContentParam = @{
    File        = ".\$($zipFile)"
    Container   = $storageContainerName
    Blob        = $zipFile
    Context     = $storageAccountContext
    Force       = $true
}
Set-AzureStorageBlobContent @setAzureStorageBlobContentParam

## Get package Uri
$getAzureStorageBlobParam = @{
    Container   = $storageContainerName
    Blob        = $zipFile
    Context     = $storageAccountContext
}
$packageFileUri = Get-AzureStorageBlob @getAzureStorageBlobParam
$packageFileUri = $packageFileUri.ICloudBlob.StorageUri.PrimaryUri.AbsoluteUri

## Create a new service definition
$newAzureRmManagedApplicationDefinitionParam = @{
    Name                = $appDefName 
    Location            = $appDefRegion 
    ResourceGroupName   = $serviceDefStorageRG 
    LockLevel           = "None" 
    DisplayName         = $appDefDisplayName
    Description         = $appDefDescription
    Authorization       = $appDefAuthKey
    PackageFileUri      = $packageFileUri
}
New-AzureRmManagedApplicationDefinition @newAzureRmManagedApplicationDefinitionParam
