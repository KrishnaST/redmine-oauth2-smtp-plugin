param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\dist')
)

$ErrorActionPreference = 'Stop'
$pluginRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$archive = Join-Path $OutputDirectory 'redmine_microsoft365_smtp-2.0.1.zip'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archiveStream = [System.IO.File]::Create($archive)
$zipArchive = [System.IO.Compression.ZipArchive]::new($archiveStream, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $includedNames = @('app', 'config', 'documentation', 'lib', 'test', 'tools', 'init.rb', 'README.md', '.gitignore')
    foreach ($includedName in $includedNames) {
        $includedPath = Join-Path $pluginRoot $includedName
        $includedItem = Get-Item -LiteralPath $includedPath -Force
        $files = if ($includedItem.PSIsContainer) { Get-ChildItem -LiteralPath $includedPath -File -Recurse -Force } else { @($includedItem) }
        foreach ($file in $files) {
            $relativePath = $file.FullName.Substring($pluginRoot.Length + 1).Replace('\', '/')
            $entryName = 'redmine_microsoft365_smtp/' + $relativePath
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $file.FullName, $entryName, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    }
} finally {
    $zipArchive.Dispose()
    $archiveStream.Dispose()
}
Get-FileHash -Algorithm SHA256 -LiteralPath $archive
