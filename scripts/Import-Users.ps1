# ============================
# Import-Users.ps1
# Creates users in Entra ID from users.json
# ============================

Write-Host "Loading user definitions..."

$users = Get-Content ".\definitions\users.json" | ConvertFrom-Json

Write-Host "Creating users in Entra ID..."

foreach ($user in $users) {

    # Generate mailNickname (lowercase, no spaces)
    $mailNickname = ($user.displayName -replace '\s+', '').ToLower()

    # Generate UPN
    $upn = "$mailNickname@reallabfakeorg.onmicrosoft.com"

    # Generate a password
    $password = "P@ssw0rd123!"

    Write-Host "Creating user: $($user.displayName) ($upn)..."

    New-MgUser `
        -DisplayName $user.displayName `
        -UserPrincipalName $upn `
        -MailNickname $mailNickname `
        -Department $user.department `
        -JobTitle $user.jobTitle `
        -PasswordProfile @{ Password = $password; ForceChangePasswordNextSignIn = $true } `
        -AccountEnabled:$true

    Write-Host "Created: $($user.displayName)"
}

Write-Host "All users created successfully."