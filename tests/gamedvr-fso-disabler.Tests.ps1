BeforeDiscovery {
    $script:valueCases = @(
        @{ Label = 'DWORD 0'; Value = [int]0; Expect = 'dword:00000000' }
        @{ Label = 'DWORD -1 as eight hex digits'; Value = [int]-1; Expect = 'dword:ffffffff' }
        @{ Label = 'QWORD 1 as hex(b)'; Value = [long]1; Expect = 'hex(b):01,00,00,00,00,00,00,00' }
        @{ Label = 'binary 01 ab'; Value = [byte[]](1, 171); Expect = 'hex:01,ab' }
        @{ Label = 'string with a backslash and quotes'; Value = 'C:\a "b"'; Expect = '"C:\\a \"b\""' }
    )
    $script:pathCases = @(
        @{ Path = 'HKCU:\System\GameConfigStore'; Expect = 'HKEY_CURRENT_USER\System\GameConfigStore' }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Expect = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\GameDVR' }
        @{ Path = 'Registry::HKEY_USERS\S-1-5-21-1-2-3-1001\System\GameConfigStore'; Expect = 'HKEY_USERS\S-1-5-21-1-2-3-1001\System\GameConfigStore' }
    )
    $script:rerunCases = @(
        @{ Status = $true; Expect = 'Status=True' }
        @{ Status = $false; Expect = 'Status=False' }
    )
}

BeforeAll {
    $script:scriptPath = Join-Path $PSScriptRoot '..\gamedvr-fso-disabler.ps1'
    $script:scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)

    function Find-ScriptNode([scriptblock]$Predicate) {
        $scriptAst.Find($Predicate, $true)
    }
}

Describe 'PSScriptInfo version placeholder' {
    It 'is exactly .VERSION 0.0.0, the line release.yml stamps' {
        $lines = @(Select-String -LiteralPath $scriptPath -Pattern '^\.VERSION\b' | ForEach-Object Line)
        $lines.Count | Should -Be 1
        $lines[0] | Should -BeExactly '.VERSION 0.0.0'
    }
}

Describe 'the irm | iex rerun forwards -Status to powershell.exe -File' {
    It 'binds -Status in the rerun only when it was given (<Expect>)' -ForEach $rerunCases {
        $bootstrap = Find-ScriptNode { param($n) $n -is [System.Management.Automation.Language.IfStatementAst] -and $n.Clauses[0].Item1.Extent.Text -eq '-not $PSCommandPath' }
        $rerun = @($bootstrap.Clauses[0].Item2.Statements | Where-Object { $_.Extent.Text -match '^(\$fwd\s*=|powershell\s)' })
        $rerun.Count | Should -Be 2
        $stub = Join-Path $TestDrive 'rerun-stub.ps1'
        Set-Content -LiteralPath $stub -Value 'param([switch]$Status) "Status=$Status"' -Encoding Ascii
        $code = @('param($Status, $saved)') + @($rerun | ForEach-Object { $_.Extent.Text })
        & ([scriptblock]::Create($code -join "`n")) $Status $stub | Should -Be $Expect
    }
}

Describe 'ConvertTo-RegValueText' {
    BeforeAll {
        $fn = Find-ScriptNode { param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'ConvertTo-RegValueText' }
        if (-not $fn) { throw 'gamedvr-fso-disabler.ps1 defines no ConvertTo-RegValueText' }
        . ([scriptblock]::Create($fn.Extent.Text))
    }

    It 'writes a <Label> as <Expect>' -ForEach $valueCases {
        ConvertTo-RegValueText $Value | Should -BeExactly $Expect
    }

    It 'refuses a type the .reg format cannot carry here instead of writing a wrong snapshot' {
        { ConvertTo-RegValueText ([double]1.5) } | Should -Throw '*cannot snapshot*'
    }
}

Describe 'ConvertTo-RawRegPath' {
    BeforeAll {
        $fn = Find-ScriptNode { param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'ConvertTo-RawRegPath' }
        if (-not $fn) { throw 'gamedvr-fso-disabler.ps1 defines no ConvertTo-RawRegPath' }
        . ([scriptblock]::Create($fn.Extent.Text))
    }

    It 'turns <Path> into <Expect>' -ForEach $pathCases {
        ConvertTo-RawRegPath $Path | Should -BeExactly $Expect
    }
}
