<#
.SYNOPSIS
    Optimizes MetaTrader 5 template files (.tpl) by removing static objects.

.DESCRIPTION
    When saving a template in MT5, all graphical objects (arrows, lines, boxes) are saved into the file.
    This script removes all <object>...</object> blocks to reduce file size and prevent "ghost" objects.
    It also compacts excessive empty lines while preserving readability.

    The script creates a new file with the '_mod.tpl' suffix for safety.

.PARAMETER Path
    The file path(s) or folder path(s) to process.
    Default is ".\MyTemplates".
    Accepts multiple values (comma-separated).

.EXAMPLE
    .\Clean-MT5Templates.ps1
    Processes all .tpl files in the .\MyTemplates folder.

.EXAMPLE
    .\Clean-MT5Templates.ps1 -Path "C:\MT5\Profiles\Templates\Strategy.tpl"
    Processes a single file.

.EXAMPLE
    .\Clean-MT5Templates.ps1 -Path "C:\Templates", "D:\Backup\Old.tpl"
    Processes a folder and a specific file.
#>

param (
    [string[]]$Path = @(".\MyTemplates")
)

function Remove-TplObjects {
    param ([string]$FilePath)

    try {
        # Read all text
        $content = [System.IO.File]::ReadAllText($FilePath)

        # 1. Remove <object> blocks
        # (?s) = Singleline mode (dot matches newline)
        $patternObj = "(?s)<object>.*?</object>"
        $cleanContent = [System.Text.RegularExpressions.Regex]::Replace($content, $patternObj, "")

        # 2. Compact Empty Lines (Preserve single empty lines)
        # Replace 3 or more newlines with 2 newlines
        $patternEmpty = "(\r?\n){3,}"
        $replacement = "`r`n`r`n"
        $cleanContent = [System.Text.RegularExpressions.Regex]::Replace($cleanContent, $patternEmpty, $replacement)

        if ($content.Length -ne $cleanContent.Length) {
            # Create new filename (_mod.tpl)
            $dir = Split-Path $FilePath -Parent
            $name = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
            $ext = [System.IO.Path]::GetExtension($FilePath)
            $newPath = Join-Path $dir "$($name)_mod$ext"

            # Write back
            [System.IO.File]::WriteAllText($newPath, $cleanContent)

            # Calculate stats
            $diffLen = $content.Length - $cleanContent.Length
            Write-Host "Created: $(Split-Path $newPath -Leaf) (Reduced by $diffLen bytes)" -ForegroundColor Green
        } else {
            Write-Host "Skipped: $(Split-Path $FilePath -Leaf) (Clean)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Error processing $FilePath : $_" -ForegroundColor Red
    }
}

foreach ($p in $Path) {
    if (Test-Path $p -PathType Container) {
        Write-Host "Processing folder: $p" -ForegroundColor Cyan
        $files = Get-ChildItem -Path $p -Filter "*.tpl" -Recurse
        foreach ($file in $files) {
            if ($file.Name -notlike "*_mod.tpl") {
                Remove-TplObjects -FilePath $file.FullName
            }
        }
    } elseif (Test-Path $p -PathType Leaf) {
        if ($p.EndsWith(".tpl") -and $p -notlike "*_mod.tpl") {
            Remove-TplObjects -FilePath $p
        }
    } else {
        Write-Host "Path not found: $p" -ForegroundColor Red
    }
}
Write-Host "Done." -ForegroundColor Cyan
