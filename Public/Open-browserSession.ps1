
    function isURI($address) {
        ($address -as [System.URI]).AbsolutePath -ne $null
    }

    function isURIWeb($address) {
        $uri = $address -as [System.URI]
        $uri.AbsoluteURI -ne $null -and $uri.Scheme -match 'http|https'
    }

function Open-browserSession {
    [CmdletBinding()]
    param (
        # Browser which needs to be opened up for automation with Selenium. Paramter supports predefined list of browser
        # names to chose from.
        [Parameter(Position=0,
                   HelpMessage="Browser to use to connect to vCenter.")]
        [ValidateSet('Chrome','Edge')]
        [String]$browser = 'Chrome',

        # Allows to connect to websites with invalid certificate without a warning page.
        [Parameter(HelpMessage="Whether to ignore invalid certificate.")]
        [Switch]$AcceptInsecureCertificates,

        # Hides default command prompt window created by Selenium.
        [Parameter(HelpMessage="Output of Selenium commands should ideally be hidden.")]
        [Switch]$HideCommandPromptWindow,

        # Specifies the window size of the browser which to be opened as part of the request.
        [Parameter(HelpMessage="Window size for the browser.")]
        [ValidateSet('FullScreen','Maximize','Minimize')]
        [String]$WindowSize = 'Maximize'
    )
    
    begin 
    {
        #Path where all binaries for the module are present
        $binaryPath = (Resolve-Path -Path "$PSScriptRoot\..\Binaries").Path

        #Verify WebDriverManager.dll exist in the module folder
        if( Test-Path -Path "$binaryPath\WebDriver.dll" )
        {
            #Unblock all binaries incase they are getting blocked.
            Get-ChildItem $binaryPath -Recurse | Unblock-File

            #Import WebDriver DLL file, this file is essential for the selenium automation
            Import-Module "$binaryPath\WebDriver.dll"
            Write-Verbose "WebDriver.dll imported as module."            
        }
        else 
        {
            Write-Warning "WebDriver.dll binary is not available in the module. It is required to run Selenium browser automation."
            break
        }
    }
    
    process 
    {
        if( !$global:SeleniumDriverDefault )
        {
            #Create as global varialbe and set variable type to hash table
            $global:SeleniumDriverDefault = New-Object 'System.Collections.Generic.Dictionary[string,object]' 
        }

        if( !$global:SeleniumDriverDefault[$browser] -or !$SeleniumDriverDefault[$browser].WindowHandles )
        {
            #Remove unusable browser entries
            if( !$SeleniumDriverDefault[$browser].WindowHandles )
            {
                $null = $global:SeleniumDriverDefault.remove($browser)
            }

            #Common paramters used to create browser websession
            $commonParameters = New-Object "System.Collections.Generic.Dictionary[[String],[System.Object]]"

            if( $AcceptInsecureCertificates.IsPresent )
            {
                $commonParameters.Add('AcceptInsecureCertificates', $true)
            }

            if( $HideCommandPromptWindow.IsPresent )
            {
                $commonParameters.Add('HideCommandPromptWindow', $true)
            }

            if( $browser -eq 'Chrome' )
            {
                $Driver = Open-ChromeSession -BinaryPath $binaryPath @commonParameters
            }
            elseif ( $browser -eq 'Edge' ) 
            {
                $Driver = Open-EdgeSession -BinaryPath $binaryPath @commonParameters
            }

            #Set browser window size
            if ( $Driver ) 
            {
                switch ( $WindowSize ) 
                {
                    'FullScreen' 
                    {
                        $Driver.Manage().Window.FullScreen() 
                    }
                    'Maximize' 
                    {
                        $Driver.Manage().Window.Maximize() 
                    }
                    'Minimize' 
                    {
                        $Driver.Manage().Window.Minimize() 
                    }
                    Default 
                    {
                        $Driver.Manage().Window.Maximize() 
                    }
                }

                #Add the details to global variable for further use
                $null = $global:SeleniumDriverDefault.Add($browser, $Driver)
            }
        }
        else
        {
            $Driver = $global:SeleniumDriverDefault[$browser]
        }  
        
        #if user closed the latest tab in the browser window
        if ( !$global:SeleniumDriverDefault[$browser].CurrentWindowHandle ) 
        {
            #Get all available tabs in the browser window and select the last one
            $windowHandle = $global:SeleniumDriverDefault[$browser].WindowHandles|Select-Object -last 1
            
            #Switch to the selected window handle
            $null = $global:SeleniumDriverDefault[$browser].SwitchTo().window($windowHandle)
        }

        #if current active page is having proper URL string then new tab will be initiated, else same page will be used.
        if( $driver.Url -ne 'data:,' -and $driver.Url -ne 'about:blank' -and ( isURI($driver.Url) -or isURIWeb($driver.Url) ) )
        {
            #Create window type object and change its value to tab, default value is Window
            $windowType = New-Object OpenQA.Selenium.WindowType
            $windowType = 'Tab'

            #switch to new tab in browser
            $null = $Driver.SwitchTo().NewWindow($windowType)
        }
    }
    
    end 
    {
        if ( $Driver.WindowHandles.count -gt 0 ) 
        {
            Write-Output $Driver
        }
    }
}