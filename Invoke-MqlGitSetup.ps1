# PowerShell -ExecutionPolicy Bypass -File .\Invoke-MqlGitSetup.ps1
# PowerShell Script to initialize and download MQL5 Git repository with dynamic remote naming
$ErrorActionPreference = "Stop"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   MQL5 Git Repository Initializer & Downloader   " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Select the Remote Name from a predefined list
Write-Host "Select the remote repository alias:" -ForegroundColor Cyan
Write-Host "1) algoforge"
Write-Host "2) github"
Write-Host "3) gitlab"
Write-Host "4) Custom name (type your own)"
Write-Host ""

$choice = Read-Host "Enter your choice (1-4)"
$remoteName = ""

switch ($choice) {
    "1" { $remoteName = "algoforge" }
    "2" { $remoteName = "github" }
    "3" { $remoteName = "gitlab" }
    "4" {
        $remoteName = Read-Host "Enter custom remote alias"
        if ([string]::IsNullOrWhiteSpace($remoteName)) {
            Write-Error "Custom remote name cannot be empty! Script aborted."
            exit
        }
    }
    default {
        Write-Error "Invalid selection! Script aborted."
        exit
    }
}

# Clean up remote name (lowercase, no spaces)
$remoteName = $remoteName.ToLower().Trim()

# 2. Prompt user for remaining credentials
Write-Host ""
$repoUrl = Read-Host "Enter the remote Git repository URL"
$gitUser = Read-Host "Enter your Git username (e.g., John Doe)"
$gitEmail = Read-Host "Enter your Git email address (e.g., john.doe@example.com)"

if ([string]::IsNullOrWhiteSpace($gitUser) -or [string]::IsNullOrWhiteSpace($gitEmail)) {
    Write-Error "All fields are required! Script execution aborted."
    exit
}

Write-Host "`nStarting process in the current directory: $((Get-Location).Path)..." -ForegroundColor Yellow

# 3. Initialize local Git repository
Write-Host "-> Initializing local Git repository..." -ForegroundColor Gray
git init

# 4. Configure local user settings (scoped only to this repository)
Write-Host "-> Configuring local Git user settings..." -ForegroundColor Gray
git config user.name "$gitUser"
git config user.email "$gitEmail"

# 5. Manage remote connection using the chosen alias
Write-Host "-> Setting up remote named '$remoteName'..." -ForegroundColor Gray
# Remove the remote alias if it already exists from a previous attempt to avoid conflicts
git remote remove $remoteName 2>$null
git remote add $remoteName $repoUrl

# 6. Fetch all objects and refs from the specific remote
Write-Host "-> Fetching data from remote server ($remoteName) (git fetch)..." -ForegroundColor Gray
git fetch $remoteName

# 7. Force checkout to the main branch (overwriting files with matching names)
Write-Host "-> Downloading files and forcing overwrite (git checkout -f)..." -ForegroundColor Yellow
git checkout -f main

# 8. Set upstream tracking for future seamless pull/push commands linked to this specific remote
Write-Host "-> Setting up branch tracking for default push/pull target..." -ForegroundColor Gray
git branch --set-upstream-to=$remoteName/main main

# 9. Verification and status display (reading directly from Git configs)
Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "       Process completed successfully!            " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "VERIFICATION SUMMARY (Read from local config):" -ForegroundColor Cyan

# Reading actual values from Git config for verification
$verifiedUrl = git config remote.$remoteName.url
$verifiedUser = git config user.name
$verifiedEmail = git config user.email

Write-Host "• Active Remote Name: $remoteName"
Write-Host "• Remote Repo URL   : $verifiedUrl"
Write-Host "• Local User Name   : $verifiedUser"
Write-Host "• Local User Email  : $verifiedEmail"

Write-Host "`nAvailable Branches & Tracking Info:" -ForegroundColor Cyan
# Listing all local branches with their upstream targets (-vv) and remote branches
git branch -vv
git branch -a
