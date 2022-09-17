if ('ByTransformAttribute' -as [type])
{
    #Allow BY to shorten cssSelector, ClassName, LinkText, and TagName
    class ByTransformAttribute : System.Management.Automation.ArgumentTransformationAttribute  {
        [object] Transform([System.Management.Automation.EngineIntrinsics]$EngineIntrinsics, [object] $InputData) {
            if ($inputData -match 'CssSelector|Name|Id|ClassName|LinkText|PartialLinkText|TagName|XPath') {
                return $InputData
            }
            switch -regex ($InputData) {
                "^css"    {return 'CssSelector'; break}
                "^class"  {return 'ClassName'  ; break}
                "^link"   {return 'LinkText'   ; break}
                "^tag"    {return 'TagName'    ; break}
            }
            return $InputData
        }
    }

    class ByTransform : ByTransformAttribute {}
}