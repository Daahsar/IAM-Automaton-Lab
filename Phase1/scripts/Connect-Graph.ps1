# ============================
# Connect-Graph.ps1
# Authenticates to Microsoft Graph
# ============================

Import-Module Microsoft.Graph

Write-Host "Signing in to Microsoft Graph..."

Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All"

Write-Host "Connected to Microsoft Graph."