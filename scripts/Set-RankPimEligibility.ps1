<#
.SYNOPSIS
    Rank-based PIM eligibility assignment + cleanup.

.DESCRIPTION
    - Managers  -> Eligible for Application Administrator
    - Seniors   -> Eligible for Reports Reader
    - Juniors   -> No admin roles
    - Disabled, deleted, or unranked users -> Eligibility removed

    Requires:
      - RoleManagement.ReadWrite.Directory
      - Directory.Read.All
#>

Write-Host "`n=== Rank-based PIM Eligibility Assignment ===`n"

# ------------------------------------------------------------
# Helper: Get Role Definition IDs
# ------------------------------------------------------------
function Get-RoleDefinitionId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    $role = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq '$DisplayName'"
    if (-not $role) {
        throw "Role definition not found: $DisplayName"
    }
    return $role.Id
}

$roleId_AppAdmin      = Get-RoleDefinitionId -DisplayName "Application Administrator"
$roleId_ReportsReader = Get-RoleDefinitionId -DisplayName "Reports Reader"

Write-Host "App Admin RoleDefinitionId:      $roleId_AppAdmin"
Write-Host "Reports Reader RoleDefinitionId: $roleId_ReportsReader`n"

# ------------------------------------------------------------
# Get all users with a Rank (JobTitle)
# ------------------------------------------------------------
$allRankedUsers = Get-MgUser -All -Property "id,displayName,userPrincipalName,jobTitle,accountEnabled" |
                  Where-Object { $_.JobTitle -and $_.JobTitle.Trim() -ne "" }

Write-Host "Found $($allRankedUsers.Count) users with a Rank (JobTitle).`n"

# ------------------------------------------------------------
# Get existing eligibility schedules
# ------------------------------------------------------------
$existingEligibility = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All

function Has-Eligibility {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrincipalId,

        [Parameter(Mandatory = $true)]
        [string]$RoleDefinitionId
    )

    return $existingEligibility | Where-Object {
        $_.PrincipalId -eq $PrincipalId -and $_.RoleDefinitionId -eq $RoleDefinitionId
    }
}

# ------------------------------------------------------------
# Helper: Create eligibility
# ------------------------------------------------------------
function Ensure-PimEligibility {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrincipalId,

        [Parameter(Mandatory = $true)]
        [string]$RoleDefinitionId,

        [Parameter(Mandatory = $true)]
        [string]$Rank,

        [Parameter(Mandatory = $true)]
        [string]$RoleName
    )

    if (Has-Eligibility -PrincipalId $PrincipalId -RoleDefinitionId $RoleDefinitionId) {
        Write-Host "  [$Rank] Already eligible for $RoleName" -ForegroundColor DarkGray
        return
    }

    Write-Host "  [$Rank] Creating eligibility for $RoleName" -ForegroundColor Cyan

    $now = (Get-Date).ToUniversalTime()
    $end = $now.AddYears(1)

    New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -BodyParameter @{
        action            = "adminAssign"
        justification     = "Rank-based PIM eligibility (JobTitle = $Rank)"
        roleDefinitionId  = $RoleDefinitionId
        directoryScopeId  = "/"
        principalId       = $PrincipalId
        scheduleInfo      = @{
            startDateTime = $now
            expiration    = @{
                type = "AfterDateTime"
                endDateTime = $end
            }
        }
    } | Out-Null
}

# ------------------------------------------------------------
# Assign eligibility based on Rank
# ------------------------------------------------------------
foreach ($user in $allRankedUsers) {
    $rank = $user.JobTitle
    Write-Host "`nUser: $($user.DisplayName) <$($user.UserPrincipalName)>"
    Write-Host "  Rank: $rank"

    switch ($rank) {
        "Manager" {
            Ensure-PimEligibility -PrincipalId $user.Id `
                                  -RoleDefinitionId $roleId_AppAdmin `
                                  -Rank "Manager" `
                                  -RoleName "Application Administrator"
        }
        "Senior" {
            Ensure-PimEligibility -PrincipalId $user.Id `
                                  -RoleDefinitionId $roleId_ReportsReader `
                                  -Rank "Senior" `
                                  -RoleName "Reports Reader"
        }
        default {
            Write-Host "  [$rank] No PIM roles assigned (Juniors or other ranks)." -ForegroundColor DarkYellow
        }
    }
}

# ------------------------------------------------------------
# Cleanup: Remove eligibility for departed users
# ------------------------------------------------------------
Write-Host "`n=== Cleanup: Removing PIM Eligibility for Departed Users ===`n"

$eligibility = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All

foreach ($item in $eligibility) {

    $principalId = $item.PrincipalId
    $roleId      = $item.RoleDefinitionId

    $user = Get-MgUser -UserId $principalId -ErrorAction SilentlyContinue

    if (-not $user) {
        Write-Host "User $principalId no longer exists. Removing eligibility..." -ForegroundColor Yellow
        Remove-MgRoleManagementDirectoryRoleEligibilitySchedule -UnifiedRoleEligibilityScheduleId $item.Id -ErrorAction SilentlyContinue
        continue
    }

    if ($user.AccountEnabled -eq $false -or [string]::IsNullOrWhiteSpace($user.JobTitle)) {
        Write-Host "Removing eligibility for $($user.DisplayName) <$($user.UserPrincipalName)> (Left or no Rank)" -ForegroundColor Yellow
        Remove-MgRoleManagementDirectoryRoleEligibilitySchedule -UnifiedRoleEligibilityScheduleId $item.Id -ErrorAction SilentlyContinue
        continue
    }

    if ($user.JobTitle -eq "Junior") {
        Write-Host "Removing admin eligibility from Junior: $($user.DisplayName)" -ForegroundColor Yellow
        Remove-MgRoleManagementDirectoryRoleEligibilitySchedule -UnifiedRoleEligibilityScheduleId $item.Id -ErrorAction SilentlyContinue
        continue
    }
}

Write-Host "`n=== Rank-based PIM Eligibility Assignment Complete ===`n" -ForegroundColor Green