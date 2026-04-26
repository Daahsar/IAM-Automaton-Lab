param(
    [Parameter(Mandatory)]
    [string]$RoleDefinitionPath
)

# -----------------------------
# Setup logging
# -----------------------------

# Logs folder: Phase2\RBAC\logs (sibling to scripts)
$logsRoot = Join-Path $PSScriptRoot "..\logs"
if (-not (Test-Path $logsRoot)) {
    New-Item -Path $logsRoot -ItemType Directory | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$logFile = Join-Path $logsRoot "rbac-log-$timestamp.json"

$log = [ordered]@{
    timestamp   = (Get-Date).ToString("o")
    roleName    = $null
    roleId      = $null
    assignments = [ordered]@{
        users  = @()
        groups = @()
    }
}

# -----------------------------
# Use existing Microsoft Graph session
# -----------------------------

Write-Host "Using existing Microsoft Graph session..." -ForegroundColor Yellow

try {
    Get-MgContext | Out-Null
    Write-Host "Microsoft Graph session is active." -ForegroundColor Green
}
catch {
    Write-Host "No active Microsoft Graph session found." -ForegroundColor Red
    Write-Host "Please authenticate first using:" -ForegroundColor Yellow
    Write-Host 'Connect-MgGraph -Scopes "User.Read","Directory.Read.All","Directory.ReadWrite.All" -UseDeviceCode' -ForegroundColor Cyan
    $log.error = "No active Microsoft Graph session. User must run Connect-MgGraph first."
    $log | ConvertTo-Json -Depth 5 | Out-File -FilePath $logFile -Encoding UTF8
    exit 1
}

# -----------------------------
# Load role definition
# -----------------------------

$role = Get-Content $RoleDefinitionPath | ConvertFrom-Json

Write-Host "Deploying role: $($role.roleName)" -ForegroundColor Cyan
$log.roleName = $role.roleName

# -----------------------------
# Validate required fields
# -----------------------------

$requiredFields = @("roleName", "permissions", "assignTo")

foreach ($field in $requiredFields) {
    if (-not $role.$field) {
        Write-Host "Missing required field: $field" -ForegroundColor Red
        $log.error = "Missing required field: $field"
        $log | ConvertTo-Json -Depth 5 | Out-File -FilePath $logFile -Encoding UTF8
        exit 1
    }
}

# -----------------------------
# Validate users
# -----------------------------

$validatedUsers = @()
foreach ($user in $role.assignTo.users) {
    $u = Get-MgUser -Filter "userPrincipalName eq '$user'" -ErrorAction SilentlyContinue
    if (-not $u) {
        Write-Host "User not found: $user" -ForegroundColor Red
        $log.assignments.users += [ordered]@{
            principal = $user
            status    = "notFound"
            message   = "User not found in directory"
        }
    } else {
        Write-Host "Validated user: $user" -ForegroundColor Green
        $validatedUsers += $u
    }
}

# -----------------------------
# Validate groups
# -----------------------------

$validatedGroups = @()
foreach ($group in $role.assignTo.groups) {
    $g = Get-MgGroup -Filter "displayName eq '$group'" -ErrorAction SilentlyContinue
    if (-not $g) {
        Write-Host "Group not found: $group" -ForegroundColor Red
        $log.assignments.groups += [ordered]@{
            principal = $group
            status    = "notFound"
            message   = "Group not found in directory"
        }
    } else {
        Write-Host "Validated group: $group" -ForegroundColor Green
        $validatedGroups += $g
    }
}

# -----------------------------
# Validate permissions
# -----------------------------

foreach ($perm in $role.permissions) {
    if (-not $perm.resource -or -not $perm.type) {
        Write-Host "Invalid permission entry detected." -ForegroundColor Red
        continue
    }

    Write-Host "Permission OK: $($perm.resource) [$($perm.type)]" -ForegroundColor Green
}

# -----------------------------
# Create or update custom role
# -----------------------------

Write-Host "Checking if custom role already exists..." -ForegroundColor Yellow

$existingRole = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq '$($role.roleName)'" -ErrorAction SilentlyContinue

if ($existingRole) {
    Write-Host "Role already exists. Updating role: $($role.roleName)" -ForegroundColor Cyan

    $updateParams = @{
        DisplayName = $role.roleName
        Description = $role.description
        RolePermissions = @(
            @{
                AllowedResourceActions = $role.permissions.resource
            }
        )
    }

    try {
        Update-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $existingRole.Id -BodyParameter $updateParams
        Write-Host "Role updated successfully." -ForegroundColor Green
        $roleId = $existingRole.Id
        $log.roleId = $roleId
        $log.roleAction = "updated"
    }
    catch {
        Write-Host "Failed to update role." -ForegroundColor Red
        Write-Host $_.Exception.Message
        $log.error = "Failed to update role: $($_.Exception.Message)"
        $log | ConvertTo-Json -Depth 5 | Out-File -FilePath $logFile -Encoding UTF8
        exit 1
    }
}
else {
    Write-Host "Creating new custom role: $($role.roleName)" -ForegroundColor Cyan

    $createParams = @{
        DisplayName = $role.roleName
        Description = $role.description
        RolePermissions = @(
            @{
                AllowedResourceActions = $role.permissions.resource
            }
        )
    }

    try {
        $newRole = New-MgRoleManagementDirectoryRoleDefinition -BodyParameter $createParams
        Write-Host "Role created successfully. Role ID: $($newRole.Id)" -ForegroundColor Green
        $roleId = $newRole.Id
        $log.roleId = $roleId
        $log.roleAction = "created"
    }
    catch {
        Write-Host "Failed to create role." -ForegroundColor Red
        Write-Host $_.Exception.Message
        $log.error = "Failed to create role: $($_.Exception.Message)"
        $log | ConvertTo-Json -Depth 5 | Out-File -FilePath $logFile -Encoding UTF8
        exit 1
    }
}

# -----------------------------
# Idempotent role assignments
# -----------------------------

Write-Host "Checking existing role assignments..." -ForegroundColor Yellow

$existingAssignments = Get-MgRoleManagementDirectoryRoleAssignment -Filter "roleDefinitionId eq '$roleId'" -All

$usersAssigned = 0
$usersSkipped  = 0
$groupsAssigned = 0
$groupsSkipped  = 0

# Assign role to users
foreach ($u in $validatedUsers) {

    $alreadyAssigned = $existingAssignments | Where-Object { $_.PrincipalId -eq $u.Id }

    if ($alreadyAssigned) {
        Write-Host "User already has role — skipping: $($u.UserPrincipalName)" -ForegroundColor DarkYellow
        $usersSkipped++
        $log.assignments.users += [ordered]@{
            principal = $u.UserPrincipalName
            status    = "skipped"
            message   = "User already has role"
        }
        continue
    }

    Write-Host "Assigning role to user: $($u.UserPrincipalName)" -ForegroundColor Yellow

    try {
        New-MgRoleManagementDirectoryRoleAssignment -BodyParameter @{
            PrincipalId      = $u.Id
            RoleDefinitionId = $roleId
            DirectoryScopeId = "/"
        }
        Write-Host "Assigned role to user: $($u.UserPrincipalName)" -ForegroundColor Green
        $usersAssigned++
        $log.assignments.users += [ordered]@{
            principal = $u.UserPrincipalName
            status    = "assigned"
            message   = "Role assigned successfully"
        }
    }
    catch {
        Write-Host "Failed to assign role to user: $($u.UserPrincipalName)" -ForegroundColor Red
        Write-Host $_.Exception.Message
        $log.assignments.users += [ordered]@{
            principal = $u.UserPrincipalName
            status    = "failed"
            message   = $_.Exception.Message
        }
    }
}

# Assign role to groups
foreach ($g in $validatedGroups) {

    $alreadyAssigned = $existingAssignments | Where-Object { $_.PrincipalId -eq $g.Id }

    if ($alreadyAssigned) {
        Write-Host "Group already has role — skipping: $($g.DisplayName)" -ForegroundColor DarkYellow
        $groupsSkipped++
        $log.assignments.groups += [ordered]@{
            principal = $g.DisplayName
            status    = "skipped"
            message   = "Group already has role"
        }
        continue
    }

    Write-Host "Assigning role to group: $($g.DisplayName)" -ForegroundColor Yellow

    try {
        New-MgRoleManagementDirectoryRoleAssignment -BodyParameter @{
            PrincipalId      = $g.Id
            RoleDefinitionId = $roleId
            DirectoryScopeId = "/"
        }
        Write-Host "Assigned role to group: $($g.DisplayName)" -ForegroundColor Green
        $groupsAssigned++
        $log.assignments.groups += [ordered]@{
            principal = $g.DisplayName
            status    = "assigned"
            message   = "Role assigned successfully"
        }
    }
    catch {
        Write-Host "Failed to assign role to group: $($g.DisplayName)" -ForegroundColor Red
        Write-Host $_.Exception.Message
        $log.assignments.groups += [ordered]@{
            principal = $g.DisplayName
            status    = "failed"
            message   = $_.Exception.Message
        }
    }
}

# -----------------------------
# Summary + write log file
# -----------------------------

$log.summary = [ordered]@{
    usersAssigned   = $usersAssigned
    usersSkipped    = $usersSkipped
    groupsAssigned  = $groupsAssigned
    groupsSkipped   = $groupsSkipped
}

$log | ConvertTo-Json -Depth 5 | Out-File -FilePath $logFile -Encoding UTF8

Write-Host ""
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "------------------"
Write-Host "Role:           $($log.roleName)"
Write-Host "Role ID:        $($log.roleId)"
Write-Host "Users Assigned: $usersAssigned"
Write-Host "Users Skipped:  $usersSkipped"
Write-Host "Groups Assigned:$groupsAssigned"
Write-Host "Groups Skipped: $groupsSkipped"
Write-Host "Log File:       $logFile"
Write-Host ""

Write-Host "RBAC deployment completed (idempotent, logged, delegated session)." -ForegroundColor Green
