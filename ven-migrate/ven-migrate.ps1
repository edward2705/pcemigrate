# Script       : ven-migrate.ps1
# Comments     : Script to re-activate and re-pair the ven
# Version      : 1.9
# Last Modified: 05-24

# Declare Variables
param([switch]$use_configfile, [string]$pce=$null, [string]$activation_code=$null, [string]$port="443", [string]$migrate_type=$null, [string]$proxy_server=$null, [string]$api_version="v25", [string]$profile_id=$null, [string]$vendir="C:\Program Files\Illumio")
$basedir = $PSScriptRoot
$scriptname = $myInvocation.MyCommand.Name
$wkldfile = "$basedir\workloads.csv"
$venctl = "$vendir\illumio-ven-ctl.ps1"
$configfile = "$basedir\ven-migrate.conf"
$migrate = @{activate='activate';pair='pair'}
$agent_state = $null

function Usage() {
    Write-Host
    Write-Host "Usage: $scriptname -use_configfile -pce PCE [-port PORT] -activation_code ACTIVATION_CODE [-proxy-server ip_address:port] -migrate_type [activate|pair] [ -api_version
    API_VERSION ] [ -profile_id PROFILE_ID ] [ -vendir VEN_DIRECTORY ]"
    Write-Host "Where:"
    Write-Host "  -use_configfile"
    Write-Host "   use ven-migrate.conf configuration file"
    Write-Host "  -pce PCE"
    Write-Host "  -port PCE Port, default: 443 [optional]"
    Write-Host "  -activation_code ACTIVATION_CODE"
    Write-Host "  -proxy_server ip_address:port"
    Write-Host "  -migrate_type [pair | activate]"
    Write-Host "  -api_version API_VERSION, default: v25 [required for migrate_type=pair ]" 
    Write-Host "  -profile_id PROFILE_ID [required for migrate_type=pair ]"
    Write-Host "  -vendir VEN Directory, default: c:\Program Files\Illumio [optional]"
    Write-Host  
}

function Debug-Print([string]$line) {
    $datetime = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    Write-Host ". $datetime $line"
  
}

function Check-VEN-Status() {
    #    $vendir/illumio-pce-ctl status
    Debug-Print
    Debug-Print "checking ven status"
    Debug-Print
    $venstatus = & "$venctl" status  

    foreach ( $line in $venstatus) {
        Debug-Print $line
        if ( $line.contains("Agent State") ) {
            $filler, $agent_state = $line.split(":")
        }
    }

    return $agent_state.trim()
    
}

function VEN-Deactivate() {   
    Debug-Print
    Debug-Print "deactivating ven"
    Debug-Print
    $venstatus = & "$venctl" deactivate  
    $venstatus
    Start-Sleep -Seconds 3
}

function VEN-Unpair() {   
    Debug-Print
    Debug-Print "unpairing ven"
    Debug-Print
    $venstatus = & "$venctl" unpair open noreport
    $venstatus
    Start-Sleep -Seconds 3
}

