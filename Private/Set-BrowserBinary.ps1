function Set-BrowserBinary {
    [CmdletBinding()]
    param (
        # Browser for which the executable is to be downloaded.
        [Parameter(Mandatory,
                   HelpMessage="Browser to use to connect to vCenter.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Chrome','Edge')]
        [String]$browser,

        # Specifies a path to one or more locations.
        [Parameter(HelpMessage="Selenium driver object specific to each browser.")]
        $Target
    )
    
    begin {
        #Path where all binaries for the module are present
        $binaryPath = (Resolve-Path -Path "$PSScriptRoot\..\Binaries" -ErrorAction SilentlyContinue).Path

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

        #Output variable of type boolean
        [bool]$binaryConfigured = $false
    }
    
    process 
    {
        if ($browser -eq 'Chrome') 
        {
            #Create browser config object to get current browser details and compare with the binaries
            $browserConfig = New-Object -TypeName WebDriverManager.DriverConfigs.Impl.ChromeConfig

            if( $Target )
            {
                if( $Target.Capabilities.BrowserName -eq $browser )
                {
                    #Get current binary version
                    $currentBinaryVersion = $Target.Capabilities['chrome']['chromedriverVersion'].Split(' ')[0]
                }
                else
                {
                    Write-Warning "Target and browser mismatch, make sure to select target and Browser parameter input for same web browser"
                }
            }
        }
        elseif ($browser -eq "Edge")
        {
            #Create browser config object to get current browser details and compare with the binaries
            $browserConfig = New-Object -TypeName WebDriverManager.DriverConfigs.Impl.EdgeConfig

            if( $Target )
            {
                if( $Target.Capabilities.BrowserName -eq $browser )
                {
                    #Get current binary version
                    $currentBinaryVersion = $Target.Capabilities['msedge']['msedgedriverVersion'].Split(' ')[0]
                }
                else
                {
                    Write-Warning "Target and browser mismatch, make sure to select target and Browser parameter input for same web browser"
                }
            }
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
                Write-Warning "Failed to get correct browser binary version, check internet connection and try again."    
            }    
        }
        finally 
        {
            #Set error action preference back to standard setting
            $ErrorActionPreference = 'Continue'
        }

        if ( $version )
        {
            if ( $version -eq $currentBinaryVersion)
            {
                Write-Verbose "Validated: Browser binary is compatible with the browser version"

                #Output status set, if correct binary is already configured
                $binaryConfigured = $true
            }
            else
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
                $downloadPath = [WebDriverManager.Helpers.FileHelper]::GetBinDestination( $browserConfig.GetName(), $version, $arch, $browserConfig.GetBinaryName() )
                Write-Verbose "Binary file will be downloaded to $downloadPath"

                #Download browser Binary
                $downloadPath = $driverManager.SetUpDriver( $url, $downloadPath )

                if ( Test-Path -Path $downloadPath -ErrorAction SilentlyContinue ) 
                {
                    Write-Host "$browser binaries downloaded successfully." -ForegroundColor Green

                    #find and kill process running for that binary
                    $processName =  $binaryName.Split( '.' )[0]
                    Get-Process -Name $processName -ErrorAction SilentlyContinue | Where-Object{ $_.Path -eq "$binaryPath\$binaryName"} | 
                        Stop-Process -Force -Confirm:$false

                    #Move downloaded binary to module
                    $sb = [scriptblock]::Create( "Copy-Item -Path `'$downloadPath`' -Destination `'$binaryPath`' -Force" )
                    $argList = "-NoProfile -Command `"& { $sb }`""
                    Start-Process PowerShell.exe -Verb RunAs -ArgumentList $argList -Wait
                    
                    #Validate file copy
                    $downloadFile = Join-Path -Path $binaryPath -ChildPath $($browserConfig.GetBinaryName())
                    if( (Test-Path $downloadFile -ErrorAction SilentlyContinue) -and 
                        ((Get-FileHash -Path $downloadPath).hash -eq (Get-FileHash -Path $downloadFile).hash) )
                    {
                        #Delete the folder where binery was downloaded
                        $pathToDelete = "$HOME\$browserName"

                        #Remove-Item -Path $pathToDelete -Force -Recurse -Confirm:$false 
                        Write-Host "Clean-up complete" -ForegroundColor Green

                        #Output status set, if correct binary is already configured
                        $binaryConfigured = $true
                    }
                    else
                    {
                        Write-Warning "Failed to move file $($browserConfig.GetBinaryName()) from $downloadPath to $binaryPath."
                        Write-Warning "Proceed with this action manually and retry the command."
                    }
                }
                else
                {
                    Write-Warning "Failed to dowload binary file from URL $url, manually download the file and move it to $binaryPath."
                }

            }
        }
    }
    
    end {
        Write-Output $binaryConfigured
    }
}