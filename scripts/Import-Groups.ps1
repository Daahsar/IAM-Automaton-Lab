# ============================
# Import-Groups.ps1
# Creates groups in Entra ID from groups.json
# ============================

Write-Host "Loading group definitions..."

$groups = Get-Content ".\definitions\groups.json" | ConvertFrom-Json

Write-Host "Creating groups in Entra ID..."

foreach ($group in $groups) {
    Write-Host "Creating group: $($group.displayName)..."

    New-MgGroup -DisplayName $group.displayName `
            -Description $group.description `
            -MailEnabled:$false `
            -SecurityEnabled:$true `
            -MailNickname $group.mailNickname

    Write-Host "Created: $($group.displayName)"
}

Write-Host "All groups created successfully."