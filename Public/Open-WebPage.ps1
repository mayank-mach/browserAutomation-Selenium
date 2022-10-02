function Open-WebPage
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   Position=0        
        )]
        [uri]$URL,

        # Param2 help description
        [Parameter(Mandatory=$true,
                   Position=1        
        )]
        $Target
    )

    Begin
    {
    }
    Process
    {
        Write-Verbose "launching webpage $URL in selenium managed $($Target.Capabilities.BrowserName) browser"

        $Target.Navigate().GoToUrl($URL) 
    }
    End
    {
    }
}