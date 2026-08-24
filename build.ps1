[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('N4Editor_Debug', 'N4Editor_Release', 'N4Editor_RelWithDebInfo', 'all')]
    [string]$Target = 'N4Editor_Debug',
    [string]$EngineRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

$FBuildPath = 'FBuild.exe'

$MsvcInclude = ''
$MsvcLib = ''
$WindowsSdkInclude = ''
$WindowsSdkLib = ''
$WindowsSdkUcrtLib = ''

$EnableShaderCompilation = $false
$EnableVulkanValidation = $false
$VulkanSdkRoot = ''

function Resolve-Executable {
    param([string]$Name)

    if (Test-Path -LiteralPath $Name -PathType Leaf) {
        return [System.IO.Path]::GetFullPath($Name)
    }

    $command = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $command) {
        throw "Executable was not found on PATH: $Name"
    }

    $path = $command.Path
    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = $command.Source
    }

    return [System.IO.Path]::GetFullPath($path)
}

function Require-Directory {
    param(
        [string]$Name,
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Configure $Name at the top of build.ps1.'
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Container)) {
        throw ('Configured $Name does not exist: ' + $fullPath)
    }

    return $fullPath
}

function Require-File {
    param(
        [string]$Name,
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw ('Required ' + $Name + ' does not exist: ' + $Path)
    }

    return [System.IO.Path]::GetFullPath($Path)
}

function ConvertTo-BffPath {
    param([string]$Path)

    return (($Path -replace '\\', '/') -replace "'", "^'")
}

$engineRoot = Require-Directory 'EngineRoot' $EngineRoot
$buildSystemRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)

foreach ($directory in @('src', 'libs', 'schemas', 'shaders', 'tools')) {
    Require-Directory ("EngineRoot/" + $directory) (Join-Path $engineRoot $directory) | Out-Null
}

$fbuildExecutable = Resolve-Executable $FBuildPath
$clangCompiler = Resolve-Executable 'clang-cl.exe'
$clangLinker = Resolve-Executable 'lld-link.exe'
$clangLibrarian = Resolve-Executable 'llvm-lib.exe'
$pythonExecutable = Resolve-Executable 'python.exe'
$qtMoc = Resolve-Executable 'moc.exe'

$clangBin = Split-Path -Parent $clangCompiler
$qtBin = Split-Path -Parent $qtMoc
$qtRoot = Require-Directory 'QtRoot' (Split-Path -Parent $qtBin)

foreach ($directory in @('include', 'lib', 'plugins/platforms')) {
    Require-Directory ("QtRoot/" + $directory) (Join-Path $qtRoot $directory) | Out-Null
}

$MsvcInclude = Require-Directory 'MsvcInclude' $MsvcInclude
$MsvcLib = Require-Directory 'MsvcLib' $MsvcLib
$WindowsSdkInclude = Require-Directory 'WindowsSdkInclude' $WindowsSdkInclude
$WindowsSdkLib = Require-Directory 'WindowsSdkLib' $WindowsSdkLib
$WindowsSdkUcrtLib = Require-Directory 'WindowsSdkUcrtLib' $WindowsSdkUcrtLib

$llvmRoot = Split-Path -Parent $clangBin
$clangResourceRoot = Join-Path $llvmRoot 'lib/clang'
$asanResource = $null

