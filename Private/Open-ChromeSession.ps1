function Open-ChromeSession {
    [CmdletBinding()]
    param (
        # Path where chromedriver.exe binary is located, which is essential for the automation to work. Exe file acts as a bridge between WebDriver.dll
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
        #Validate chrome driver exist in the location provided
        $binaryLocation  = Join-Path -Path $BinaryPath -ChildPath 'chromedriver.exe'
        if ( !( Test-Path -Path $binaryLocation) ) 
        {
            Write-Warning "Chrome driver is not present in the location $binaryPath, trying to download latest compatible driver from internet"

            #Verfy correct binary is available for the browser
            $binaryStatus = Set-BrowserBinary -browser Chrome

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

            #Chrome options to open new browser with customizations
            $seleniumOptions = New-Object OpenQA.Selenium.Chrome.ChromeOptions
            if( $AcceptInsecureCertificates.IsPresent )
            {
                $seleniumOptions.AcceptInsecureCertificates = $true
            }
            
            $seleniumOptions.LeaveBrowserRunning = $true

            #Set browser homepage
            $seleniumOptions.AddArgument( "homepage=https://www.google.co.in/" )

            #Create Chrome driver service object to hide console output from selenium commands
            $defaultservice = [OpenQA.Selenium.Chrome.ChromeDriverService]::CreateDefaultService($binaryPath, 'chromedriver.exe' ) 
            
            #hide command prompt
            if ( $HideCommandPromptWindow.IsPresent ) 
            {
                $defaultservice.HideCommandPromptWindow = $true
            }
            
            #instantiating Chrome executable for Selenium
            $Driver = New-Object OpenQA.Selenium.Chrome.ChromeDriver  -ArgumentList  @($defaultservice, $seleniumOptions)
        }
        catch 
        {
            #store error in a variable
            $err = $_
            
            if( $err.Exception.InnerException.Message -like "session not created: This version of*" -and $err.Exception.InnerException.Source -eq 'WebDriver' )
            {
                #Verfy correct binary is available for the browser
                $binaryStatus = Set-BrowserBinary -browser Chrome -Target $driver
            }
            else 
            {
                Write-Warning "Got error trying to open chrome browser $($err.Exception.Message)"    
            }
        }
        finally 
        {
            if ( $binaryStatus )  
            {
                #Create Chrome driver service object to hide console output from selenium commands
                $defaultservice = [OpenQA.Selenium.Chrome.ChromeDriverService]::CreateDefaultService($binaryPath, 'chromedriver.exe' ) 
                
                #hide command prompt
                if ( $HideCommandPromptWindow.IsPresent ) 
                {
                    $defaultservice.HideCommandPromptWindow = $true
                }

                $Driver = New-Object OpenQA.Selenium.Chrome.ChromeDriver  -ArgumentList  @($defaultservice, $seleniumOptions) 
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