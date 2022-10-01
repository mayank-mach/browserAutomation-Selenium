function Get-BrowserBinary {
    [CmdletBinding()]
    param (
        # Browser for which the executable is to be downloaded.
        [Parameter(Mandatory,
                   HelpMessage="Browser to use to connect to vCenter.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Chrome','Edge')]
        [String]$browser
    )
    
    begin 
    {
        #Path where all binaries for the module are present
        $binaryPath = (Resolve-Path -Path "$PSScriptRoot\..\Binaries").Path

        #Verify WebDriverManager.dll exist in the module folder
        if( !( Test-Path -Path "$binaryPath\WebDriverManager.dll" ) )
        {
            Write-Warning "WebDriverManager.dll binary is not available in the module. It is required to download the correct binary file."
            break
        }
        else 
        {
            Import-Module "$binaryPath\WebDriverManager.dll"

            #Create Driver manager object to download the binary
            $driverManager = New-Object -TypeName WebDriverManager.DriverManager
        }
    }
    
    process 
    {
        #Output variable 
        [bool]$correctBinary = $false

        if ($browser -eq 'Chrome') 
        {
            #Create browser config object to get current browser details and compare with the binaries
            $browserConfig = New-Object -TypeName WebDriverManager.DriverConfigs.Impl.ChromeConfig
        }
        elseif ($browser -eq "Edge")
        {
            #Create browser config object to get current browser details and compare with the binaries
            $browserConfig = New-Object -TypeName WebDriverManager.DriverConfigs.Impl.EdgeConfig
        }

        try 
        {
            #Set error action preference within try catch block
            $ErrorActionPreference = 'Stop'

            #Get latest supported binary version based on installed browser version
            $version = $browserConfig.GetMatchingBrowserVersion()
        }
        catch 
        {
            if ( $_.Exception.InnerException.Message -like "*Unable to connect to the remote server*" ) 
            {
                Write-Warning "Failed to connect to web repository for the binary, check internet connection and try again."    
            }    
        }
        finally 
        {
            #Set error action preference back to standard setting
            $ErrorActionPreference = 'Continue'
        }

        if ( $version ) 
        {
            #Get browser and binary details from browser config
            $browserName = $browserConfig.GetName()
            $binaryName  = $browserConfig.GetBinaryName()

            #Get OS architecture
            $arch = [WebDriverManager.Helpers.ArchitectureHelper]::GetArchitecture()

            #Get download URL based on architecture type
            if ( $arch -like "*64*") 
            {
                $baseURL = $browserConfig.GetUrl64()
            }
            elseif ( $arch -like "*32*") 
            {
                $baseURL = $browserConfig.GetUrl32()
            }

            #Create download URL
            $url = [WebDriverManager.Helpers.UrlHelper]::BuildUrl( $baseURL, $version)
            Write-Verbose "$url will be used to download the binary."

            #Create download path
            $downloadPath = [WebDriverManager.Helpers.FileHelper]::GetBinDestination( $browserConfig.GetName(), $browserVersion, $arch, $browserConfig.GetBinaryName() )
            Write-Verbose "Binary file will be downloaded to $downloadPath"

            #Download browser Binary
            $downloadPath = $driverManager.SetUpDriver( $url, $downloadPath )
            Write-Host $downloadPath -ForegroundColor Green

            if ( Test-Path -Path $downloadPath -ErrorAction SilentlyContinue ) 
            {
                Write-Host "$browser binaries downloaded successfully." -ForegroundColor Green

                #find and kill process running for that binary
                $processName =  $binaryName.Split( '.' )[0]
                Get-Process -Name $processName -ErrorAction SilentlyContinue | Where-Object{ $_.Path -eq "$binaryPath\$binaryName"} | Stop-Process -Force -Confirm:$false

                #Move downloaded binary to module
                $sb = [scriptblock]::Create( "Copy-Item -Path `'$downloadPath`' -Destination `'$binaryPath`' -Force" )
                $argList = "-NonInteractive -NoProfile -WindowStyle 'Hidden' -Command `"& { $sb }`""
                Start-Process PowerShell.exe -Verb RunAs -ArgumentList $argList
                
                #Delete the folder where binery was downloaded
                $pathToDelete = "$HOME\$browserName"

                #Remove-Item -Path $pathToDelete -Force -Recurse -Confirm:$false 
                #Write-Host "Clean-up complete" -ForegroundColor Green

                $binaryStatus = $true
            }
            else 
            {
                Write-Warning "Failed to download $browser binaries."
            }       
        }         
    }
    
    end 
    {
        Write-Output $binaryStatus
    }
}