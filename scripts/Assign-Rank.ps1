<#
.SYNOPSIS
    Assigns Rank (Manager/Senior/Junior) using the JobTitle field
    for all department users based on existing CSV files.

.DESCRIPTION
    Reads each department CSV, determines rank based on line order,
    and updates the JobTitle field in Entra ID.

.NOTES
    Author: John’s IAM Automation Lab
    Phase: 2 (RBAC + Identity Governance)
#>

# Path to your definitions folder
$DefinitionsPath = "C:\Users\Use me\iac\Phase1\definitions"

# Department files and rank distribution
$Departments = @{
    "engineering.csv"     = @{ Managers = 5; Seniors = 25; Juniors = 80 }
    "it.csv"              = @{ Managers = 2; Seniors = 5;  Juniors = 13 }
    "product.csv"         = @{ Managers = 2; Seniors = 5;  Juniors = 13 }
    "communications.csv"  = @{ Managers = 1; Seniors = 2;  Juniors = 7  }
    "sales.csv"           = @{ Managers = 2; Seniors = 5;  Juniors = 18 }
    "hr.csv"              = @{ Managers = 1; Seniors = 2;  Juniors = 7  }
    "legal.csv"           = @{ Managers = 1; Seniors = 1;  Juniors = 3  }
}

Write-Host "`n=== Starting Rank Assignment (JobTitle) ===`n"

foreach ($dept in $Departments.Keys) {

    $filePath = Join-Path $DefinitionsPath $dept
    if (-not (Test-Path $filePath)) {
        Write-Warning "Missing file: $filePath"
        continue
    }

    Write-Host "`nProcessing $dept ..." -ForegroundColor Cyan

    $users = Get-Content $filePath
    $counts = $Departments[$dept]

    $Managers = $users[0..($counts.Managers - 1)]
    $Seniors  = $users[$counts.Managers..($counts.Managers + $counts.Seniors - 1)]
    $Juniors  = $users[($counts.Managers + $counts.Seniors)..($users.Count - 1)]

    # Assign Managers
    foreach ($u in $Managers) {
        Write-Host "  Manager → $u"
        Update-MgUser -UserId $u -JobTitle "Manager"
    }

    # Assign Seniors
    foreach ($u in $Seniors) {
        Write-Host "  Senior → $u"
        Update-MgUser -UserId $u -JobTitle "Senior"
    }

    # Assign Juniors
    foreach ($u in $Juniors) {
        Write-Host "  Junior → $u"
        Update-MgUser -UserId $u -JobTitle "Junior"
    }
}

Write-Host "`n=== Rank Assignment Complete ===`n" -ForegroundColor Green
