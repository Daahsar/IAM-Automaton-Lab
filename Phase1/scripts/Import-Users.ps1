# ============================
# Import-Users.ps1
# Creates users in Entra ID from users.json and issues a
# Temporary Access Pass (TAP) for first sign-in / onboarding
#
# Credential handling — no hardcoded or shared passwords:
# - No password is stored in this script or in the repository.
# - Microsoft Graph requires a passwordProfile when a user is
#   created, so a unique, cryptographically random value is
#   generated in memory for each user for that step only. It is
#   never displayed, logged, stored, shared, or used to sign in,
#   and it is discarded as soon as the account is created.
# - The user does not onboard with a password. Instead, the
#   script creates a one-time, time-limited Temporary Access
#   Pass for the new account. The TAP is shown once, to the
#   operator only, for secure out-of-band delivery. The user
#   signs in with the TAP, registers MFA / a passwordless
#   method, and sets their own password if one will be used.
#
# Prerequisites for TAP:
# - The Temporary Access Pass authentication methods policy
#   must be enabled in the tenant and cover the new users.
# - Graph permission: UserAuthenticationMethod.ReadWrite.All
#   (in addition to User.ReadWrite.All), e.g. via Connect-Graph.ps1.
# - The TAP lifetime requested must be within the minimum /
#   maximum set in the tenant TAP policy.
# ============================

param(
    [int]$TapLifetimeInMinutes = 480
)

# TAP creation uses the Identity SignIns Graph module
Import-Module Microsoft.Graph.Identity.SignIns -ErrorAction SilentlyContinue

function New-RandomCreationPassword {
    param([int]$Length = 24)

    $upper   = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lower   = 'abcdefghijkmnpqrstuvwxyz'
    $digits  = '23456789'
    $symbols = '!@#$%^&*()-_=+'
    $all     = ($upper + $lower + $digits + $symbols).ToCharArray()

    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        function Get-RandomChar([char[]]$Set) {
            $bytes = New-Object byte[] 4
            $rng.GetBytes($bytes)
            $index = [System.BitConverter]::ToUInt32($bytes, 0) % $Set.Length
            return $Set[$index]
        }

        $chars = @(
            (Get-RandomChar $upper.ToCharArray()),
            (Get-RandomChar $lower.ToCharArray()),
            (Get-RandomChar $digits.ToCharArray()),
            (Get-RandomChar $symbols.ToCharArray())
        )
        for ($i = $chars.Count; $i -lt $Length; $i++) {
            $chars += Get-RandomChar $all
        }

        $bytes = New-Object byte[] 4
        for ($i = $chars.Count - 1; $i -gt 0; $i--) {
            $rng.GetBytes($bytes)
            $j = [System.BitConverter]::ToUInt32($bytes, 0) % ($i + 1)
            $chars[$i], $chars[$j] = $chars[$j], $chars[$i]
        }

        return -join $chars
    }
    finally {
        $rng.Dispose()
    }
}

Write-Host "Loading user definitions..."

$users = Get-Content ".\definitions\users.json" | ConvertFrom-Json

Write-Host "Creating users in Entra ID..."

foreach ($user in $users) {

    # Generate mailNickname (lowercase, no spaces)
    $mailNickname = ($user.displayName -replace '\s+', '').ToLower()

    # Generate UPN
    $upn = "$mailNickname@reallabfakeorg.onmicrosoft.com"

    # Generated in memory only to satisfy Graph's creation requirement.
    # Never displayed, stored, shared, or used for onboarding.
    $creationPassword = New-RandomCreationPassword

    Write-Host "Creating user: $($user.displayName) ($upn)..."

    try {
        $createdUser = New-MgUser `
            -DisplayName $user.displayName `
            -UserPrincipalName $upn `
            -MailNickname $mailNickname `
            -Department $user.department `
            -JobTitle $user.jobTitle `
            -PasswordProfile @{ Password = $creationPassword; ForceChangePasswordNextSignIn = $true } `
            -AccountEnabled:$true
    }
    finally {
        $creationPassword = $null
    }

    $userId = $createdUser.Id
    if (-not $userId) {
        $userId = (Get-MgUser -Filter "userPrincipalName eq '$upn'").Id
    }

    # Issue a one-time, time-limited Temporary Access Pass for onboarding.
    # The TAP value is returned only at creation time.
    try {
        $tapParams = @{
            startDateTime     = (Get-Date).ToUniversalTime()
            lifetimeInMinutes = $TapLifetimeInMinutes
            isUsableOnce      = $true
        }

        $tap = New-MgUserAuthenticationTemporaryAccessPassMethod -UserId $userId -BodyParameter $tapParams

        Write-Host "Created: $($user.displayName)"
        Write-Host "Temporary Access Pass for $upn (one-time, $TapLifetimeInMinutes minutes, shown once — deliver securely, do not log or store): $($tap.TemporaryAccessPass)"
    }
    catch {
        Write-Warning "User $upn was created, but the Temporary Access Pass could not be issued: $($_.Exception.Message)"
        Write-Warning "Check that the TAP policy is enabled for this user and that the session has UserAuthenticationMethod.ReadWrite.All. Do not fall back to sharing a password."
    }

    $tap = $null
}

Write-Host "All users created successfully. Onboarding is by Temporary Access Pass — no passwords were stored, shared, or distributed."
