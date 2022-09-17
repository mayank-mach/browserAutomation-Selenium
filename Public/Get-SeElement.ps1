function Get-SeElement {
    [Alias('Find-SeElement', 'SeElement')]
    param(
        #Specifies whether the selction text is to select by name, ID, Xpath etc
        [ValidateSet("CssSelector", "Name", "Id", "ClassName", "LinkText", "PartialLinkText", "TagName", "XPath")]
        [ByTransformAttribute()]
        [string]$By = "XPath",
        #Text to select on
        [Alias("CssSelector", "Name", "Id", "ClassName", "LinkText", "PartialLinkText", "TagName", "XPath")]
        [Parameter(Position = 1, Mandatory = $true)]
        [string]$Selection,
        #Specifies a time out
        [Parameter(Position = 2)]
        [Int]$Timeout = 0,
        #The driver or Element where the search should be performed.
        [Parameter(Position = 3, ValueFromPipeline = $true)]
        [Alias('Element', 'Driver')]
        $Target = $Global:SeDriver,

        [parameter(DontShow)]
        [Switch]$Wait

    )
      begin 
    {
        #Path where all binaries for the module are present
        $binaryPath = (Resolve-Path -Path "$PSScriptRoot\..\Binaries").Path

        #Verify WebDriverManager.dll exist in the module folder
        if( Test-Path -Path "$binaryPath\WebDriver.Support.dll" )
        {
            #Unblock all binaries incase they are getting blocked.
            Get-ChildItem $binaryPath -Recurse | Unblock-File

            #Import WebDriver DLL file, this file is essential for the selenium automation
            Import-Module "$binaryPath\WebDriver.Support.dll"
            Write-Verbose "WebDriver.Support.dll imported as module."            
        }
        else 
        {
            Write-Warning "WebDriver.dll binary is not available in the module. It is required to run Selenium browser automation."
            break
        }
    }
    process {
        #if one of the old parameter names was used and BY was NIT specified, look for
        # <cmd/alias name> [anything which doesn't mean end of command] -Param
        # capture Param and set it as the value for by
        $mi = $MyInvocation.InvocationName
        if (-not $PSBoundParameters.ContainsKey("By") -and
            ($MyInvocation.Line -match "$mi[^>\|;]*-(CssSelector|Name|Id|ClassName|LinkText|PartialLinkText|TagName|XPath)")) {
            $By = $Matches[1]
        }
        if ($wait -and $Timeout -eq 0) { $Timeout = 30 }

        if ($TimeOut -and $Target -is [OpenQA.Selenium.Remote.RemoteWebDriver]) {
            $TargetElement = [OpenQA.Selenium.By]::$By($Selection)
            $WebDriverWait = [OpenQA.Selenium.Support.UI.WebDriverWait]::new($Target, (New-TimeSpan -Seconds $Timeout))
            $WebDriverWait.Until(
                [System.Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]] { 
                    param($Target) 
                    Try { 
                        $Target.FindElements([OpenQA.Selenium.By]::$By($Selection))
                    } 
                    Catch { $null } 
                })
        }
        elseif ($Target -is [OpenQA.Selenium.Remote.RemoteWebElement] -or
            $Target -is [OpenQA.Selenium.Remote.RemoteWebDriver]) {
            if ($Timeout) { Write-Warning "Timeout does not apply when searching an Element" }
            $Target.FindElements([OpenQA.Selenium.By]::$By($Selection))
        }
        else { throw "No valid target was provided." }
    }
}
