<#
    LIVE MODE DIRECTORY TRANSFORMATION SCRIPT
    -----------------------------------------
    - Generates American names automatically
    - Mixed male/female
    - No middle initials
    - Updates displayName, givenName, surname, jobTitle
    - Preserves UPN, mail, ObjectId
    - Skips your account: "Rashaad Porter"
    - Logs all changes
    - Department extracted from first word of displayName
    - Rank extracted from jobTitle
#>

Import-Module Microsoft.Graph.Users

# Ensure log directory exists
$LogPath = "C:\Users\Use me\iac\logs"
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath | Out-Null
}

$LogFile = "$LogPath\directory-transform.log"

Function Write-Log {
    param([string]$Message)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $LogFile -Value "$timestamp  $Message"
}

Write-Log "=== DIRECTORY TRANSFORMATION STARTED ==="

# American name pools
$MaleFirst = @(
    "James","John","Robert","Michael","William","David","Richard","Joseph","Thomas","Charles",
    "Christopher","Daniel","Matthew","Anthony","Mark","Donald","Steven","Paul","Andrew","Joshua",
    "Kevin","Brian","George","Timothy","Ronald","Edward","Jason","Jeffrey","Ryan","Jacob"
)

$FemaleFirst = @(
    "Mary","Patricia","Jennifer","Linda","Elizabeth","Barbara","Susan","Jessica","Sarah","Karen",
    "Nancy","Lisa","Margaret","Betty","Sandra","Ashley","Kimberly","Emily","Donna","Michelle",
    "Carol","Amanda","Dorothy","Melissa","Deborah","Stephanie","Rebecca","Sharon","Laura","Cynthia"
)

$LastNames = @(
    "Smith","Johnson","Williams","Brown","Jones","Garcia","Miller","Davis","Rodriguez","Martinez",
    "Hernandez","Lopez","Gonzalez","Wilson","Anderson","Thomas","Taylor","Moore","Jackson","Martin",
    "Lee","Perez","Thompson","White","Harris","Sanchez","Clark","Ramirez","Lewis","Robinson"
)

# Deterministic name generator (FIXED VERSION)
Function Get-DeterministicName {
    param([string]$ObjectId)

    $hash = [Math]::Abs(($ObjectId.GetHashCode()))
    $genderPick = $hash % 2

    if ($genderPick -eq 0) {
        $first = $MaleFirst[$hash % $MaleFirst.Count]
    } else {
        $first = $FemaleFirst[$hash % $FemaleFirst.Count]
    }

    # FIX: force integer division for array index
    $lastIndex = [math]::Floor($hash / 2) % $LastNames.Count
    $last = $LastNames[$lastIndex]

    return @{ First=$first; Last=$last }
}

# Department → Manager Title
$DeptToManagerTitle = @{
    "Engineering"    = "Engineering Manager"
    "Sales"          = "Sales Manager"
    "Product"        = "Product Manager"
    "Communications" = "Communications Manager"
    "IT"             = "IT Manager"
    "HR"             = "HR Manager"
    "Legal"          = "Legal Manager"
}

# Fetch all users
$Users = Get-MgUser -All

foreach ($u in $Users) {

    # Skip your account
    if ($u.DisplayName -eq "Rashaad Porter") {
        Write-Log "Skipping your account: $($u.DisplayName)"
        continue
    }

    # Extract department from first word of displayName
    $dept = $u.DisplayName.Split(" ")[0]

    if (-not $DeptToManagerTitle.ContainsKey($dept)) {
        Write-Log "Skipping user with unknown department: $($u.DisplayName)"
        continue
    }

    # Determine rank from jobTitle
    switch ($u.JobTitle) {
        "Junior" { $newJob = "Junior Associate" }
        "Senior" { $newJob = "Senior Associate" }
        "Manager" { $newJob = $DeptToManagerTitle[$dept] }
        default {
            Write-Log "Skipping user with unknown rank: $($u.DisplayName) ($($u.JobTitle))"
            continue
        }
    }

    # Generate deterministic name
    $name = Get-DeterministicName -ObjectId $u.Id
    $newDisplay = "$($name.First) $($name.Last)"

    Write-Log "Updating user: $($u.DisplayName) → $newDisplay | JobTitle: $newJob"

    # Apply updates (LIVE MODE)
    Update-MgUser -UserId $u.Id -DisplayName $newDisplay -GivenName $name.First -Surname $name.Last -JobTitle $newJob
}

Write-Log "=== DIRECTORY TRANSFORMATION COMPLETE ==="
