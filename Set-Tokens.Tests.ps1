Describe 'Smoke Tests' {
    It 'passes empty params' {
        .\Set-Tokens | Should -Not -BeNullOrEmpty
    }
    It 'passes file copy' {
        .\Set-Tokens "$PSScriptRoot\tests\smoke\test\test.json" "tests\smoke\test-copy-file\test-new.json" -Verbose | Should -Not -BeNullOrEmpty
        $results = (Get-Content "tests\smoke\test-copy-file\test-new.json")
        $results | Should -Not -BeLike '*$(subscription)*'
    }
    It 'passes file update' {
        $source = "$PSScriptRoot\tests\smoke\test-update-file\test.json"
        if (-not (Test-Path "$PSScriptRoot\tests\smoke\test-update-file")) { New-Item -Path "$PSScriptRoot\tests\smoke\test-update-file" -ItemType Directory | Out-Null}
        Copy-Item $source.replace('test-update-file','test') $source -Force
        .\Set-Tokens $source -Verbose| Should -Not -BeNullOrEmpty
        $? | Should -Be $true
        #Get-Item $source | Where-Object { $_.LastWriteTime -lt ($(Get-Date).AddMinutes(-1)) } | ForEach-Object { "Name:" + $_.Name}
        $results = (Get-Content $source)
        $results | Should -Not -BeLike '*$(subscription)*'
    }
    It 'passes folder copy' {
        .\Set-Tokens "$PSScriptRoot\tests\smoke\test" "tests\smoke\test-copy-folder" -Verbose| Should -Not -BeNullOrEmpty
        $? | Should -Be $true
        $results = (Get-Content "tests\smoke\test-copy-folder\test.json")
        $results | Should -Not -BeLike '*$(subscription)*'
    }
    It 'passes folder update' {
        Copy-Item "$PSScriptRoot\tests\smoke\test" -Destination "$PSScriptRoot\tests\smoke\test-update-folder" -Force -Recurse
        .\Set-Tokens "tests\smoke\test-update-folder" -Verbose| Should -Not -BeNullOrEmpty
        $? | Should -Be $true
        $results = (Get-Content "tests\smoke\test-update-folder\test.json")
        $results | Should -Not -BeLike '*$(subscription)*'
    }
}