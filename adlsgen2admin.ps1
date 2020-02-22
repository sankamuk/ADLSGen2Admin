function usage_error {

  Write-Host "Usage: adlsgen2admin.ps1 /a FILESYSTEM_ACTION /f FILESYSTEM_RESOURCEPATH [/l LOCAL_FILE] [/p PROXY_SERVER]"
  Write-Host "       FILESYSTEM_ACTION       -> Filesystem action to perform, supported LS, MKDIR, CAT, PUT, RM, RMDIR"
  Write-Host "       FILESYSTEM_RESOURCEPATH -> ADLS Resource detail, FORMAT: STORAGE_ACCOUNT/FILESYSTEM@PATH_IN_ADLS"
  Write-Host "       LOCAL_FILE (Optional)   -> Applicable only for PUT action, path of your local file to be PUT in ADLS"
  Write-Host "       PROXY_SERVER (Optional) -> Your proxy server if applicable, eg: http://127.0.0.1:3128"
  Write-Host ""
  Write-Host "NOTE: The tool uses SPN(OAuth) to authenticate, thus you need to export CLIENT_ID, CLIENT_SECRET and TENENT_ID in environment."
  exit 1

}

for ( $i = 0; $i -lt $args.count; $i++ ) {
  if ($args[ $i ] -eq "/a") { $action=$args[ $i+1 ] }
  if ($args[ $i ] -eq "/f") { $fullPath=$args[ $i+1 ] }
  if ($args[ $i ] -eq "/l") { $localFile=$args[ $i+1 ] }
  if ($args[ $i ] -eq "/p") { $isProxy=$args[ $i+1 ] }
}

$CLIENT_ID = $env:$CLIENT_ID
$CLIENT_SECRET = $env:$CLIENT_SECRET
$TENENT_ID = $env:$TENENT_ID

$adlsLocation,$storagePath = $fullPath.split('@')
$storageAccount,$storageFs = $adlsLocation.split('/')

if (! $CLIENT_ID) {
  Write-Host "ERROR: AAD Client Id not set in environment"
  usage_error
}

if (! $CLIENT_SECRET) {
  Write-Host "ERROR: AAD CLIENT Secret not set in environment"
  usage_error
}

if (! $TENENT_ID) {
  Write-Host "ERROR: AAD TENENT Id not set in environment"
  usage_error
}

if (! $storageAccount) {
  Write-Host "ERROR: FILESYSTEM_RESOURCEPATH not correctly set, cannot detect storage account"
  usage_error
}

if (! $storageFs) {
  Write-Host "ERROR: FILESYSTEM_RESOURCEPATH not correctly set, cannot detect storage account filesystem"
  usage_error
}

if (! $storagePath) {
  Write-Host "ERROR: FILESYSTEM_RESOURCEPATH not correctly set, cannot detect storage path"
  usage_error
}


if ( $isProxy ) {
  $proxy = New-Object System.Net.WebProxy
  $proxy.Address = [uri]$isProxy
  [System.Net.WebRequest]::DefaultWebProxy = $proxy
}

$curScope = 'https://storage.azure.com/.default'
$curResponse = Invoke-RestMethod "https://login.microsoftonline.com/$TENENT_ID/oauth2/v2.0/token" `
               -Method Post -ContentType "application/x-www-form-urlencoded" `
               -Body @{client_id=$CLIENT_ID; client_secret=$CLIENT_SECRET; 
               scope=$curScope; grant_type="client_credentials"} -ErrorAction STOP

$accessToken = $curResponse.access_token
$adlsUrl = "https://$storageAccount.dfs.core.windows.net/$storageFs"

if ( $action -eq "ls" ){
  $endPoint = "{0}?resource=filesystem&directory={1}&recursive=false" -f $adlsUrl, $storagePath
  $fileList = (Invoke-RestMethod -Uri "$endPoint" -Method GET -Headers @{"Authorization"="Bearer $accessToken"; "x-ms-version"="2018-11-09"})
  $fileList.paths
}

if ( $action -eq "mkdir" ){
  $endPoint = "{0}{1}?resource=directory" -f $adlsUrl, $storagePath
  Invoke-RestMethod -Uri "$endPoint" -Method PUT -Headers @{"Authorization"="Bearer $accessToken"; "x-ms-version"="2018-11-09"; "content-length"=0}

}

if ( $action -eq "cat" ){
  $endPoint = "{0}{1}" -f $adlsUrl, $storagePath
  Invoke-RestMethod -Uri "$endPoint" -Method GET -Headers @{"Authorization"="Bearer $accessToken"; "x-ms-version"="2018-11-09"}

}

if ( $action -eq "rm" ){
  $endPoint = "{0}{1}" -f $adlsUrl, $storagePath
  Invoke-RestMethod -Uri "$endPoint" -Method DELETE -Headers @{"Authorization"="Bearer $accessToken"; "x-ms-version"="2018-11-09"}
}

if ( $action -eq "rmdir" ){
  $endPoint = "{0}{1}?recursive=true" -f $adlsUrl, $storagePath
  Invoke-RestMethod -Uri "$endPoint" -Method DELETE -Headers @{"Authorization"="Bearer $accessToken"; "x-ms-version"="2018-11-09"}
}

if ( $action -eq "put" ){
  if (! $localFile) {
    Write-Host "ERROR: LOCAL_FILE not correctly set, provide absolute path if relative path not correct"
    usage_error
  }

  $content = [IO.File]::ReadAllText($localFile)
  $content_size = $content.Length
  $createEndpoint = "{0}{1}?resource=file" -f $adlsUrl, $storagePath
  $uploadEndpoint = "{0}{1}?action=append&position=0" -f $adlsUrl, $storagePath
  $flushEndpoint = "{0}{1}?action=flush&close=true&position={2}" -f $adlsUrl, $storagePath, $content_size

  Invoke-RestMethod -Uri "$createEndpoint" -Method PUT -Headers @{"Authorization"="Bearer $accessToken"; "x-ms-version"="2018-11-09"; "content-length"=0}

  Invoke-RestMethod -Uri "$uploadEndpoint" -Method PATCH -Body $content -Headers @{"Authorization"="Bearer $accessToken"; "x-ms-version"="2018-11-09"; "Content-Type": "text/plain"; "content-length"="$content_size"}

  Invoke-RestMethod -Uri "$endPoint" -Method PATCH -Headers @{"Authorization"="Bearer $accessToken"; "x-ms-version"="2018-11-09"; "Content-Type": "text/plain"; "content-length"=0}
}