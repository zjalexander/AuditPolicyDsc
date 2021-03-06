
Import-Module $PSScriptRoot\..\Helper.psm1 -Verbose:0

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $CsvPath,

        [parameter()]
        [System.Boolean]
        $force = $false,

        [ValidateSet("Present","Absent")]
        [string]$Ensure = "Present"
    )

    if(! (Test-Path "c:\Temp\"))
    {
        New-Item -ItemType Directory -path "c:\temp\"
    }
    
    #Question: Better way to create a temp file in SYSTEM context?
    $tempFile = "C:\Temp\test.CSV"
    
    $returnValue = @{}
    $returnValue.CSVPath = $tempFile
    $returnValue.Force = $force
    $returnValue.Ensure = "Absent"

    # Get-TargetResource should return CURRENT state of settings.
    # Good precedent in xAdUser xTimeZone, and many others.
    try
    {
        Invoke-SecurityCmdlet -Action "Export" -Path $tempFile
    }
    catch
    {
        Write-Verbose ($localizedData.ExportFailed -f $tempFile)
    }

    $csv = Import-CSV $tempFile
    if (($csv | ?{($_."Inclusion Setting" -notmatch "No Auditing") -and ($_."Inclusion Setting" -ne "")}).Count -gt 0)
    {
        $returnValue.Ensure = "Present"
    }

    return $returnValue
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $CsvPath,

        [parameter()]
        [System.Boolean]
        $force = $false,

        [ValidateSet("Present","Absent")]
        [string]$Ensure = "Present"
    )

    if(Test-Path $CsvPath)
    {
        
        #clear existing policy!!
        Write-Verbose "Start Set" 
        try
        {
            if ($Ensure -eq "Present")
            {
                if (!$Force)
                {
                    Invoke-SecurityCmdlet -Action "Import" -Path $CsvPath | Out-Null
                    Write-Verbose "Set Success"
                }
                else
                {
                    # Need to import settings, null them out and reset.
                }
            }
            else
            {
                # If Ensure is Absent, suggest clearing out Audit Policy.
                # Cannot do ensure separately on every settings without serious re-working, so this is the next logical move.
            }
        }
        catch
        {
            Write-Verbse "Set Fail" 
            Write-Verbose ($localizedData.ImportFailed -f $CsvPath)
        }
    }
    else
    {
        Write-Verbose ($localizedData.FileNotFound -f $CsvPath)
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $CsvPath,

        [parameter()]
        [System.Boolean]
        $force = $false, 

        [ValidateSet("Present","Absent")]
        [string]$Ensure = "Present"
    )

    if(Test-Path $CsvPath)
    {
        $result = Get-TargetResource @PSBoundParameters
        # Good Precedent here for using Get-TargetResource within other Blocks.$result = Get-TargetResource
        $tempFile = $result.CSVPath

        #Ignore "Machine Name" since it will cause a failure if your CSV was generated on a different machine

        #compare GUIDs and values to see if they are the same
        #options have no GUIDs, just object names...

        #clearing settings just writes "0"s on top, so lets discard those from consideration

        $ActualSettings  =  import-csv $tempFile | ? { $_."Setting Value" -ne 0 -and $_."Setting Value" -ne ""} | Select-Object -Property "Subcategory GUID", "Setting Value"
        $DesiredSettings =  import-csv $CsvPath  | ? { $_."Setting Value" -ne 0 -and $_."Setting Value" -ne ""} | Select-Object -Property "Subcategory GUID", "Setting Value"
        
        $result = Compare-Object $DesiredSettings $ActualSettings
        #only report items where selected items are present in desired state but NOT in actual state
        switch ($Ensure)
        {
            "Present" { 
                if (! ($result) )
                {
                    return $true
                }
                else
                {
                    #TODO: branch on $force
                    foreach ($entry in $result)
                    {
                        Write-Verbose ($localizedData.testCsvFailed -f $entry)
                    }
                    return $false
                }
            } 
            
            "Absent" { # Same question here on logic.  If "Absent" is set what should the results of the test be? 
            } 
        }
    }
    else
    {
        Write-Verbose ($localizedData.FileNotFound -f $CsvPath)
        return $false
    }
    #this shouldn't get reached, but it is getting reached. 
    return $false
}

Export-ModuleMember -Function *-TargetResource
