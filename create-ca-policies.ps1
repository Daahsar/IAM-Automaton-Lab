<#
    create-ca-policies.ps1
    Author: John
    Purpose: Deploy Conditional Access policies for all departments except HR
    Safety: All policies are ReportOnly and exclude the admin account
#>

Import-Module Microsoft.Graph

Write-Host "`n=== Connecting to Microsoft Graph ===`n" -ForegroundColor Cyan
Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess","Directory.ReadWrite.All","Group.Read.All"

# ============================
# Admin account (excluded from all policies)
# ============================
$adminUpn = "AliR@reallabfakeorg.onmicrosoft.com"

# ============================
# Resolve group IDs
# ============================
Write-Host "`n=== Resolving Department Group IDs ===`n" -ForegroundColor Cyan

$engineeringGroupId    = (Get-MgGroup -Filter "displayName eq 'Engineering Users'").Id
$itGroupId             = (Get-MgGroup -Filter "displayName eq 'IT Users'").Id
$salesGroupId          = (Get-MgGroup -Filter "displayName eq 'Sales Users'").Id
$productGroupId        = (Get-MgGroup -Filter "displayName eq 'Product Users'").Id
$legalGroupId          = (Get-MgGroup -Filter "displayName eq 'Legal Users'").Id
$communicationsGroupId = (Get-MgGroup -Filter "displayName eq 'Communications Users'").Id

Write-Host "Engineering Users:     $engineeringGroupId"
Write-Host "IT Users:              $itGroupId"
Write-Host "Sales Users:           $salesGroupId"
Write-Host "Product Users:         $productGroupId"
Write-Host "Legal Users:           $legalGroupId"
Write-Host "Communications Users:  $communicationsGroupId"

Write-Host "`n=== Creating Conditional Access Policies ===`n" -ForegroundColor Cyan

# ============================================================
# ENGINEERING — Require MFA
# ============================================================
$body = @{
    displayName = "CA - Engineering - Require MFA"
    state       = "reportOnly"
    conditions  = @{
        users = @{
            includeGroups = @($engineeringGroupId)
            excludeUsers  = @($adminUpn)
        }
        applications = @{
            includeApplications = @("All")
        }
        clientAppTypes = @("browser","mobileAppsAndDesktopClients")
    }
    grantControls = @{
        operator = "OR"
        builtInControls = @("mfa")
    }
}

Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" `
    -Body ($body | ConvertTo-Json -Depth 10)

Write-Host "Created: CA - Engineering - Require MFA" -ForegroundColor Green

# ============================================================
# IT — Require Compliant Device
# ============================================================
$body = @{
    displayName = "CA - IT - Require compliant device"
    state       = "reportOnly"
    conditions  = @{
        users = @{
            includeGroups = @($itGroupId)
            excludeUsers  = @($adminUpn)
        }
        applications = @{
            includeApplications = @("All")
        }
        clientAppTypes = @("browser","mobileAppsAndDesktopClients")
    }
    grantControls = @{
        operator = "AND"
        builtInControls = @("compliantDevice")
    }
}

Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" `
    -Body ($body | ConvertTo-Json -Depth 10)

Write-Host "Created: CA - IT - Require compliant device" -ForegroundColor Green

# ============================================================
# SALES — Require MFA
# ============================================================
$body = @{
    displayName = "CA - Sales - Require MFA"
    state       = "reportOnly"
    conditions  = @{
        users = @{
            includeGroups = @($salesGroupId)
            excludeUsers  = @($adminUpn)
        }
        applications = @{
            includeApplications = @("All")
        }
        clientAppTypes = @("browser","mobileAppsAndDesktopClients")
    }
    grantControls = @{
        operator = "OR"
        builtInControls = @("mfa")
    }
}

Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" `
    -Body ($body | ConvertTo-Json -Depth 10)

Write-Host "Created: CA - Sales - Require MFA" -ForegroundColor Green

# ============================================================
# PRODUCT — Require MFA
# ============================================================
$body = @{
    displayName = "CA - Product - Require MFA"
    state       = "reportOnly"
    conditions  = @{
        users = @{
            includeGroups = @($productGroupId)
            excludeUsers  = @($adminUpn)
        }
        applications = @{
            includeApplications = @("All")
        }
        clientAppTypes = @("browser","mobileAppsAndDesktopClients")
    }
    grantControls = @{
        operator = "OR"
        builtInControls = @("mfa")
    }
}

Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" `
    -Body ($body | ConvertTo-Json -Depth 10)

Write-Host "Created: CA - Product - Require MFA" -ForegroundColor Green

# ============================================================
# LEGAL — Require MFA
# ============================================================
$body = @{
    displayName = "CA - Legal - Require MFA"
    state       = "reportOnly"
    conditions  = @{
        users = @{
            includeGroups = @($legalGroupId)
            excludeUsers  = @($adminUpn)
        }
        applications = @{
            includeApplications = @("All")
        }
        clientAppTypes = @("browser","mobileAppsAndDesktopClients")
    }
    grantControls = @{
        operator = "OR"
        builtInControls = @("mfa")
    }
}

Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" `
    -Body ($body | ConvertTo-Json -Depth 10)

Write-Host "Created: CA - Legal - Require MFA" -ForegroundColor Green

# ============================================================
# COMMUNICATIONS — Require MFA
# ============================================================
$body = @{
    displayName = "CA - Communications - Require MFA"
    state       = "reportOnly"
    conditions  = @{
        users = @{
            includeGroups = @($communicationsGroupId)
            excludeUsers  = @($adminUpn)
        }
        applications = @{
            includeApplications = @("All")
        }
        clientAppTypes = @("browser","mobileAppsAndDesktopClients")
    }
    grantControls = @{
        operator = "OR"
        builtInControls = @("mfa")
    }
}

Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" `
    -Body ($body | ConvertTo-Json -Depth 10)

Write-Host "Created: CA - Communications - Require MFA" -ForegroundColor Green

Write-Host "`n=== Conditional Access Policy Deployment Complete ===`n" -ForegroundColor Cyan