if (Test-Path -LiteralPath $clangResourceRoot -PathType Container) {
    foreach ($versionDirectory in (Get-ChildItem -LiteralPath $clangResourceRoot -Directory | Sort-Object Name -Descending)) {
        $candidate = Join-Path $versionDirectory.FullName 'lib/windows'
        $runtime = Join-Path $candidate 'clang_rt.asan_dynamic-x86_64.lib'
        $thunk = Join-Path $candidate 'clang_rt.asan_dynamic_runtime_thunk-x86_64.lib'
        $dll = Join-Path $candidate 'clang_rt.asan_dynamic-x86_64.dll'

        if ((Test-Path -LiteralPath $runtime -PathType Leaf) -and (Test-Path -LiteralPath $thunk -PathType Leaf) -and (Test-Path -LiteralPath $dll -PathType Leaf)) {
            $asanResource = $candidate
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($asanResource)) {
    throw "LLVM AddressSanitizer runtime was not found relative to clang-cl.exe: $clangResourceRoot"
}

$vulkanRoot = ''
$glslangExecutable = 'glslangValidator.exe'

if ($EnableShaderCompilation -or $EnableVulkanValidation) {
    if ([string]::IsNullOrWhiteSpace($VulkanSdkRoot)) {
        $glslangFromPath = Resolve-Executable 'glslangValidator.exe'
        $vulkanRoot = Split-Path -Parent (Split-Path -Parent $glslangFromPath)
    }
    else {
        $vulkanRoot = Require-Directory 'VulkanSdkRoot' $VulkanSdkRoot
        $glslangFromPath = Join-Path $vulkanRoot 'Bin/glslangValidator.exe'
    }

    $glslangExecutable = Require-File 'glslangValidator.exe' $glslangFromPath
}

if ($EnableVulkanValidation) {
    Require-File 'Vulkan validation DLL' (Join-Path $vulkanRoot 'Bin/VkLayer_khronos_validation.dll') | Out-Null
    Require-File 'Vulkan validation JSON' (Join-Path $vulkanRoot 'Bin/VkLayer_khronos_validation.json') | Out-Null
}

$asanRuntime = Join-Path $asanResource 'clang_rt.asan_dynamic-x86_64.lib'
$asanThunk = Join-Path $asanResource 'clang_rt.asan_dynamic_runtime_thunk-x86_64.lib'
$asanDll = Join-Path $asanResource 'clang_rt.asan_dynamic-x86_64.dll'
$validationValue = if ($EnableVulkanValidation) { '1' } else { '0' }

$localBffPath = Join-Path $buildSystemRoot 'fbuild.local.bff'
$localBffLines = @(
    ".QtAsanPrefix = '$(ConvertTo-BffPath $qtRoot)'",
    ".QtStandardPrefix = '$(ConvertTo-BffPath $qtRoot)'",
    ".QtHostPrefix = '$(ConvertTo-BffPath $qtRoot)'",
    ".N4DCDebugQtRuntimePrefix = '$(ConvertTo-BffPath $qtRoot)'",
    ".N4DCReleaseQtRuntimePrefix = '$(ConvertTo-BffPath $qtRoot)'",
    ".N4DCRelWithDebInfoQtRuntimePrefix = '$(ConvertTo-BffPath $qtRoot)'",
    ".QtHostBin = '$(ConvertTo-BffPath $qtBin)'",
    ".ClangBin = '$(ConvertTo-BffPath $clangBin)'",
    ".ClangCompiler = '$(ConvertTo-BffPath $clangCompiler)'",
    ".ClangLinker = '$(ConvertTo-BffPath $clangLinker)'",
    ".ClangLibrarian = '$(ConvertTo-BffPath $clangLibrarian)'",
    ".Python = '$(ConvertTo-BffPath $pythonExecutable)'",
    ".VulkanSdk = '$(ConvertTo-BffPath $vulkanRoot)'",
    ".MsvcInclude = '$(ConvertTo-BffPath $MsvcInclude)'",
    ".MsvcLib = '$(ConvertTo-BffPath $MsvcLib)'",
    ".WindowsSdkInclude = '$(ConvertTo-BffPath $WindowsSdkInclude)'",
    ".WindowsSdkLib = '$(ConvertTo-BffPath $WindowsSdkLib)'",
    ".WindowsSdkUcrtLib = '$(ConvertTo-BffPath $WindowsSdkUcrtLib)'",
    ".AsanResource = '$(ConvertTo-BffPath $asanResource)'",
    ".AsanLinkerLib = '$(ConvertTo-BffPath $asanResource)'",
    ".AsanRuntime = '$(ConvertTo-BffPath $asanRuntime)'",
    ".AsanThunk = '$(ConvertTo-BffPath $asanThunk)'",
    ".AsanDll = '$(ConvertTo-BffPath $asanDll)'",
    ".Glslang = '$(ConvertTo-BffPath $glslangExecutable)'",
    ".N4DCEnableShaderCompilation = $($EnableShaderCompilation.ToString().ToLowerInvariant())",
    ".N4DCEnableVulkanValidation = $($EnableVulkanValidation.ToString().ToLowerInvariant())",
    ".N4DCVulkanValidationValue = '$validationValue'"
)

[System.IO.File]::WriteAllText(
    $localBffPath,
    (($localBffLines -join [Environment]::NewLine) + [Environment]::NewLine),
    [System.Text.UTF8Encoding]::new($false)
)

$bffPath = Join-Path $buildSystemRoot 'fbuild.bff'
$exitCode = 1

Push-Location $engineRoot
try {
    & $fbuildExecutable '-config' $bffPath '-continueafterdbmove' $Target
    $exitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

exit $exitCode
