<#
install-rdg-cert.ps1

Downloads and installs the 
certificate of the given rdg

#>


# Parameters
Param(
[Parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
[string]$RDG
)


# Downloads the Certificate from a given 
# Web Site to the selected path
# Returns True if succeed of False if failed
Function Get-CertificateFromURL
{
    # Parameters
    Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$URL,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$DestFile,
    [Parameter(Mandatory=$false)]
    [switch]$Force=$false
    )

    $UrlPrefix='https://martinrdg001.westeurope.cloudapp.azure.com'

    # Check URL Parameter
    If ($URL.Length -le $url.Length) {
        $URL=($UrlPrefix+$URL)
    } else {
        If (-not (($url.Substring(1,$UrlPrefix.Length)) -like $UrlPrefix)) {
            $URL=($UrlPrefix+$URL)
        }
    }

    # Create Web Request
    $WebRequest=[Net.WebRequest]::Create($URL)

    # Retrieve Certificate
    Try { 
         $WebRequest.GetResponse() 
         } catch {}
    $Certificate = $WebRequest.ServicePoint.Certificate

    # Write Certificate to $DestFile
    $Certificate_Bytes=$Certificate.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    
    # Exit if File exists and Force switch is off
    If ((-not $Force) -and (Test-Path $DestFile)) {return $false}
    
    # Write retrieved certificate to $DestFile
    $retVal=Set-Content -value $Certificate_Bytes -encoding byte -path $DestFile -Force
    
    # Return True if file is properly written (compare byte arrays)
    Return (@(Compare-Object $Certificate_Bytes (Get-Content -Path $DestFile -Encoding Byte)).length -eq 0)

    } 


$CertFile=($env:TEMP+'\rdg.cer')

Write-Host "Retrieving RDG Certificate..." -ForegroundColor Green
If (Get-CertificateFromURL -URL $rdg -DestFile $CertFile) {
    # Certificate downloaded. Import to User's Trusted Root.
    Write-Host "Installing certificate into user's root" -ForegroundColor Green
    
    $Cert=new-object System.Security.Cryptography.X509Certificates.X509Certificate2
    $Cert.Import($CertFile)
    $CertStore=Get-Item "Cert:\CurrentUser\Root"
    $CertStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::MaxAllowed)
    $CertStore.Add($cert)
    $CertStore.Close
    # From Windows 8 --
    # Import-Certificate -CertStoreLocation cert:\CurrentUser\Root -FilePath ($cert_dst+$cert_name)
    # --

    sleep 2
    Write-Host "Cleaning up temporary files" -ForegroundColor Green
    Remove-Item -Path $CertFile -Force
    Write-Host ("Done!")   
     
} else {
    Write-Host ("Unable to retrieve certificate from "+$rdg+".") -ForegroundColor Red
}