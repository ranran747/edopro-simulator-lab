param(
    [Parameter(Mandatory)][string]$ProjectIgnis,
    [string]$CoreDirectory = '',
    [ValidateRange(1,10000)][int]$Seeds = 20
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$project = (Resolve-Path -LiteralPath $ProjectIgnis).Path
$scripts = Join-Path $project 'script'
if (-not (Test-Path -LiteralPath $scripts)) { $scripts = $project }
foreach ($name in 'constant.lua','utility.lua') {
    if (-not (Test-Path -LiteralPath (Join-Path $scripts $name))) {
        throw "Missing EDOPro shared script: $name"
    }
}
if (-not $CoreDirectory) {
    $build = Join-Path $root 'native/build'
    & cmake -S (Join-Path $root 'native') -B $build -G 'Visual Studio 17 2022' -A Win32
    if ($LASTEXITCODE -ne 0) { throw 'CMake configuration failed.' }
    & cmake --build $build --config Release --parallel 4
    if ($LASTEXITCODE -ne 0) { throw 'ocgcore build failed.' }
    $CoreDirectory = Join-Path $build 'Release'
}
$core = (Resolve-Path -LiteralPath $CoreDirectory).Path
if (-not (Test-Path -LiteralPath (Join-Path $core 'ocgcore.dll'))) { throw "ocgcore.dll is missing in $core" }
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe'
$artifacts = Join-Path $root 'artifacts'
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$runner = Join-Path $artifacts 'UnionArenaSmoke.exe'
& $compiler /nologo /target:exe /platform:x86 "/out:$runner" (Join-Path $PSScriptRoot 'UnionArenaSmoke.cs')
if ($LASTEXITCODE -ne 0) { throw 'Harness build failed.' }
& $runner $root $Seeds $core $scripts 'UnionArena_AI_vs_AI.lua'
if ($LASTEXITCODE -ne 0) { throw 'A match failed.' }
