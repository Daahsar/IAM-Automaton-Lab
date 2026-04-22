# ============================
# Generate-Users.ps1
# Creates 200 mock users
# ============================

$departments = @{
    "Engineering"    = 110
    "Product"        = 20
    "Sales"          = 25
    "HR"             = 10
    "IT"             = 20
    "Legal"          = 5
    "Communications" = 10
}

$users = @()

foreach ($dept in $departments.Keys) {
    for ($i = 1; $i -le $departments[$dept]; $i++) {

        $jobTitle = switch ($dept) {
            "Engineering"    { "Developer" }
            "Product"        { "Product Manager" }
            "Sales"          { "Sales Representative" }
            "HR"             { "HR Generalist" }
            "IT"             { "IT Support Technician" }
            "Legal"          { "Legal Counsel" }
            "Communications" { "Communications Specialist" }
        }

        $users += [pscustomobject]@{
            displayName = "$dept User$i"
            department  = $dept
            jobTitle    = $jobTitle
        }
    }
}
$users | ConvertTo-Json -Depth 5 | Out-File ".\definitions\users.json"
Write-Host "users.json generated successfully."