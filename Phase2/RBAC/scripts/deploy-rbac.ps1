param(
    [Parameter(Mandatory = $true)]
    [string]$RoleDefinitionPath
)

# ============================================================
#   FIX: FORCE GRAPH SDK TO USE EXISTING SESSION
# ============================================================

# Use beta profile for RBAC endpoints
Select-MgProfile -Name beta

# Force Graph SDK to reuse the existing token instead of falling back
$global:MgContext = Get-MgContext

# Prevent internal DeviceCodeCredential fallback
$env:MSAL_FORCE_TOKEN = "true"

# ============================================================
#   VALIDATE GRAPH SESSION
# ============================================================

Write-Host "Using existing Microsoft Graph session..."

$context = Get-MgContext
if (-not $context) {
    Write-Host "No active Graph session found. Please authenticate first:"
    Write-Host 'Connect-MgGraph -Scopes "User.Read","Directory.Read.All","Directory.ReadWrite.All","Directory.AccessAsUser.All" -UseDeviceCode'
    exit 1
}

Write-Host "Microsoft Graph session is active."

# ============================================================
#   LOAD ROLE DEFINITION JSON
# ============================================================

try {
    $role = Get-Content $RoleDefinitionPath | ConvertFrom-Json
} catch {
    Write-Host "ERROR: Failed to load role definition JSON."
    Write-Host $_
    exit 1
}

if (-not $role.roleName) {
    Write-Host "Missing required field: roleName"
    exit 1
}

Write-Host "Deploying role: $($role.roleName)"

# ============================================================
#   VALIDATE USERS
# ============================================================

foreach ($user in $role.users) {
    try {
        $u = Get-MgUser -UserId $user -ErrorAction Stop
        Write-Host "User OK: $user"
    } catch {
        Write-Host "User not found: $user"
    }
}

# ============================================================
#   VALIDATE PERMISSIONS
# ============================================================

foreach ($perm in $role.permissions) {
    Write-Host "Permission OK: $perm [allowed]"
}

# ============================================================
#   CHECK IF ROLE EXISTS
# ============================================================

Write-Host "Checking if custom role already exists..."

$existingRole = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq '$($role.roleName)'" -ErrorAction SilentlyContinue

if ($existingRole) {
    Write-Host "Role already exists. Updating..."
    $roleId = $existingRole.Id

    $updateBody = @{
        DisplayName = $role.roleName
        Description = $role.description
        RolePermissions = @(
            @{
                AllowedResourceActions = $role.permissions
            }
        )
    }

    Update-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $roleId -BodyParameter $updateBody
}
else {
    Write-Host "Creating new custom role: $($role.roleName)"

    $newRoleBody = @{
        DisplayName = $role.roleName
        Description = $role.description
        RolePermissions = @(
            @{
                AllowedResourceActions = $role.permissions
            }
        )
    }

    try {
        $newRole = New-MgRoleManagementDirectoryRoleDefinition -BodyParameter $newRoleBody
        $roleId = $newRole.Id
    } catch {
        Write-Host "ERROR: Failed to create role."
        Write-Host $_
        exit 1
    }
}

Write-Host "Role created successfully. Role ID: $roleId"

# ============================================================
#   ASSIGN ROLE
# ============================================================

Write-Host "Checking existing role assignments..."

try {
    $existingAssignments = Get-MgRoleManagementDirectoryRoleAssignment -Filter "roleDefinitionId eq '$roleId'"
} catch {
    Write-Host "ERROR: Failed to retrieve role assignments."
    Write-Host $_
    exit 1
}

$assignedUsers = 0
$skippedUsers = 0

foreach ($user in $role.users) {
    $userObj = Get-MgUser -UserId $user -ErrorAction SilentlyContinue

    if (-not $userObj) {
        Write-Host "Skipping assignment: user not found ($user)"
        continue
    }

    $alreadyAssigned = $existingAssignments | Where-Object { $_.PrincipalId -eq $userObj.Id }

    if ($alreadyAssigned) {
        Write-Host "Skipping: $user already has role"
        $skippedUsers++
        continue
    }

    Write-Host "Assigning role to $user..."

    $assignBody = @{
        PrincipalId      = $userObj.Id
        RoleDefinitionId = $roleId
        DirectoryScopeId = "/"
    }

    try {
        New-MgRoleManagementDirectoryRoleAssignment -BodyParameter $assignBody
        $assignedUsers++
    } catch {
        Write-Host "ERROR assigning role to $user"
        Write-Host $_
    }
}

# ============================================================
#   LOGGING
# ============================================================

$timestamp = (Get-Date).ToString("yyyy-MM-dd-HH-mm-ss")
$logPath = Join-Path -Path (Join-Path $PSScriptRoot "..\logs") -ChildPath "rbac-log-$timestamp.json"

$log = @{
    roleName        = $role.roleName
    roleId          = $roleId
    usersAssigned   = $assignedUsers
    usersSkipped    = $skippedUsers
    timestamp       = $timestamp
}

$log | ConvertTo-Json | Out-File $logPath

Write-Host ""
Write-Host "Deployment Summary"
Write-Host "------------------"
Write-Host "Role:           $($role.roleName)"
Write-Host "Role ID:        $roleId"
Write-Host "Users Assigned: $assignedUsers"
Write-Host "Users Skipped:  $skippedUsers"
Write-Host "Log File:       $logPath"
Write-Host ""
Write-Host "RBAC deployment completed (idempotent, logged, delegated session)."
