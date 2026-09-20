# PowerShell -ExecutionPolicy Bypass -File .\Add-MqlGitRemote.ps1
# PowerShell Script to add a secondary remote and set it as the default tracking target
$ErrorActionPreference = "Stop"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   MQL5 Git Remote Strategy Reconfiguration       " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Select the Secondary Remote Name from a predefined list
Write-Host "Select the secondary remote repository alias to ADD:" -ForegroundColor Cyan
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

# 2. Prompt user for the secondary repository URL
Write-Host ""
$repoUrl = Read-Host "Enter the remote URL for '$remoteName'"

if ([string]::IsNullOrWhiteSpace($repoUrl)) {
    Write-Error "Repository URL is required! Script execution aborted."
    exit
}

Write-Host "`nReconfiguring Git remotes in: $((Get-Location).Path)..." -ForegroundColor Yellow

# 3. Add or Update the chosen secondary remote
$remoteExists = git remote | Select-String -Pattern "^$remoteName$"
if ($remoteExists) {
    Write-Host "-> '$remoteName' remote already exists. Updating its URL..." -ForegroundColor Gray
    git remote set-url $remoteName $repoUrl
} else {
    Write-Host "-> Adding new secondary remote named '$remoteName'..." -ForegroundColor Gray
    git remote add $remoteName $repoUrl
}

# 4. Set default push/pull target (Upstream) to the new remote's main branch
Write-Host "-> Setting '$remoteName' as the default target for 'git push' and 'git pull'..." -ForegroundColor Yellow
git branch --set-upstream-to=$remoteName/main main 2>$null

# 5. Verification and status display
Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "       Configuration completed successfully!      " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "CURRENT REMOTE REPOSITORIES:" -ForegroundColor Cyan
git remote -v

Write-Host "`nDEFAULT TRACKING BRANCH:" -ForegroundColor Cyan
git branch -vv

# 6. Proactive Next Steps and Recommendations for Force Push
Write-Host ""
Write-Host "RECOMMENDED NEXT STEP (To mirror your local codebase):" -ForegroundColor Yellow
Write-Host "To overwrite the remote target with your local history and avoid conflicts, run:" -ForegroundColor Gray
Write-Host "  git push -u \$remoteName main --force" -ForegroundColor Cyan
Write-Host ""
Write-Host "After running this command once, your default 'git push' and 'git pull' will point to '\$remoteName'." -ForegroundColor Gray
