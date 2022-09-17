function Open-EdgeSession {
    [CmdletBinding()]
    param (
        # Path where msedgedriver.exe binary is located, which is essential for the automation to work. Exe file acts as a bridge between WebDriver.dll
        # and the browser installed in operating system.
        [Parameter(Mandatory=$true,
                   Position=0,
                   ValueFromPipelineByPropertyName=$true)]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if ( Test-Path -Path  $_ ) 
                {
                    $true
                }
                else 
                {
                    throw "Invalid path provided"    
                }
            }
        )]
        [string]$BinaryPath,

        # Allows to connect to websites with invalid certificate without a warning page.
        [Parameter(HelpMessage="Whether to ignore invalid certificate.")]
        [Switch]$AcceptInsecureCertificates,

        # Hides default command prompt window created by Selenium.
        [Parameter(HelpMessage="Output of Selenium commands should ideally be hidden.")]
        [Switch]$HideCommandPromptWindow
    )
    
    begin 
    {      
        #Validate edge driver exist in the location provided
        $binaryLocation  = Join-Path -Path $BinaryPath -ChildPath 'msedgedriver.exe'
        if ( !( Test-Path -Path $binaryLocation) ) 
        {
            Write-Warning "Edge driver is not present in the location $binaryPath, trying to download latest compatible driver from internet"

            #Verfy correct binary is available for the browser
            $binaryStatus = Get-BrowserBinary -browser Edge

            #in case binary is not downloaded, exit the function. As without binary there can be not action to perform.
            if ( !$binaryStatus ) 
            {
                Exit
            }
        } 
    }
    
    process 
    {
        try 
        {
            #Set error action preference for within the try block
            $ErrorActionPreference = 'Stop'
            
            #Edge options to open new browser with customizations
            $seleniumOptions = New-Object OpenQA.Selenium.Edge.EdgeOptions
            if( $AcceptInsecureCertificates.IsPresent )
            {
                $seleniumOptions.AcceptInsecureCertificates = $true
            }

            $seleniumOptions.LeaveBrowserRunning = $true

            #Set browser homepage
            $seleniumOptions.AddArgument( "homepage=https://www.bing.com/" )

            #Create Edge driver service object to hide console output from selenium commands
            $defaultservice = [OpenQA.Selenium.Edge.EdgeDriverService]::CreateDefaultService( $binaryPath, 'msedgedriver.exe' )

            #hide command prompt
            if ( $HideCommandPromptWindow.IsPresent ) 
            {
                $defaultservice.HideCommandPromptWindow = $true
            }
                        
            #instantiating Edge executable for Selenium
            $Driver = New-Object OpenQA.Selenium.Edge.EdgeDriver  -ArgumentList  @($defaultservice, $seleniumOptions)

        }
        catch 
        {
            #store error in a variable
            $err = $_

            if( $err.Exception.InnerException.Message -like "session not created: This version of*" -and $err.Exception.InnerException.Source -eq 'WebDriver' )
            {
                #Verfy correct binary is available for the browser
                $binaryStatus = Get-BrowserBinary -browser Edge
            }
            else 
            {
                Write-Warning "Got error trying to open Edge browser $($err.Exception.Message)"    
            }
        }
        finally 
        {
            if ( $binaryStatus )  
            {
                $Driver = New-Object OpenQA.Selenium.Edge.EdgeDriver  -ArgumentList  @($defaultservice, $seleniumOptions) 
            }
            
            #Set error action preference back to normal
            $ErrorActionPreference = 'Continue'
        }
    }

    end 
    {
        if ( $Driver ) 
        {
            Write-Output $Driver
        }
    }
}