<#
.SYNOPSIS
    Searches for a specific text string inside files within a directory tree.

.DESCRIPTION
    This script recursively searches for files containing a specific string.
    It returns the file paths of the matches. It uses case-sensitive search.

.PARAMETER SearchTerm
    The string you want to find inside the files. (Required)

.PARAMETER Path
    The root directory to start the search. Defaults to the current directory (.).

.PARAMETER Filter
    File extension filter (e.g., "*.mqh", "*.mq4"). Defaults to "*" (all files).

.EXAMPLE
    # Run from script file:
    .\FindString.ps1 -SearchTerm "ATR_Calculator.mqh"

.EXAMPLE
    # Search only in specific file types:
    .\FindString.ps1 -SearchTerm "ATR_Calculator.mqh" -Filter "*.mq*"

.EXAMPLE
    # One-liner command (without saving this script):
    Get-ChildItem -Recurse -Filter *.mq* | Select-String -Pattern "ATR_Calculator.mqh" -CaseSensitive -List | Select-Object Path
#>

param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SearchTerm,

    [string]$Path = ".",

    [string]$Filter = "*"
)

# Visual feedback for the user
Write-Host "Searching for: '$SearchTerm' (Case Sensitive) in '$Path'..." -ForegroundColor Cyan

try {
    # Performing the search
    # -List: Stop after first match in a file (performance optimization)
    # -CaseSensitive: Matches exact casing only
    # Note: Variable name changed to avoid conflict with automatic variable $matches
    $searchResults = Get-ChildItem -Path $Path -Recurse -Filter $Filter -File -ErrorAction SilentlyContinue |
    Select-String -Pattern $SearchTerm -CaseSensitive -List

    if ($searchResults) {
        Write-Host "`nFound matches in the following files:" -ForegroundColor Green
        foreach ($item in $searchResults) {
            Write-Host $item.Path
        }
        Write-Host "`nTotal files found: $($searchResults.Count)" -ForegroundColor Gray
    } else {
        Write-Host "`nNo files found containing '$SearchTerm'." -ForegroundColor Yellow
    }
} catch {
    Write-Error "An error occurred: $_"
}
