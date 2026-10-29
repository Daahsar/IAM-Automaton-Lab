# ============================
# Connect-Graph.ps1
# Authenticates to Microsoft Graph
# ============================

Import-Module Microsoft.Graph

Write-Host "Signing in to Microsoft Graph..."

# UserAuthenticationMethod.ReadWrite.All is required to issue
# Temporary Access Passes for newly provisioned users.
Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All","UserAuthenticationMethod.ReadWrite.All"

Write-Host "Connected to Microsoft Graph."
