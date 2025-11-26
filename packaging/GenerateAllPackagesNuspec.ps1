param(
    [Parameter(Mandatory = $true)]
    [string]$FolderPath,
    [Parameter(Mandatory = $true)]
    [string]$CompanyName,
    [string]$iconUrl
)

Write (">FolderPath = " + $FolderPath)
Write (">CompanyName = " + $CompanyName)
Write (">iconUrl = " + $iconUrl)

$allPackagesPath = Join-Path $FolderPath "AllPackages.nuspec"
Remove-Item $allPackagesPath -Force -ErrorAction SilentlyContinue

# Collect all .nuspec files
$nuspecFiles = Get-ChildItem -Path $FolderPath -Filter *.nuspec -Recurse | Where-Object { $_.Name -ne 'Optional.nuspec' }

# Check if any nuspec file has 'il2cpp' in its name (case-insensitive)
$IL2CPP = $nuspecFiles | Where-Object { $_.Name -match 'il2cpp' } | Select-Object -First 1
$IL2CPP = $IL2CPP -ne $null

# Hashtable: targetFramework => list of dependencies
$frameworkDeps = @{}

foreach ($nuspec in $nuspecFiles) {
    [xml]$xml = Get-Content $nuspec.FullName

    # Get version
    $version = $xml.package.metadata.version
    if (-not $version) { continue }

    # Get targetFramework (from dependencies/group or fallback to empty)
    $group = $xml.package.metadata.dependencies.group | Select-Object -First 1
    $targetFramework = $group.targetFramework
    if (-not $targetFramework) { $targetFramework = ".NETFramework4.6" } # Default if missing

    # Compose dependency id
    $folderName = Split-Path $nuspec.DirectoryName -Leaf
    $nuspecName = [System.IO.Path]::GetFileNameWithoutExtension($nuspec.Name)
    $depId = "IllusionLibs.$folderName.$nuspecName"

    # Store dependency
    if (-not $frameworkDeps.ContainsKey($targetFramework)) {
        $frameworkDeps[$targetFramework] = @()
    }
    $frameworkDeps[$targetFramework] += @{ id = $depId; version = $version }
}

# Always add IllusionLibs.BepInEx to all frameworks
$frameworkKeys = @($frameworkDeps.Keys)
foreach ($fw in $frameworkKeys) {
    if ($IL2CPP) {
        $frameworkDeps[$fw] += @{ id = "BepInEx.KeyboardShortcut.IL2CPP"; version = "[18.3.0,)" }
        $frameworkDeps[$fw] += @{ id = "BepInEx.Unity.IL2CPP"; version = "[6.0.0-be.738,)" }
    }
    else {
        $frameworkDeps[$fw] += @{ id = "IllusionLibs.BepInEx"; version = "[5.4.22,)" }
    }
}

# Build XML
$xmlContent = @()
$xmlContent += '<?xml version="1.0"?>'
$xmlContent += '<package xmlns="http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd">'
$xmlContent += '  <metadata>'
$xmlContent += '    <id>$id$</id>'
$xmlContent += '    <version>$gameVersion$</version>'
$xmlContent += '    <description>All packages required to compile a plugin, no need to install any of them manually</description>'
$xmlContent += '    <authors>' + $CompanyName + '</authors>'
if ($iconUrl) {
    $xmlContent += "    <iconUrl>$iconUrl</iconUrl>"
}
$xmlContent += '    <dependencies>'

foreach ($fw in $frameworkDeps.Keys) {
    $xmlContent += "      <group targetFramework=""$fw"">"
    foreach ($dep in $frameworkDeps[$fw]) {
        $xmlContent += "        <dependency id=""$($dep.id)"" version=""$($dep.version)"" />"
    }
    $xmlContent += "      </group>"
}

$xmlContent += '    </dependencies>'
$xmlContent += '  </metadata>'
$xmlContent += '  <files>'
$xmlContent += '  </files>'
$xmlContent += '</package>'

# Write to AllPackages.nuspec
$xmlContent | Set-Content -Encoding UTF8 $allPackagesPath
Write-Host "AllPackages.nuspec created at $allPackagesPath"