function VEN-Activate() {

    if ( Test-Path $wkldfile ) {
        $workload = Import-Csv $wkldfile | where { $_.hostname -eq $(hostname) }
    }

    if ( ![string]::IsNullOrEmpty($workload.role) ) {
        $role_param = "-role " + "'" + $workload.role + "'"
    }
    
    if ( ![string]::IsNullOrEmpty($workload.app) ) {
        $app_param = "-app " + "'" + $workload.app + "'"

    }
    
    if ( ![string]::IsNullOrEmpty($workload.env) ) {
        $env_param = "-env " + "'" + $workload.env + "'"
    }
    
    if ( ![string]::IsNullOrEmpty($workload.loc) ) {
        $loc_param = "-loc " + "'" + $workload.loc + "'"      
    }
    
    if ( ![string]::IsNullOrEmpty($workload.enforcement) ) {
        $enforcement_param = "-enforcement_mode " + "'" + $workload.enforcement + "'"
    }

    $mgmtserver = "$pce" + ":" + "$port"

    if ($migrate_type -eq $migrate.activate) {
        Debug-Print
        Debug-Print "starting ven activation"
        Debug-Print

        if ($proxy_server) {
            $ven_cmd = "& '$venctl' activate -management-server $mgmtserver -activation-code $activation_code -proxy-server $proxy_server $enforcement_param $role_param $app_param $env_param $loc_param"
        }
        else {
            $ven_cmd = "& '$venctl' activate -management-server $mgmtserver -activation-code $activation_code $enforcement_param $role_param $app_param $env_param $loc_param"
        }

        
        Debug-Print "$ven_cmd"

        Powershell -Command "& { $ven_cmd }"

    }
    elseif ( $migrate_type -eq $migrate.pair ) {
        Debug-Print
        Debug-Print "starting ven pairing"
        Debug-Print
        

        $url = "https://$($mgmtserver)/api/$api_version/software/ven/image?pair_script=pair.ps1&profile_id=$profile_id"

        Debug-Print "$url"

        Debug-Print "Set-ExecutionPolicy -Scope process remotesigned -Force; Start-Sleep -s 3; 
            Set-Variable -Name ErrorActionPreference -Value SilentlyContinue; [System.Net.ServicePointManager]::SecurityProtocol=[Enum]::ToObject([System.Net.SecurityProtocolType], 3072); 
            Set-Variable -Name ErrorActionPreference -Value Continue; (New-Object System.Net.WebClient).DownloadFile('$url', (echo $env:windir\temp\pair.ps1))"
    
        Set-ExecutionPolicy -Scope process remotesigned -Force; Start-Sleep -s 3; 
        Set-Variable -Name ErrorActionPreference -Value SilentlyContinue; [System.Net.ServicePointManager]::SecurityProtocol=[Enum]::ToObject([System.Net.SecurityProtocolType], 3072); 
        Set-Variable -Name ErrorActionPreference -Value Continue; (New-Object System.Net.WebClient).DownloadFile($url, (echo $env:windir\temp\pair.ps1)); 

        if ($proxy_server) {
            $ven_cmd = "& $env:windir\temp\pair.ps1 -management-server $mgmtserver -activation-code -proxy-server $proxy_server $activation_code $enforcement_param $role_param $app_param $env_param $loc_param"
        }
        else {
            $ven_cmd = "& $env:windir\temp\pair.ps1 -management-server $mgmtserver -activation-code $activation_code $enforcement_param $role_param $app_param $env_param $loc_param"
        }



        Debug-Print "executing cmd: $ven_cmd"
        Debug-Print
    
        Powershell -Command "& {$ven_cmd}"
        
    }
}       


function Check-File-Exists([string] $file) {
    Debug-Print
    Debug-Print "checking file $file"    
    if ( Test-Path $file ) {
        Debug-Print "File $file found!"
        return 0
    }
    else {
       Debug-Print "File $file not found!"
       return 1
    }
}


### Main Program ###

if ( $use_configfile )  {
    $rc = Check-File-Exists "$configfile" 
    if  ($rc -eq 0 ) {
        $pcekey = @{}
        Get-Content $configfile | ForEach-Object {    
            if ( $_ -notmatch "^#.$" ){   
                $keys = $_.replace('"','') -split "="
                $pcekey += @{$keys[0] = $keys[1]}
            }
        }
        $pce = $pcekey.pce
        $port = $pcekey.port
        $activation_code = $pcekey.activation_code
        $api_version = $pcekey.api_version
        $profile_id = $pcekey.profile_id
        $migrate_type = $pcekey.migrate_type
        $proxy_server = $pcekey.proxy_server

        
        if ($migrate.ContainsKey($migrate_type)) {
            Debug-Print "pce: $pce, port: $port, activation_code: $activation_code"
            Debug-Print "migrate_type: $migrate_type, api_version: $api_version, profile_id: $profile_id"
        }
        else {
            Debug-Print "ERROR: migrate_type should be either activate or pair!"
            Usage
            Exit 1
        }
    }
}
elseif ( ([string]::IsNullOrEmpty($pce)) -or ([string]::IsNullOrEmpty($activation_code)) -or ( ! $migrate.ContainsKey($migrate_type)) ) {
    Usage
    exit 0
}
else {
    Debug-Print "pce: $pce, port: $port, activation_code: $activation_code"
    Debug-Print "migrate_type: $migrate_type, api_version: $api_version, profile_id: $profile_id"
}

$rc = Check-File-Exists $venctl
Debug-Print "RC: $rc"
if ( $rc -eq 0 ) {
    $agent_state = Check-VEN-Status

    if ($migrate_type -eq $migrate.activate ) {
        VEN-Deactivate
    }
    elseif ($migrate_type -eq $migrate.pair ) {
        VEN-Unpair
    }
}

VEN-Activate $migrate_type

Start-Sleep -Seconds 3


$rc = Check-File-Exists $venctl

if ( $rc -eq 0 ) {
    $agent_state = Check-VEN-Status
    if ( $agent_state -ne "unpaired") {
        Debug-Print "ven agent paired successfully"
        Write-Host
        exit 0
    }
    else {
        Debug-Print "ERROR: ven agent pairing FAILED!"
        Write-Host
        exit 1
    }
}
else {
    exit 1
}































