<#
.SYNOPSIS
    Assignment Checker - interactive web dashboard for Intune group assignments.

.DESCRIPTION
    This script:
      1. Installs the Microsoft.Graph.Authentication module if missing.
      2. Connects to Microsoft Graph via the "Microsoft Graph Command Line Tools"
         enterprise application (no custom app registration required).
      3. Opens a browser for interactive sign-in and consent to the required
         permissions (only on first use or when new scopes are added).
      4. Starts a local web server and opens the dashboard in the default browser.

    No app registrations, client secrets, or portal configuration required.

.NOTES
    Requires PowerShell 5.1+ (Windows PowerShell) or PowerShell 7+ (cross-platform).
    The signed-in user must be able to consent to (or have an admin pre-consent)
    the listed Graph scopes.
#>

[CmdletBinding()]
param(
    [int]$Port = 8080
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:CurrentVersion = "1.0.0"

# -----------------------------------------------------------------------------
# 2. Ensure the Microsoft Graph Authentication module is available
# -----------------------------------------------------------------------------

$moduleName = "Microsoft.Graph.Authentication"

if (-not (Get-Module -ListAvailable -Name $moduleName)) {
    Write-Host ""
    Write-Host "  Installing $moduleName module (one-time setup)..." -ForegroundColor Cyan
    Write-Host ""
    try {
        Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber -Repository PSGallery -MinimumVersion 2.0.0
        Write-Host "  Module installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to install $moduleName. Please run: Install-Module $moduleName -Scope CurrentUser"
        exit 1
    }
}

Import-Module $moduleName -ErrorAction Stop

# -----------------------------------------------------------------------------
# 3. Connect to Microsoft Graph with required scopes (interactive sign-in)
# -----------------------------------------------------------------------------

$requiredScopes = @(
    "DeviceManagementApps.Read.All"
    "DeviceManagementConfiguration.Read.All"
    "DeviceManagementManagedDevices.Read.All"
    "DeviceManagementScripts.Read.All"
    "Group.Read.All"
    "User.Read"
    "User.Read.All"
)

Write-Host ""
Write-Host "  ======================================================" -ForegroundColor Magenta
Write-Host "         Assignment Checker                             " -ForegroundColor Magenta
Write-Host "  ======================================================" -ForegroundColor Magenta
Write-Host "  No app registration required.                         " -ForegroundColor Magenta
Write-Host "  Permissions are requested via Microsoft Graph          " -ForegroundColor Magenta
Write-Host "  Command Line Tools.                                   " -ForegroundColor Magenta
Write-Host "                                                        " -ForegroundColor Magenta
Write-Host "  A browser window will open for sign-in.               " -ForegroundColor Magenta
Write-Host "  You may be prompted to consent to permissions         " -ForegroundColor Magenta
Write-Host "  on first use.                                         " -ForegroundColor Magenta
Write-Host "  ======================================================" -ForegroundColor Magenta
Write-Host ""

<# try {
    Connect-MgGraph -Scopes $requiredScopes -NoWelcome
    $context = Get-MgContext
    Write-Host "  Signed in as: $($context.Account)" -ForegroundColor Green
    Write-Host "  Tenant:       $($context.TenantId)" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Error "Authentication failed: $_"
    exit 1
}

#>

# -----------------------------------------------------------------------------
# 3a. Per-launch session state: API secret and idle-timeout tracking
# -----------------------------------------------------------------------------

# High-entropy random secret bound to this launch. Only the browser window
# opened by this script ever sees it (delivered via URL fragment). Any
# other local process that hits the listener without this key is rejected
# from /api/* routes so it cannot piggyback on the Graph session.
$script:apiSecretBytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($script:apiSecretBytes)
$script:apiSecret = ([Convert]::ToBase64String($script:apiSecretBytes)).TrimEnd('=').Replace('+','-').Replace('/','_')

# Idle timeout: disconnect Graph after this many seconds of inactivity.
# Matches the SPA-side timer (30 min) so an abandoned terminal does not
# leave delegated Graph access available indefinitely.
$script:idleTimeoutSec   = 30 * 60
$script:lastActivityTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$script:sessionExpired   = $false

# -----------------------------------------------------------------------------
# 4. Graph API helper functions
# -----------------------------------------------------------------------------

function Invoke-GraphPaginated {
    <#
    .SYNOPSIS
        Fetches all pages from a Microsoft Graph endpoint.
    #>
    param(
        [Parameter(Mandatory)][string]$Uri,
        [switch]$SilentErrors
    )

    $all = [System.Collections.ArrayList]::new()
    $nextUri = $Uri

    $maxRetries = 3

    while ($nextUri) {
        $response = $null
        for ($attempt = 0; $attempt -le $maxRetries; $attempt++) {
            try {
                $response = Invoke-MgGraphRequest -Method GET -Uri $nextUri -OutputType PSObject
                break
            }
            catch {
                $statusCode = 0
                $respProp = $_.Exception.PSObject.Properties['Response']
                if ($respProp) {
                    $statusCode = [int]$respProp.Value.StatusCode
                }
                # Retry on 429 (throttled) or 5xx (server error)
                if (($statusCode -eq 429 -or $statusCode -ge 500) -and $attempt -lt $maxRetries) {
                    $delay = [Math]::Pow(2, $attempt + 1)
                    Write-Warning "Graph API $statusCode on attempt $($attempt + 1), retrying in ${delay}s"
                    Start-Sleep -Seconds $delay
                    continue
                }
                $safeUri = ($nextUri -split '\?')[0]
                Write-Warning "Graph request failed for $safeUri (HTTP $statusCode)"
                if ($SilentErrors) { $nextUri = $null; break }
                throw
            }
        }
        if (-not $response) { break }

        if ($response.value) {
            $response.value | ForEach-Object { [void]$all.Add($_) }
        }

        # Safely check for next page link — the property may not exist
        # on the response object depending on output type and PS version.
        if ($response -is [hashtable]) {
            $nextUri = $response['@odata.nextLink']
        } elseif ($response.PSObject.Properties.Match('@odata.nextLink').Count) {
            $nextUri = $response.'@odata.nextLink'
        } else {
            $nextUri = $null
        }

        # Validate nextLink to prevent token leakage to untrusted hosts
        if ($nextUri) {
            try {
                $parsedLink = [System.Uri]::new($nextUri)
                if ($parsedLink.Scheme -ne 'https' -or $parsedLink.Host -ne 'graph.microsoft.com') {
                    Write-Warning "Ignoring untrusted @odata.nextLink host: $($parsedLink.Host)"
                    $nextUri = $null
                }
            } catch {
                Write-Warning "Ignoring malformed @odata.nextLink"
                $nextUri = $null
            }
        }
    }

    # Return items through the pipeline individually.
    # Callers should use @() to collect results into an array.
    $all.ToArray()
}

function Get-AllGroups {
    # Note: $orderby on /groups requires ConsistencyLevel:eventual + $count=true
    # which complicates pagination. Sort client-side instead.
    $uri = "/v1.0/groups?`$select=id,displayName,description,groupTypes,membershipRule&`$top=999"
    $groups = @(Invoke-GraphPaginated -Uri $uri)
    if ($groups.Count -gt 0) {
        $groups = @($groups | Sort-Object { $_.displayName })
    }
    $groups
}

function Get-SafeValue {
    <#
    .SYNOPSIS
        Safely reads a property from an object that may be a hashtable or PSObject.
        Returns $null when the key/property does not exist, avoiding StrictMode errors.
    #>
    param($Object, [string]$Key)

    if ($null -eq $Object) { return $null }
    if ($Object -is [hashtable]) { return $Object[$Key] }
    $prop = $Object.PSObject.Properties.Match($Key)
    if ($prop.Count) { return $prop[0].Value }
    return $null
}

function Get-ItemPlatform {
    param([object]$Item, [string]$CategoryKey)

    if ($CategoryKey -eq 'scripts' -or $CategoryKey -eq 'remediations') {
        return "Windows"
    }
    if ($CategoryKey -eq 'settingsCatalog') {
        $platforms = Get-SafeValue $Item 'platforms'
        if ($platforms) {
            $p = "$platforms".ToLower()
            if ($p -match 'windows') { return "Windows" }
            if ($p -match 'ios')     { return "iOS" }
            if ($p -match 'macos')   { return "macOS" }
            if ($p -match 'android') { return "Android" }
        }
        return ""
    }
    $odataType = Get-SafeValue $Item '@odata.type'
    if ($odataType) {
        $t = "$odataType".ToLower()
        if ($t -match 'ios|iphone')                   { return "iOS" }
        if ($t -match 'android')                      { return "Android" }
        if ($t -match 'windows|win32|microsoftstore|winget') { return "Windows" }
        if ($t -match 'macos')                        { return "macOS" }
    }
    return ""
}

function Get-AssignmentsForGroup {
    param([string]$GroupId)

    $categories = @{
        configurations  = "/beta/deviceManagement/deviceConfigurations?`$expand=assignments"
        compliance      = "/beta/deviceManagement/deviceCompliancePolicies?`$expand=assignments"
        settingsCatalog = "/beta/deviceManagement/configurationPolicies?`$expand=assignments"
        applications    = "/beta/deviceAppManagement/mobileApps?`$expand=assignments&`$filter=isAssigned eq true"
        scripts         = "/beta/deviceManagement/deviceManagementScripts?`$expand=assignments"
        remediations    = "/beta/deviceManagement/deviceHealthScripts?`$expand=assignments"
    }

    $result  = @{}
    $_errors = @{}

    foreach ($cat in $categories.GetEnumerator()) {
        $matched = [System.Collections.ArrayList]::new()
        try {
            $items = @(Invoke-GraphPaginated -Uri $cat.Value)
        }
        catch {
            Write-Warning "Category $($cat.Key) failed: $($_.Exception.Message)"
            $_errors[$cat.Key] = $_.Exception.Message
            $result[$cat.Key]  = @()
            continue
        }

        foreach ($item in $items) {
            $itemAssignments = Get-SafeValue $item 'assignments'
            if (-not $itemAssignments) { continue }

            foreach ($assignment in $itemAssignments) {
                $target = Get-SafeValue $assignment 'target'
                if (-not $target) { continue }

                $targetGroupId = Get-SafeValue $target 'groupId'
                $targetType    = Get-SafeValue $target '@odata.type'

                # Match: group assignment to this group, OR All Devices, OR All Users
                $isGroupMatch     = ($targetGroupId -eq $GroupId)
                $isAllDevices     = ($targetType -eq '#microsoft.graph.allDevicesAssignmentTarget')
                $isAllUsers       = ($targetType -eq '#microsoft.graph.allLicensedUsersAssignmentTarget')

                if ($isGroupMatch -or $isAllDevices -or $isAllUsers) {
                    $friendly = switch ($targetType) {
                        "#microsoft.graph.groupAssignmentTarget"            { "Include" }
                        "#microsoft.graph.exclusionGroupAssignmentTarget"   { "Exclude" }
                        "#microsoft.graph.allDevicesAssignmentTarget"       { "All Devices" }
                        "#microsoft.graph.allLicensedUsersAssignmentTarget" { "All Users" }
                        default { $targetType }
                    }

                    $itemDisplayName = Get-SafeValue $item 'displayName'
                    $itemName        = Get-SafeValue $item 'name'
                    $displayName     = if ($itemDisplayName) { $itemDisplayName } elseif ($itemName) { $itemName } else { "N/A" }
                    $itemDesc        = Get-SafeValue $item 'description'
                    $assignIntent    = Get-SafeValue $assignment 'intent'
                    $filterId        = Get-SafeValue $target 'deviceAndAppManagementAssignmentFilterId'
                    $filterType      = Get-SafeValue $target 'deviceAndAppManagementAssignmentFilterType'

                    [void]$matched.Add(@{
                        id              = Get-SafeValue $item 'id'
                        displayName     = $displayName
                        description     = if ($itemDesc) { $itemDesc } else { "" }
                        assignmentType  = $friendly
                        intent          = if ($assignIntent) { $assignIntent } else { "" }
                        filterId        = if ($filterId) { $filterId } else { "" }
                        filterType      = if ($filterType) { $filterType } else { "" }
                        platform        = Get-ItemPlatform -Item $item -CategoryKey $cat.Key
                    })
                    # Don't break — same item may match as both group + All Devices/Users
                }
            }
        }

        $result[$cat.Key] = @($matched.ToArray())
    }

    $result['_errors'] = $_errors
    return $result
}

function Get-GroupParentGroups {
    <#
    .SYNOPSIS
        Returns the transitive group memberships for a given group.
        This reveals which parent groups this group is nested within.
    #>
    param([Parameter(Mandatory)][string]$GroupId)

    $uri = "/v1.0/groups/$GroupId/transitiveMemberOf/microsoft.graph.group?`$select=id,displayName&`$top=999"
    $parents = @(Invoke-GraphPaginated -Uri $uri -SilentErrors)
    return $parents
}

function Get-NestedGroupAssignments {
    <#
    .SYNOPSIS
        For a given group, finds all assignments that come through parent group
        memberships (nested/inherited assignments).
    #>
    param(
        [Parameter(Mandatory)][string]$GroupId,
        [Parameter(Mandatory)][array]$ParentGroups
    )

    $categories = @{
        configurations  = "/beta/deviceManagement/deviceConfigurations?`$expand=assignments"
        compliance      = "/beta/deviceManagement/deviceCompliancePolicies?`$expand=assignments"
        settingsCatalog = "/beta/deviceManagement/configurationPolicies?`$expand=assignments"
        applications    = "/beta/deviceAppManagement/mobileApps?`$expand=assignments&`$filter=isAssigned eq true"
        scripts         = "/beta/deviceManagement/deviceManagementScripts?`$expand=assignments"
        remediations    = "/beta/deviceManagement/deviceHealthScripts?`$expand=assignments"
    }

    # Build a lookup of parent group IDs to names
    $parentLookup = @{}
    foreach ($pg in $ParentGroups) {
        $pgId = Get-SafeValue $pg 'id'
        $pgName = Get-SafeValue $pg 'displayName'
        if ($pgId) { $parentLookup[$pgId] = if ($pgName) { $pgName } else { $pgId } }
    }

    $result  = @{}
    $_errors = @{}

    foreach ($cat in $categories.GetEnumerator()) {
        $matched = [System.Collections.ArrayList]::new()
        try {
            $items = @(Invoke-GraphPaginated -Uri $cat.Value)
        }
        catch {
            $_errors[$cat.Key] = $_.Exception.Message
            $result[$cat.Key]  = @()
            continue
        }

        foreach ($item in $items) {
            $itemAssignments = Get-SafeValue $item 'assignments'
            if (-not $itemAssignments) { continue }

            foreach ($assignment in $itemAssignments) {
                $target = Get-SafeValue $assignment 'target'
                if (-not $target) { continue }

                $targetGroupId = Get-SafeValue $target 'groupId'
                $targetType    = Get-SafeValue $target '@odata.type'

                # Check if assignment targets a parent group
                if ($targetGroupId -and $parentLookup.ContainsKey($targetGroupId)) {
                    $friendly = switch ($targetType) {
                        "#microsoft.graph.groupAssignmentTarget"          { "Include" }
                        "#microsoft.graph.exclusionGroupAssignmentTarget" { "Exclude" }
                        default { $targetType }
                    }

                    $itemDisplayName = Get-SafeValue $item 'displayName'
                    $itemName        = Get-SafeValue $item 'name'
                    $displayName     = if ($itemDisplayName) { $itemDisplayName } elseif ($itemName) { $itemName } else { "N/A" }
                    $itemDesc        = Get-SafeValue $item 'description'
                    $assignIntent    = Get-SafeValue $assignment 'intent'
                    $filterId        = Get-SafeValue $target 'deviceAndAppManagementAssignmentFilterId'
                    $filterType      = Get-SafeValue $target 'deviceAndAppManagementAssignmentFilterType'

                    [void]$matched.Add(@{
                        id              = Get-SafeValue $item 'id'
                        displayName     = $displayName
                        description     = if ($itemDesc) { $itemDesc } else { "" }
                        assignmentType  = $friendly
                        intent          = if ($assignIntent) { $assignIntent } else { "" }
                        filterId        = if ($filterId) { $filterId } else { "" }
                        filterType      = if ($filterType) { $filterType } else { "" }
                        inheritedFrom   = $parentLookup[$targetGroupId]
                        inheritedFromId = $targetGroupId
                        platform        = Get-ItemPlatform -Item $item -CategoryKey $cat.Key
                    })
                }
            }
        }

        $result[$cat.Key] = @($matched.ToArray())
    }

    $result['_errors'] = $_errors
    return $result
}

function Get-OrphanedItems {
    <#
    .SYNOPSIS
        Returns all Intune items (policies, apps, scripts, remediations) that have
        zero assignments — i.e. orphaned items that may be candidates for cleanup.
    #>
    $categories = @{
        configurations  = "/beta/deviceManagement/deviceConfigurations?`$expand=assignments"
        compliance      = "/beta/deviceManagement/deviceCompliancePolicies?`$expand=assignments"
        settingsCatalog = "/beta/deviceManagement/configurationPolicies?`$expand=assignments"
        applications    = "/beta/deviceAppManagement/mobileApps?`$expand=assignments&`$select=id,displayName,description,assignments"
        scripts         = "/beta/deviceManagement/deviceManagementScripts?`$expand=assignments"
        remediations    = "/beta/deviceManagement/deviceHealthScripts?`$expand=assignments"
    }

    $result  = @{}
    $_errors = @{}

    foreach ($cat in $categories.GetEnumerator()) {
        $orphaned = [System.Collections.ArrayList]::new()
        try {
            $items = @(Invoke-GraphPaginated -Uri $cat.Value)
        }
        catch {
            Write-Warning "Orphaned check for $($cat.Key) failed: $($_.Exception.Message)"
            $_errors[$cat.Key] = $_.Exception.Message
            $result[$cat.Key]  = @()
            continue
        }

        foreach ($item in $items) {
            $itemAssignments = Get-SafeValue $item 'assignments'
            $assignCount = 0
            if ($itemAssignments) {
                $assignCount = @($itemAssignments).Count
            }

            if ($assignCount -eq 0) {
                $itemDisplayName = Get-SafeValue $item 'displayName'
                $itemName        = Get-SafeValue $item 'name'
                $displayName     = if ($itemDisplayName) { $itemDisplayName } elseif ($itemName) { $itemName } else { "N/A" }
                $itemDesc        = Get-SafeValue $item 'description'

                [void]$orphaned.Add(@{
                    id          = Get-SafeValue $item 'id'
                    displayName = $displayName
                    description = if ($itemDesc) { $itemDesc } else { "" }
                    platform    = Get-ItemPlatform -Item $item -CategoryKey $cat.Key
                })
            }
        }

        $result[$cat.Key] = @($orphaned.ToArray())
    }

    $result['_errors'] = $_errors

    # Compute unassigned groups (groups with no Intune assignments)
    try {
        $allGroupsList  = @(Get-AllGroups)
        $assignedResult = Get-AssignedGroupIds
        $assignedSet    = @{}
        foreach ($gid in $assignedResult.ids) { $assignedSet[$gid] = $true }

        $unassigned = [System.Collections.ArrayList]::new()
        foreach ($grp in $allGroupsList) {
            $grpId = Get-SafeValue $grp 'id'
            if ($grpId -and -not $assignedSet.ContainsKey($grpId)) {
                $grpDisplayName = Get-SafeValue $grp 'displayName'
                $grpDesc        = Get-SafeValue $grp 'description'
                $grpTypes       = Get-SafeValue $grp 'groupTypes'
                $groupType      = "Assigned"
                if ($grpTypes -and ($grpTypes -contains "DynamicMembership")) {
                    $groupType = "Dynamic"
                }
                [void]$unassigned.Add(@{
                    id          = $grpId
                    displayName = if ($grpDisplayName) { $grpDisplayName } else { "Unnamed" }
                    description = if ($grpDesc) { $grpDesc } else { "" }
                    groupType   = $groupType
                })
            }
        }
        $result['groups'] = @($unassigned.ToArray())
    }
    catch {
        Write-Warning "Unassigned groups check failed: $($_.Exception.Message)"
        $result['_errors']['groups'] = $_.Exception.Message
        $result['groups']  = @()
    }

    return $result
}

function Get-AssignedGroupIds {
    <#
    .SYNOPSIS
        Returns a list of unique group IDs that appear as assignment targets
        across all Intune policy categories.
    #>
    $endpoints = @(
        "/beta/deviceManagement/deviceConfigurations?`$expand=assignments&`$select=id,assignments"
        "/beta/deviceManagement/deviceCompliancePolicies?`$expand=assignments&`$select=id,assignments"
        "/beta/deviceManagement/configurationPolicies?`$expand=assignments&`$select=id,assignments"
        "/beta/deviceAppManagement/mobileApps?`$expand=assignments&`$filter=isAssigned eq true&`$select=id,assignments"
        "/beta/deviceManagement/deviceManagementScripts?`$expand=assignments&`$select=id,assignments"
        "/beta/deviceManagement/deviceHealthScripts?`$expand=assignments&`$select=id,assignments"
    )

    $counts = @{}

    foreach ($uri in $endpoints) {
        $items = Invoke-GraphPaginated -Uri $uri -SilentErrors
        foreach ($item in $items) {
            $itemAssignments = Get-SafeValue $item 'assignments'
            if (-not $itemAssignments) { continue }
            foreach ($assignment in $itemAssignments) {
                $target  = Get-SafeValue $assignment 'target'
                if (-not $target) { continue }
                $gid = Get-SafeValue $target 'groupId'
                if ($gid) {
                    if ($counts.ContainsKey($gid)) {
                        $counts[$gid] = $counts[$gid] + 1
                    } else {
                        $counts[$gid] = 1
                    }
                }
            }
        }
    }

    @{
        ids    = @($counts.Keys)
        counts = $counts
    }
}

function Get-GroupMemberCounts {
    <#
    .SYNOPSIS
        Returns a map of groupId -> member count for the supplied group IDs.
        Uses the Graph /$batch endpoint to fetch up to 20 counts per request.
        Groups that return a non-200 response are simply omitted from the map;
        the caller treats a missing entry as "unknown" rather than zero.
    #>
    param([string[]]$GroupIds)

    $counts = @{}
    if (-not $GroupIds -or $GroupIds.Count -eq 0) { return $counts }

    # De-dupe and validate GUIDs
    $valid = @()
    $seen  = @{}
    foreach ($g in $GroupIds) {
        if (-not $g) { continue }
        $parsed = [System.Guid]::Empty
        if ([System.Guid]::TryParse($g, [ref]$parsed)) {
            $gid = $parsed.ToString()
            if (-not $seen.ContainsKey($gid)) {
                $seen[$gid] = $true
                $valid += $gid
            }
        }
    }

    $batchSize = 20
    for ($i = 0; $i -lt $valid.Count; $i += $batchSize) {
        $end   = [Math]::Min($i + $batchSize - 1, $valid.Count - 1)
        # Wrap in @() so a single-element slice still presents as an array.
        $chunk = @($valid[$i..$end])

        $requests = @()
        for ($j = 0; $j -lt $chunk.Count; $j++) {
            $requests += @{
                id      = "$j"
                method  = "GET"
                url     = "/groups/$($chunk[$j])/members/`$count"
                headers = @{ "ConsistencyLevel" = "eventual" }
            }
        }

        $body = @{ requests = $requests } | ConvertTo-Json -Depth 5 -Compress
        try {
            $resp = Invoke-MgGraphRequest -Method POST -Uri "/v1.0/`$batch" -Body $body -ContentType "application/json" -OutputType PSObject
        }
        catch {
            Write-Warning "Member count batch failed: $($_.Exception.Message)"
            continue
        }

        $responses = Get-SafeValue $resp 'responses'
        if (-not $responses) { continue }

        foreach ($r in $responses) {
            $idStr = Get-SafeValue $r 'id'
            $idx   = 0
            if (-not [int]::TryParse("$idStr", [ref]$idx)) { continue }
            if ($idx -lt 0 -or $idx -ge $chunk.Count) { continue }

            $status = Get-SafeValue $r 'status'
            if ([int]$status -ne 200) { continue }

            $rawBody = Get-SafeValue $r 'body'
            $n       = 0
            if ($rawBody -is [int] -or $rawBody -is [long]) {
                $n = [int]$rawBody
            }
            elseif ($rawBody -is [string]) {
                [void][int]::TryParse($rawBody, [ref]$n)
            }
            else {
                # Sometimes batch wraps text/plain bodies — try coercion
                [void][int]::TryParse("$rawBody", [ref]$n)
            }
            $counts[$chunk[$idx]] = $n
        }
    }

    return $counts
}

function Get-AssignmentsByTargetType {
    param([string]$TargetOdataType)

    $categories = @{
        configurations  = "/beta/deviceManagement/deviceConfigurations?`$expand=assignments"
        compliance      = "/beta/deviceManagement/deviceCompliancePolicies?`$expand=assignments"
        settingsCatalog = "/beta/deviceManagement/configurationPolicies?`$expand=assignments"
        applications    = "/beta/deviceAppManagement/mobileApps?`$expand=assignments&`$filter=isAssigned eq true"
        scripts         = "/beta/deviceManagement/deviceManagementScripts?`$expand=assignments"
        remediations    = "/beta/deviceManagement/deviceHealthScripts?`$expand=assignments"
    }

    $friendly = switch ($TargetOdataType) {
        "#microsoft.graph.allDevicesAssignmentTarget"       { "All Devices" }
        "#microsoft.graph.allLicensedUsersAssignmentTarget" { "All Users" }
        default { $TargetOdataType }
    }

    $result  = @{}
    $_errors = @{}

    foreach ($cat in $categories.GetEnumerator()) {
        $matched = [System.Collections.ArrayList]::new()
        try {
            $items = @(Invoke-GraphPaginated -Uri $cat.Value)
        }
        catch {
            Write-Warning "Category $($cat.Key) failed: $($_.Exception.Message)"
            $_errors[$cat.Key] = $_.Exception.Message
            $result[$cat.Key]  = @()
            continue
        }

        foreach ($item in $items) {
            $itemAssignments = Get-SafeValue $item 'assignments'
            if (-not $itemAssignments) { continue }

            foreach ($assignment in $itemAssignments) {
                $target = Get-SafeValue $assignment 'target'
                if (-not $target) { continue }

                $targetType = Get-SafeValue $target '@odata.type'
                if ($targetType -ne $TargetOdataType) { continue }

                $itemDisplayName = Get-SafeValue $item 'displayName'
                $itemName        = Get-SafeValue $item 'name'
                $displayName     = if ($itemDisplayName) { $itemDisplayName } elseif ($itemName) { $itemName } else { "N/A" }
                $itemDesc        = Get-SafeValue $item 'description'
                $assignIntent    = Get-SafeValue $assignment 'intent'
                $filterId        = Get-SafeValue $target 'deviceAndAppManagementAssignmentFilterId'
                $filterType      = Get-SafeValue $target 'deviceAndAppManagementAssignmentFilterType'

                [void]$matched.Add(@{
                    id              = Get-SafeValue $item 'id'
                    displayName     = $displayName
                    description     = if ($itemDesc) { $itemDesc } else { "" }
                    assignmentType  = $friendly
                    intent          = if ($assignIntent) { $assignIntent } else { "" }
                    filterId        = if ($filterId) { $filterId } else { "" }
                    filterType      = if ($filterType) { $filterType } else { "" }
                    platform        = Get-ItemPlatform -Item $item -CategoryKey $cat.Key
                })
            }
        }

        $result[$cat.Key] = @($matched.ToArray())
    }

    $result['_errors'] = $_errors
    return $result
}

# -----------------------------------------------------------------------------
# 5. JSON serialization helper
# -----------------------------------------------------------------------------

function ConvertTo-SafeJson {
    param($InputObject, [switch]$AsArray)

    # -AsArray: guarantee the output is always a JSON array, regardless
    # of PowerShell's array-unwrapping quirks (0 items → "[]",
    # 1 item → "[{…}]", N items → "[{…},{…},…]").
    if ($AsArray) {
        if ($null -eq $InputObject) { return "[]" }
        $arr = @($InputObject)
        if ($arr.Count -eq 0) { return "[]" }
        $json = ConvertTo-Json -InputObject $arr -Depth 10 -Compress
        # Guard: some PS versions still unwrap single-element arrays
        if ($json[0] -ne '[') { $json = "[$json]" }
        return $json
    }

    if ($null -eq $InputObject) { return "null" }
    return (ConvertTo-Json -InputObject $InputObject -Depth 10 -Compress)
}

function Set-SecurityHeaders {
    <#
    .SYNOPSIS
        Adds standard security headers to an HTTP response.
    #>
    param(
        [Parameter(Mandatory)]
        [System.Net.HttpListenerResponse]$Response
    )

    $Response.Headers.Set("X-Content-Type-Options", "nosniff")
    $Response.Headers.Set("X-Frame-Options", "DENY")
    $Response.Headers.Set("Referrer-Policy", "strict-origin-when-cross-origin")
    $Response.Headers.Set("Permissions-Policy", "geolocation=(), microphone=(), camera=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=()")
    $Response.Headers.Set("X-Permitted-Cross-Domain-Policies", "none")
    $csp = "default-src 'none'; script-src 'self' https://cdn.jsdelivr.net; style-src 'self'; img-src 'self'; " +
           "connect-src 'self' https://graph.microsoft.com https://login.microsoftonline.com; font-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
    $Response.Headers.Set("Content-Security-Policy", $csp)

    # CORS: restrict cross-origin requests to same localhost origin
    $Response.Headers.Set("Access-Control-Allow-Origin", "http://localhost:$Port")
    $Response.Headers.Set("Access-Control-Allow-Methods", "GET, POST, HEAD, OPTIONS")
    $Response.Headers.Set("Access-Control-Allow-Headers", "Content-Type, X-Backend-Key")
}

function Test-ApiOrigin {
    <#
    .SYNOPSIS
        Validates that an API request originates from the expected localhost origin.
        Returns $true if valid, $false if the request should be rejected.
    #>
    param(
        [Parameter(Mandatory)][System.Net.HttpListenerRequest]$Request
    )

    $origin  = $Request.Headers["Origin"]
    $referer = $Request.Headers["Referer"]
    $expectedOrigin = "http://localhost:$Port"

    if ($origin) {
        return ($origin -eq $expectedOrigin)
    } elseif ($referer) {
        return $referer.StartsWith("$expectedOrigin/")
    }
    # Browser-initiated requests always send Origin or Referer;
    # allow requests with neither (e.g. curl, PowerShell, direct browser navigation)
    return $true
}

# -----------------------------------------------------------------------------
# 6. Embedded web assets (HTML / CSS / JS baked directly into the script)
# -----------------------------------------------------------------------------

# NOTE: These are single-quoted here-strings — PowerShell will NOT expand
# dollar signs or backticks inside them, which is exactly what we want for
# HTML / CSS / JavaScript source that is full of $ characters.

$script:htmlBytes = [System.Text.Encoding]::UTF8.GetBytes(@'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self' https://graph.microsoft.com; font-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'">
    <title>Assignment Checker</title>
    <link rel="stylesheet" href="/static/css/style.css">
    <!-- Framebuster: <meta> CSP does not enforce frame-ancestors (browsers only
         honor it as an HTTP response header). For GitHub Pages we cannot set
         response headers, so break out of any frame as a defence-in-depth step.
         The PowerShell backend additionally sends X-Frame-Options: DENY. -->
    <script>
        if (window.top !== window.self) {
            try { window.top.location = window.self.location; }
            catch (e) { document.documentElement.innerHTML = ""; }
        }
    </script>
</head>
<body>
    <!-- Header -->
    <header class="app-header">
        <div class="header-left">
            <h1>Assignment Checker</h1>
        </div>
        <div class="header-right">
            <button class="btn-header active" id="btnShowAllDevices" title="Show/hide All Devices assignments">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>
                All Devices
            </button>
            <button class="btn-header active" id="btnShowAllUsers" title="Show/hide All Users assignments">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                All Users
            </button>
            <button class="btn-header active" id="btnShowNested" title="Show/hide inherited assignments from parent groups">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><line x1="19" y1="1" x2="19" y2="7"/><line x1="16" y1="4" x2="22" y2="4"/></svg>
                Nested Groups
            </button>
            <button class="btn-header" id="btnTheme" title="Toggle dark mode">
                <svg id="iconSun" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display:none">
                    <circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/>
                </svg>
                <svg id="iconMoon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>
                </svg>
            </button>
        </div>
    </header>

    <!-- Main Layout -->
    <div class="app-layout">

        <!-- Left Panel — Group List -->
        <aside class="sidebar" id="sidebar">
            <div class="sidebar-header">
                <h2>Entra Groups</h2>
                <div class="sidebar-header-actions">
                    <span class="group-count" id="groupCount">0</span>
                    <button class="btn-filter active" id="btnGroupFilter" title="Toggle: show only groups with assignments or all groups">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/></svg>
                    </button>
                </div>
            </div>
            <div class="search-box">
                <svg class="search-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>
                </svg>
                <input type="text" id="groupSearch" placeholder="Search groups..." autocomplete="off">
            </div>
            <div class="count-filter" id="countFilter">
                <button class="btn-count-filter" id="btnCountFilter" title="Filter groups by assignment count">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="4" y1="21" x2="4" y2="14"/><line x1="4" y1="10" x2="4" y2="3"/><line x1="12" y1="21" x2="12" y2="12"/><line x1="12" y1="8" x2="12" y2="3"/><line x1="20" y1="21" x2="20" y2="16"/><line x1="20" y1="12" x2="20" y2="3"/><line x1="1" y1="14" x2="7" y2="14"/><line x1="9" y1="8" x2="15" y2="8"/><line x1="17" y1="16" x2="23" y2="16"/></svg>
                    Assignment Count
                </button>
                <div class="count-filter-panel" id="countFilterPanel" style="display:none">
                    <div class="count-filter-row">
                        <label>Min</label>
                        <input type="number" id="filterMinCount" min="0" placeholder="0" autocomplete="off">
                        <label>Max</label>
                        <input type="number" id="filterMaxCount" min="0" placeholder="Any" autocomplete="off">
                    </div>
                    <div class="count-filter-actions">
                        <button class="btn-count-apply" id="btnCountApply">Apply</button>
                        <button class="btn-count-clear" id="btnCountClear">Clear</button>
                        <button class="btn-count-export" id="btnCountExport" title="Export the current filtered group list to CSV">Export CSV</button>
                    </div>
                </div>
            </div>
            <ul class="group-list" id="groupList">
                <!-- Populated by JS -->
            </ul>
            <ul class="group-list-sticky" id="groupListSticky">
                <!-- Synthetic groups (All Devices, All Users, Orphaned Items) — always visible -->
            </ul>
            <div class="sidebar-loading" id="sidebarLoading">
                <div class="spinner"></div>
                <p>Loading groups...</p>
            </div>
            <div class="sidebar-error" id="sidebarError" style="display:none">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="m15 9-6 6M9 9l6 6"/></svg>
                <p id="sidebarErrorMsg">Failed to load groups.</p>
                <button class="btn-retry" id="btnRetry">Retry</button>
            </div>
        </aside>

        <!-- Right Panel — Assignment Details -->
        <main class="content" id="content">

            <!-- Empty state -->
            <div class="empty-state" id="emptyState">
                <div class="empty-icon">
                    <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                        <rect width="18" height="18" x="3" y="3" rx="2"/>
                        <path d="M9 3v18M3 9h6M3 15h6"/>
                    </svg>
                </div>
                <h2>Select a Group</h2>
                <p>Choose an Entra group from the left panel to view its Intune assignments.</p>
            </div>

            <!-- Loading state -->
            <div class="content-loading" id="contentLoading" style="display:none">
                <div class="spinner large"></div>
                <p>Fetching assignments...</p>
            </div>

            <!-- Error state -->
            <div class="content-error" id="contentError" style="display:none">
                <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="m15 9-6 6M9 9l6 6"/></svg>
                <p id="contentErrorMsg">Error</p>
            </div>

            <!-- Assignment data -->
            <div class="assignments" id="assignments" style="display:none">
                <div class="assignments-header">
                    <div class="assignments-header-top">
                        <div>
                            <h2 id="selectedGroupName">Group Name</h2>
                            <p class="assignments-subtitle" id="selectedGroupDesc"></p>
                            <div class="membership-rule" id="membershipRule" style="display:none">
                                <span class="membership-rule-label">Dynamic Rule</span>
                                <code class="membership-rule-query" id="membershipRuleQuery"></code>
                            </div>
                        </div>
                        <div class="assignments-header-actions">
                            <button class="btn-export" id="btnExportCsv" title="Export current view to CSV">
                                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
                                Export CSV
                            </button>
                        </div>
                    </div>
                </div>

                <!-- Category tabs -->
                <div class="category-tabs" id="categoryTabs">
                    <button class="tab active" data-category="configurations">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/></svg>
                        Configurations
                        <span class="tab-count" id="countConfigurations">0</span>
                    </button>
                    <button class="tab" data-category="compliance">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg>
                        Compliance
                        <span class="tab-count" id="countCompliance">0</span>
                    </button>
                    <button class="tab" data-category="settingsCatalog">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 3h18v18H3z"/><path d="M3 9h18M3 15h18M9 3v18"/></svg>
                        Settings Catalog
                        <span class="tab-count" id="countSettingsCatalog">0</span>
                    </button>
                    <button class="tab" data-category="applications">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="7" height="7" x="3" y="3" rx="1"/><rect width="7" height="7" x="14" y="3" rx="1"/><rect width="7" height="7" x="3" y="14" rx="1"/><rect width="7" height="7" x="14" y="14" rx="1"/></svg>
                        Applications
                        <span class="tab-count" id="countApplications">0</span>
                    </button>
                    <button class="tab" data-category="scripts">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>
                        Scripts
                        <span class="tab-count" id="countScripts">0</span>
                    </button>
                    <button class="tab" data-category="remediations">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19.439 7.85c-.049.322.059.648.289.878l1.568 1.568c.47.47.706 1.087.706 1.704s-.235 1.233-.706 1.704l-1.611 1.611a.98.98 0 0 1-.837.276c-.47-.07-.802-.48-.968-.925a2.501 2.501 0 1 0-3.214 3.214c.446.166.855.497.925.968a.979.979 0 0 1-.276.837l-1.61 1.61a2.404 2.404 0 0 1-1.705.707 2.402 2.402 0 0 1-1.704-.706l-1.568-1.568a1.026 1.026 0 0 0-.877-.29c-.493.074-.84.504-1.02.968a2.5 2.5 0 1 1-3.237-3.237c.464-.18.894-.527.967-1.02a1.026 1.026 0 0 0-.289-.877l-1.568-1.568A2.402 2.402 0 0 1 1.998 12c0-.617.236-1.234.706-1.704L4.315 8.685a.98.98 0 0 1 .837-.276c.47.07.802.48.968.925a2.501 2.501 0 1 0 3.214-3.214c-.446-.166-.855-.497-.925-.968a.979.979 0 0 1 .276-.837l1.61-1.61a2.404 2.404 0 0 1 1.705-.707c.617 0 1.234.236 1.704.706l1.568 1.568c.23.23.556.338.877.29.493-.074.84-.504 1.02-.968a2.5 2.5 0 1 1 3.237 3.237c-.464.18-.894.527-.967 1.02Z"/></svg>
                        Remediations
                        <span class="tab-count" id="countRemediations">0</span>
                    </button>
                    <button class="tab" data-category="groups" style="display:none">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                        Groups
                        <span class="tab-count" id="countGroups">0</span>
                    </button>
                </div>

                <!-- Platform filter (orphaned items only) -->
                <div class="platform-filter" id="platformFilter" style="display:none">
                    <span class="platform-filter-label">Platform:</span>
                    <button class="platform-btn active" data-platform="">All</button>
                    <button class="platform-btn" data-platform="Android">Android</button>
                    <button class="platform-btn" data-platform="iOS">iOS</button>
                    <button class="platform-btn" data-platform="Windows">Windows</button>
                    <button class="platform-btn" data-platform="macOS">macOS</button>
                </div>

                <!-- Assignment cards -->
                <div class="card-grid" id="cardGrid">
                    <!-- Populated by JS -->
                </div>

                <!-- Empty category state -->
                <div class="category-empty" id="categoryEmpty" style="display:none">
                    <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M13 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><polyline points="13 2 13 9 20 9"/></svg>
                    <p>No assignments found in this category.</p>
                </div>
            </div>
        </main>
    </div>

    <!-- Script Preview Modal -->
    <div class="modal-overlay" id="scriptModal">
        <div class="modal">
            <div class="modal-header">
                <span>
                    <span class="modal-title" id="scriptModalTitle">Script</span>
                    <span class="modal-subtitle" id="scriptModalFile"></span>
                </span>
                <span class="modal-actions">
                    <button class="btn-copy-script" id="btnCopyScript" title="Copy script">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
                        <span id="copyBtnLabel">Copy Script</span>
                    </button>
                    <button class="btn-modal-close" id="btnModalClose" title="Close">
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                    </button>
                </span>
            </div>
            <div class="modal-body" id="scriptModalBody">
                <div class="modal-loading">
                    <div class="spinner"></div>
                    <p>Loading script content...</p>
                </div>
            </div>
        </div>
    </div>

    <script src="/static/js/graph.js"></script>
    <script src="/static/js/app.js"></script>
</body>
</html>
'@)

$script:cssBytes = [System.Text.Encoding]::UTF8.GetBytes(@'
/* ═══════════════════════════════════════════════════════════════════════════
   Assignment Checker — ZeroToTrust Edition
   Palette: Sky Blue → Purple → Magenta (from logo gradient)
   ═══════════════════════════════════════════════════════════════════════════ */

:root {
    /* Primary palette — purple center of the shield gradient */
    --primary:        #7C3AED;
    --primary-light:  #A78BFA;
    --primary-lighter: #C4B5FD;
    --primary-pale:   #EDE9FE;
    --primary-dark:   #6D28D9;
    --primary-darker: #5B21B6;

    /* Accent — magenta from the bottom of the shield */
    --accent:         #D946EF;
    --accent-light:   #E879F9;

    /* Secondary — sky blue from the top of the shield */
    --secondary:      #38BDF8;
    --secondary-dark: #0EA5E9;

    /* Neutrals */
    --bg:             #F5F3FF;
    --surface:        #ffffff;
    --surface-hover:  #FAF5FF;
    --border:         #E5E1F0;
    --border-light:   #EDE9FE;
    --text:           #1E1B2E;
    --text-secondary: #6B6F82;
    --text-muted:     #9EA2B3;

    /* Semantic */
    --include-bg:     #E6F9ED;
    --include-text:   #1A7A3A;
    --exclude-bg:     #FDE8E8;
    --exclude-text:   #B52A2A;

    /* Layout */
    --sidebar-width:  340px;
    --header-height:  60px;
    --radius:         10px;
    --radius-sm:      6px;

    /* Shadows */
    --shadow-sm:      0 1px 3px rgba(124, 58, 237, 0.06);
    --shadow-md:      0 4px 12px rgba(124, 58, 237, 0.10);
    --shadow-lg:      0 8px 30px rgba(124, 58, 237, 0.14);

    /* Header gradient — matches ZeroToTrust shield */
    --header-gradient: linear-gradient(135deg, #38BDF8 0%, #818CF8 40%, #A855F7 70%, #D946EF 100%);

    /* Focus ring */
    --focus-ring:     rgba(124, 58, 237, 0.12);
}

/* ── Dark Mode ──────────────────────────────────────────────────────────── */

[data-theme="dark"] {
    --bg:             #0F0D1A;
    --surface:        #1A1726;
    --surface-hover:  #231F33;
    --border:         #2E2A40;
    --border-light:   #37325A;
    --text:           #F1F0F7;
    --text-secondary: #A09CB3;
    --text-muted:     #706C85;

    --primary-pale:   #2D2250;
    --primary-lighter: #6D5EAD;

    --include-bg:     #0D2818;
    --include-text:   #4ADE80;
    --exclude-bg:     #2D0F0F;
    --exclude-text:   #FCA5A5;

    --shadow-sm:      0 1px 3px rgba(0, 0, 0, 0.30);
    --shadow-md:      0 4px 12px rgba(0, 0, 0, 0.40);
    --shadow-lg:      0 8px 30px rgba(0, 0, 0, 0.50);

    --focus-ring:     rgba(167, 139, 250, 0.20);
}

/* ── Reset & Base ────────────────────────────────────────────────────────── */

*, *::before, *::after {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

html, body {
    height: 100%;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
    -webkit-font-smoothing: antialiased;
    transition: background 0.3s, color 0.3s;
}

/* ── Header ──────────────────────────────────────────────────────────────── */

.app-header {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    z-index: 100;
    height: var(--header-height);
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 24px;
    background: var(--header-gradient);
    color: #fff;
    box-shadow: 0 2px 16px rgba(124, 58, 237, 0.30);
}

.header-left {
    display: flex;
    align-items: center;
    gap: 12px;
}

.app-header h1 {
    font-size: 18px;
    font-weight: 600;
    letter-spacing: -0.02em;
}

.header-right {
    display: flex;
    align-items: center;
    gap: 8px;
}

.connection-badge {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 5px 12px;
    background: rgba(255, 255, 255, 0.15);
    border-radius: 20px;
    font-size: 12px;
    font-weight: 500;
    backdrop-filter: blur(4px);
}

/* Header pill buttons (shared style for dark mode toggle, logout) */
.btn-header {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 5px 14px;
    background: rgba(255, 255, 255, 0.12);
    border: 1px solid rgba(255, 255, 255, 0.25);
    border-radius: 20px;
    color: #fff;
    font-size: 12px;
    font-weight: 500;
    font-family: inherit;
    cursor: pointer;
    backdrop-filter: blur(4px);
    transition: background 0.2s, border-color 0.2s;
}

.btn-header:hover {
    background: rgba(255, 255, 255, 0.22);
    border-color: rgba(255, 255, 255, 0.40);
}

.btn-header.active {
    background: rgba(255, 255, 255, 0.28);
    border-color: rgba(255, 255, 255, 0.50);
}

.btn-header:not(.active) {
    opacity: 0.55;
}

.btn-header svg {
    flex-shrink: 0;
}

.badge-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: #facc15;
    animation: pulse-dot 1.8s infinite;
}

.badge-dot.connected {
    background: #4ade80;
    animation: none;
}

.badge-dot.error {
    background: #f87171;
    animation: none;
}

@keyframes pulse-dot {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.4; }
}

/* ── Layout ──────────────────────────────────────────────────────────────── */

.app-layout {
    display: flex;
    height: calc(100vh - var(--header-height));
    margin-top: var(--header-height);
}

/* ── Sidebar ─────────────────────────────────────────────────────────────── */

.sidebar {
    width: var(--sidebar-width);
    min-width: var(--sidebar-width);
    background: var(--surface);
    border-right: 1px solid var(--border);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    transition: background 0.3s, border-color 0.3s;
}

.sidebar-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 20px 20px 0;
}

.sidebar-header h2 {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.05em;
}

.sidebar-header-actions {
    display: flex;
    align-items: center;
    gap: 6px;
}

.group-count {
    font-size: 11px;
    font-weight: 600;
    background: var(--primary-pale);
    color: var(--primary-light);
    padding: 2px 8px;
    border-radius: 10px;
}

.btn-filter {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
    border: 1.5px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--surface);
    color: var(--text-muted);
    cursor: pointer;
    transition: all 0.2s;
}

.btn-filter:hover {
    border-color: var(--primary-lighter);
    color: var(--primary-light);
    background: var(--surface-hover);
}

.btn-filter.active {
    border-color: var(--primary);
    background: var(--primary);
    color: #fff;
}

.search-box {
    position: relative;
    padding: 14px 20px;
}

.search-icon {
    position: absolute;
    left: 32px;
    top: 50%;
    transform: translateY(-50%);
    color: var(--text-muted);
    pointer-events: none;
}

.search-box input {
    width: 100%;
    padding: 9px 12px 9px 36px;
    border: 1.5px solid var(--border);
    border-radius: var(--radius-sm);
    font-size: 13px;
    font-family: inherit;
    color: var(--text);
    background: var(--bg);
    outline: none;
    transition: border-color 0.2s, box-shadow 0.2s, background 0.3s;
}

.search-box input:focus {
    border-color: var(--primary);
    box-shadow: 0 0 0 3px var(--focus-ring);
}

.search-box input::placeholder {
    color: var(--text-muted);
}

/* Group list */
.group-list {
    list-style: none;
    overflow-y: auto;
    flex: 1;
    padding: 0 12px 12px;
}

.group-list::-webkit-scrollbar {
    width: 5px;
}

.group-list::-webkit-scrollbar-thumb {
    background: var(--primary-lighter);
    border-radius: 10px;
}

.group-item {
    padding: 12px 14px;
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: all 0.15s ease;
    border: 1.5px solid transparent;
    margin-bottom: 2px;
}

.group-item:hover {
    background: var(--surface-hover);
    border-color: var(--border-light);
}

.group-item.active {
    background: var(--primary-pale);
    border-color: var(--primary-lighter);
}

.group-item-header {
    display: flex;
    align-items: center;
    gap: 2px;
}

.group-item-header .group-item-copy {
    flex-shrink: 0;
    opacity: 0;
    transition: opacity 0.2s;
}

.group-item:hover .group-item-header .group-item-copy {
    opacity: 1;
}

.group-item-header .btn-copy {
    width: 22px;
    height: 22px;
}

.group-item-name {
    font-size: 13.5px;
    font-weight: 500;
    color: var(--text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    min-width: 0;
}

.group-item.active .group-item-name {
    color: var(--primary-light);
    font-weight: 600;
}

.group-item-desc {
    font-size: 11.5px;
    color: var(--text-muted);
    margin-top: 2px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

/* Synthetic group items (All Devices / All Users) */
.group-item-synthetic {
    background: var(--primary-pale);
    border-color: var(--border-light);
}

.group-item-synthetic .group-item-name {
    display: flex;
    align-items: center;
    gap: 6px;
}

.group-item-synthetic .group-item-name svg {
    flex-shrink: 0;
    color: var(--primary-light);
}

.group-item-synthetic.active {
    background: var(--primary);
    border-color: var(--primary-dark);
}

.group-item-synthetic.active .group-item-name {
    color: #fff;
}

.group-item-synthetic.active .group-item-name svg {
    color: #fff;
}

.group-item-synthetic.active .group-item-desc {
    color: rgba(255, 255, 255, 0.7);
}

/* Sticky synthetic group list at sidebar bottom */
.group-list-sticky {
    list-style: none;
    padding: 6px 12px 8px;
    border-top: 1px solid var(--border);
    flex-shrink: 0;
}

.group-list-sticky .group-item-synthetic {
    padding: 6px 10px;
    margin-bottom: 2px;
}

.group-list-sticky .group-item-synthetic:last-child {
    margin-bottom: 0;
}

.group-list-sticky .group-item-name {
    font-size: 12px;
}

.group-list-separator {
    height: 1px;
    background: var(--border);
    margin: 8px 4px;
    list-style: none;
}

.group-item-badges {
    display: flex;
    align-items: center;
    gap: 6px;
    margin-top: 4px;
    flex-wrap: wrap;
}

.group-item-type {
    display: inline-block;
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    padding: 1px 6px;
    border-radius: 4px;
    background: var(--primary-pale);
    color: var(--primary-light);
}

.group-item-count {
    display: inline-block;
    font-size: 10px;
    font-weight: 600;
    padding: 1px 6px;
    border-radius: 4px;
    background: var(--include-bg);
    color: var(--include-text);
}

.group-item-members {
    display: inline-block;
    font-size: 10px;
    font-weight: 600;
    padding: 1px 6px;
    border-radius: 4px;
    background: var(--primary-pale);
    color: var(--primary-light);
}

/* Highlight zero-member groups — these are the "orphan-assigned" groups
   the user wants to spot quickly. */
.group-item-members-empty {
    background: var(--exclude-bg);
    color: var(--exclude-text);
}

.group-item-members-loading {
    background: transparent;
    color: var(--text-muted);
    font-weight: 400;
}

/* Count filter */
.count-filter {
    padding: 0 20px 8px;
}

.btn-count-filter {
    display: flex;
    align-items: center;
    gap: 6px;
    width: 100%;
    padding: 7px 12px;
    border: 1.5px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--surface);
    font-size: 12px;
    font-weight: 500;
    font-family: inherit;
    color: var(--text-secondary);
    cursor: pointer;
    transition: all 0.2s;
}

.btn-count-filter:hover {
    border-color: var(--primary-lighter);
    color: var(--primary-light);
}

.btn-count-filter.active {
    border-color: var(--primary);
    background: var(--primary-pale);
    color: var(--primary);
}

.count-filter-panel {
    margin-top: 8px;
    padding: 10px 12px;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
}

.count-filter-row {
    display: flex;
    align-items: center;
    gap: 8px;
}

.count-filter-row label {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary);
    text-transform: uppercase;
}

.count-filter-row input {
    flex: 1;
    min-width: 0;
    padding: 5px 8px;
    border: 1.5px solid var(--border);
    border-radius: 4px;
    font-size: 12px;
    font-family: inherit;
    color: var(--text);
    background: var(--surface);
    outline: none;
    transition: border-color 0.2s;
}

.count-filter-row input:focus {
    border-color: var(--primary);
}

.count-filter-actions {
    display: flex;
    gap: 6px;
    margin-top: 8px;
}

/* Shared box sizing for all three action buttons. A solid 1px border is
   included in the base rule — variants override the color — so Apply
   doesn't render shorter than Clear/Export and the row baseline-aligns.
   flex: 1 stretches the trio edge-to-edge so there's no ragged trailing
   space on the right side of the panel. */
.btn-count-apply, .btn-count-clear, .btn-count-export {
    flex: 1;
    padding: 5px 14px;
    border: 1px solid transparent;
    border-radius: 4px;
    font-size: 11px;
    font-weight: 600;
    font-family: inherit;
    cursor: pointer;
    transition: all 0.2s;
}

.btn-count-apply {
    background: var(--primary);
    border-color: var(--primary);
    color: #fff;
}

.btn-count-apply:hover {
    background: var(--primary-dark);
    border-color: var(--primary-dark);
}

.btn-count-clear {
    background: var(--surface);
    border-color: var(--border);
    color: var(--text-secondary);
}

.btn-count-clear:hover {
    background: var(--surface-hover);
}

/* Export uses the same neutral-default/primary-on-hover recipe as the
   canonical .btn-export above the main content (style.css:898) so the two
   export affordances feel like the same component across the app. */
.btn-count-export {
    background: var(--surface);
    border-color: var(--border);
    color: var(--text-secondary);
}

.btn-count-export:hover {
    background: var(--primary-pale);
    border-color: var(--primary-lighter);
    color: var(--primary);
}

.btn-count-export:disabled {
    opacity: 0.5;
    cursor: not-allowed;
    background: var(--surface);
}

/* Sidebar loading / error */
.sidebar-loading, .sidebar-error {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    flex: 1;
    gap: 12px;
    color: var(--text-muted);
    font-size: 13px;
    padding: 20px;
    text-align: center;
}

.sidebar-error svg {
    color: #f87171;
}

.btn-retry {
    padding: 6px 16px;
    border: none;
    border-radius: var(--radius-sm);
    background: var(--primary);
    color: #fff;
    font-size: 12px;
    font-weight: 500;
    font-family: inherit;
    cursor: pointer;
    transition: background 0.2s;
}

.btn-retry:hover {
    background: var(--primary-dark);
}

/* ── Main Content ────────────────────────────────────────────────────────── */

.content {
    flex: 1;
    overflow-y: auto;
    padding: 28px 32px;
    transition: background 0.3s;
}

.content::-webkit-scrollbar {
    width: 6px;
}

.content::-webkit-scrollbar-thumb {
    background: var(--primary-lighter);
    border-radius: 10px;
}

/* Empty state */
.empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    text-align: center;
    color: var(--text-muted);
}

.empty-icon {
    width: 100px;
    height: 100px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--primary-pale);
    border-radius: 50%;
    margin-bottom: 20px;
    color: var(--primary-lighter);
}

.empty-state h2 {
    font-size: 20px;
    font-weight: 600;
    color: var(--text);
    margin-bottom: 6px;
}

.empty-state p {
    font-size: 14px;
    max-width: 320px;
}

/* Content loading */
.content-loading, .content-error {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    gap: 16px;
    color: var(--text-muted);
    font-size: 14px;
    text-align: center;
}

.content-error svg {
    color: #f87171;
}

/* ── Spinner ─────────────────────────────────────────────────────────────── */

.spinner {
    width: 28px;
    height: 28px;
    border: 3px solid var(--primary-pale);
    border-top-color: var(--primary);
    border-radius: 50%;
    animation: spin 0.7s linear infinite;
}

.spinner.large {
    width: 40px;
    height: 40px;
    border-width: 4px;
}

@keyframes spin {
    to { transform: rotate(360deg); }
}

/* ── Assignments Header ──────────────────────────────────────────────────── */

.assignments-header {
    margin-bottom: 20px;
}

.assignments-header-top {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 16px;
    flex-wrap: wrap;
}

.assignments-header h2 {
    font-size: 22px;
    font-weight: 700;
    letter-spacing: -0.02em;
    color: var(--text);
    display: inline;
}

.assignments-subtitle {
    font-size: 13px;
    color: var(--text-secondary);
    margin-top: 4px;
}

/* Copy button */
.btn-copy {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
    border: 1px solid transparent;
    border-radius: var(--radius-sm);
    background: transparent;
    color: var(--text-muted);
    cursor: pointer;
    transition: all 0.2s;
    flex-shrink: 0;
    vertical-align: middle;
}

.btn-copy:hover {
    background: var(--surface-hover);
    border-color: var(--border);
    color: var(--text-secondary);
}

.btn-copy.copied {
    color: var(--success);
}

/* Copy buttons in assignment header */
.btn-copy-name,
.btn-copy-desc {
    margin-left: 4px;
    opacity: 0;
    transition: opacity 0.2s;
}

.assignments-header-top:hover .btn-copy-name,
.assignments-header-top:hover .btn-copy-desc,
.btn-copy-name.copied,
.btn-copy-desc.copied {
    opacity: 1;
}

/* Dynamic membership rule */
.membership-rule {
    margin-top: 8px;
    display: flex;
    align-items: flex-start;
    gap: 8px;
    flex-wrap: wrap;
}

.membership-rule-label {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-muted);
    padding: 3px 6px;
    background: var(--surface-hover);
    border-radius: var(--radius-sm);
    flex-shrink: 0;
    line-height: 1.4;
}

.membership-rule-query {
    font-size: 12px;
    color: var(--text-secondary);
    background: var(--surface);
    border: 1px solid var(--border-light);
    border-radius: var(--radius-sm);
    padding: 4px 8px;
    word-break: break-all;
    line-height: 1.5;
    flex: 1;
    min-width: 0;
}

.membership-rule .btn-copy {
    margin-top: 1px;
}

/* Copy button in card */
.card-actions .btn-copy {
    opacity: 0;
    transition: opacity 0.2s;
}

.assignment-card:hover .card-actions .btn-copy {
    opacity: 1;
}

.assignments-header-actions {
    display: flex;
    align-items: center;
    gap: 6px;
    flex-wrap: wrap;
}

.btn-export {
    display: flex;
    align-items: center;
    gap: 5px;
    padding: 6px 12px;
    border: 1.5px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--surface);
    font-size: 12px;
    font-weight: 500;
    font-family: inherit;
    color: var(--text-secondary);
    cursor: pointer;
    transition: all 0.2s;
}

.btn-export:hover {
    border-color: var(--primary-lighter);
    background: var(--primary-pale);
    color: var(--primary);
}

/* ── Category Tabs ───────────────────────────────────────────────────────── */

.category-tabs {
    display: flex;
    gap: 6px;
    margin-bottom: 24px;
    padding-bottom: 2px;
    overflow-x: auto;
    flex-wrap: wrap;
}

.tab {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 9px 16px;
    border: 1.5px solid var(--border);
    border-radius: 8px;
    background: var(--surface);
    font-size: 13px;
    font-weight: 500;
    font-family: inherit;
    color: var(--text-secondary);
    cursor: pointer;
    transition: all 0.2s ease;
    white-space: nowrap;
}

.tab:hover {
    border-color: var(--primary-lighter);
    color: var(--primary-light);
    background: var(--surface-hover);
}

.tab.active {
    border-color: var(--primary);
    background: var(--primary);
    color: #fff;
    box-shadow: var(--shadow-md);
}

.tab.active svg {
    stroke: #fff;
}

.tab-count {
    font-size: 11px;
    font-weight: 700;
    padding: 1px 7px;
    border-radius: 10px;
    background: var(--primary-pale);
    color: var(--primary-light);
}

.tab.active .tab-count {
    background: rgba(255, 255, 255, 0.25);
    color: #fff;
}

/* ── Platform Filter ─────────────────────────────────────────────────────── */

.platform-filter {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 20px;
    flex-wrap: wrap;
}

.platform-filter-label {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin-right: 4px;
}

.platform-btn {
    padding: 5px 14px;
    border: 1.5px solid var(--border);
    border-radius: 20px;
    background: var(--surface);
    font-size: 12px;
    font-weight: 500;
    font-family: inherit;
    color: var(--text-secondary);
    cursor: pointer;
    transition: all 0.2s ease;
    white-space: nowrap;
}

.platform-btn:hover {
    border-color: var(--primary-lighter);
    color: var(--primary-light);
    background: var(--surface-hover);
}

.platform-btn.active {
    border-color: var(--primary);
    background: var(--primary);
    color: #fff;
}

/* ── Card Grid ───────────────────────────────────────────────────────────── */

.card-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    gap: 14px;
}

/* ── Assignment Card ─────────────────────────────────────────────────────── */

.assignment-card {
    background: var(--surface);
    border: 1.5px solid var(--border);
    border-radius: var(--radius);
    padding: 18px 20px;
    transition: all 0.2s ease;
    position: relative;
    overflow: hidden;
}

.assignment-card::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    width: 4px;
    height: 100%;
    background: linear-gradient(180deg, var(--secondary) 0%, var(--primary) 50%, var(--accent) 100%);
    border-radius: 4px 0 0 4px;
    opacity: 0;
    transition: opacity 0.2s;
}

.assignment-card:hover {
    border-color: var(--primary-lighter);
    box-shadow: var(--shadow-md);
    transform: translateY(-1px);
}

.assignment-card:hover::before {
    opacity: 1;
}

.card-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 8px;
}

.card-name {
    font-size: 14px;
    font-weight: 600;
    color: var(--text);
    margin-bottom: 4px;
    line-height: 1.4;
}

.card-name a {
    color: inherit;
    text-decoration: none;
    transition: color 0.2s;
}

.card-name a:hover {
    color: var(--primary-light);
}

.card-name a .link-icon {
    display: inline;
    margin-left: 4px;
    opacity: 0;
    transition: opacity 0.2s;
    vertical-align: middle;
}

.assignment-card:hover .card-name a .link-icon {
    opacity: 0.6;
}

.card-actions {
    display: flex;
    align-items: center;
    gap: 4px;
    flex-shrink: 0;
}

.btn-preview {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 30px;
    height: 30px;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--surface-hover);
    color: var(--text-secondary);
    cursor: pointer;
    transition: all 0.2s;
}

.btn-preview:hover {
    background: var(--primary-pale);
    border-color: var(--primary-lighter);
    color: var(--primary);
}

.card-desc {
    font-size: 12px;
    color: var(--text-muted);
    margin-bottom: 10px;
    line-height: 1.4;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
}

.card-meta {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
}

.badge {
    display: inline-flex;
    align-items: center;
    font-size: 11px;
    font-weight: 600;
    padding: 3px 9px;
    border-radius: 5px;
    letter-spacing: 0.02em;
}

.badge-include {
    background: var(--include-bg);
    color: var(--include-text);
}

.badge-exclude {
    background: var(--exclude-bg);
    color: var(--exclude-text);
}

.badge-intent {
    background: var(--primary-pale);
    color: var(--primary-light);
}

.badge-filter {
    background: #fef3c7;
    color: #92400e;
}

[data-theme="dark"] .badge-filter {
    background: #422006;
    color: #FCD34D;
}

.badge-inherited {
    background: #E0E7FF;
    color: #3730A3;
}

[data-theme="dark"] .badge-inherited {
    background: #1E1B4B;
    color: #A5B4FC;
}

.badge-orphaned {
    background: #FEF3C7;
    color: #92400E;
}

[data-theme="dark"] .badge-orphaned {
    background: #422006;
    color: #FCD34D;
}

.badge-platform {
    background: #DBEAFE;
    color: #1E40AF;
}

[data-theme="dark"] .badge-platform {
    background: #1E3A5F;
    color: #93C5FD;
}

/* Orphaned card styling */
.orphaned-card::before {
    background: linear-gradient(180deg, #F59E0B 0%, #EF4444 100%);
}

/* Category error banner */
.category-error-banner {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 16px;
    margin-bottom: 16px;
    background: var(--exclude-bg);
    color: var(--exclude-text);
    border: 1px solid currentColor;
    border-radius: var(--radius-sm);
    font-size: 13px;
    line-height: 1.4;
}

.category-error-banner svg {
    flex-shrink: 0;
}

/* Category info banner (non-error notices, e.g. orphaned groups scope) */
.category-info-banner {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 16px;
    margin-bottom: 16px;
    background: #FEF3C7;
    color: #92400E;
    border: 1px solid currentColor;
    border-radius: var(--radius-sm);
    font-size: 13px;
    line-height: 1.4;
}

[data-theme="dark"] .category-info-banner {
    background: #422006;
    color: #FCD34D;
}

.category-info-banner svg {
    flex-shrink: 0;
}

/* Category empty */
.category-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 60px 20px;
    color: var(--text-muted);
    font-size: 14px;
    text-align: center;
    gap: 12px;
}

.category-empty svg {
    color: var(--primary-lighter);
}

/* ── Script Preview Modal ───────────────────────────────────────────────── */

.modal-overlay {
    display: none;
    position: fixed;
    inset: 0;
    z-index: 200;
    background: rgba(15, 13, 26, 0.6);
    backdrop-filter: blur(4px);
    align-items: center;
    justify-content: center;
    padding: 24px;
}

.modal-overlay.active {
    display: flex;
}

.modal {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    width: 100%;
    max-width: 800px;
    max-height: 80vh;
    display: flex;
    flex-direction: column;
    box-shadow: var(--shadow-lg);
    overflow: hidden;
}

.modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-bottom: 1px solid var(--border);
    gap: 12px;
}

.modal-title {
    font-size: 15px;
    font-weight: 600;
    color: var(--text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.modal-subtitle {
    font-size: 11px;
    color: var(--text-muted);
    margin-left: 8px;
    font-weight: 400;
}

.modal-actions {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-shrink: 0;
}

.btn-copy-script {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--surface-hover);
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
    white-space: nowrap;
}

.btn-copy-script:hover {
    background: var(--primary-pale);
    border-color: var(--primary-lighter);
    color: var(--primary);
}

.btn-copy-script.copied {
    background: var(--primary-pale);
    border-color: var(--primary-lighter);
    color: var(--primary);
}

.btn-modal-close {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    border: none;
    border-radius: var(--radius-sm);
    background: transparent;
    color: var(--text-secondary);
    cursor: pointer;
    transition: background 0.2s, color 0.2s;
    flex-shrink: 0;
}

.btn-modal-close:hover {
    background: var(--primary-pale);
    color: var(--text);
}

.modal-body {
    overflow-y: auto;
    padding: 16px 20px;
    flex: 1;
}

.modal-body pre {
    font-family: 'Cascadia Code', 'Fira Code', 'SF Mono', 'Consolas', monospace;
    font-size: 13px;
    line-height: 1.6;
    color: var(--text);
    white-space: pre-wrap;
    word-wrap: break-word;
    margin: 0;
    background: var(--bg);
    border-radius: var(--radius-sm);
    padding: 16px;
    border: 1px solid var(--border);
}

.modal-loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 48px 20px;
    gap: 12px;
    color: var(--text-muted);
    font-size: 13px;
}

/* ── Responsive ──────────────────────────────────────────────────────────── */

@media (max-width: 900px) {
    :root {
        --sidebar-width: 260px;
    }

    .app-header h1 {
        font-size: 15px;
    }

    .content {
        padding: 20px 18px;
    }

    .card-grid {
        grid-template-columns: 1fr;
    }
}

@media (max-width: 640px) {
    .app-layout {
        flex-direction: column;
    }

    .sidebar {
        width: 100%;
        min-width: 100%;
        max-height: 45vh;
        border-right: none;
        border-bottom: 1px solid var(--border);
    }

    .content {
        flex: 1;
        min-height: 0;
    }

    .category-tabs {
        flex-wrap: nowrap;
    }
}

/* ── Setup Screen (SPA mode) ─────────────────────────────────────────────── */

.setup-screen {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    padding: 24px;
    background: var(--bg);
}

.setup-card {
    width: 100%;
    max-width: 480px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 40px 36px;
    box-shadow: var(--shadow-lg);
    text-align: center;
}

.setup-logo {
    width: 80px;
    height: 80px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--primary-pale);
    border-radius: 50%;
    margin: 0 auto 20px;
}

.setup-card h1 {
    font-size: 22px;
    font-weight: 700;
    color: var(--text);
    margin-bottom: 8px;
    letter-spacing: -0.02em;
}

.setup-subtitle {
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.5;
    margin-bottom: 28px;
}

.setup-form {
    text-align: left;
}

.setup-label {
    display: block;
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin-bottom: 6px;
}

.setup-input {
    width: 100%;
    padding: 10px 14px;
    border: 1.5px solid var(--border);
    border-radius: var(--radius-sm);
    font-size: 13px;
    font-family: inherit;
    color: var(--text);
    background: var(--bg);
    outline: none;
    transition: border-color 0.2s, box-shadow 0.2s;
    margin-bottom: 16px;
}

.setup-input:focus {
    border-color: var(--primary);
    box-shadow: 0 0 0 3px var(--focus-ring);
}

.setup-input::placeholder {
    color: var(--text-muted);
}

.setup-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    width: 100%;
    padding: 12px 20px;
    border: none;
    border-radius: var(--radius-sm);
    background: var(--header-gradient);
    color: #fff;
    font-size: 14px;
    font-weight: 600;
    font-family: inherit;
    cursor: pointer;
    transition: opacity 0.2s, box-shadow 0.2s;
    box-shadow: var(--shadow-md);
    margin-top: 4px;
}

.setup-btn:hover {
    opacity: 0.92;
    box-shadow: var(--shadow-lg);
}

.setup-hint {
    font-size: 11px;
    color: var(--text-muted);
    text-align: center;
    margin-top: 14px;
    line-height: 1.5;
}

.setup-help {
    text-align: left;
    margin-top: 24px;
    border-top: 1px solid var(--border);
    padding-top: 20px;
}

.setup-help summary {
    font-size: 13px;
    font-weight: 600;
    color: var(--primary-light);
    cursor: pointer;
    padding: 4px 0;
    transition: color 0.2s;
}

.setup-help summary:hover {
    color: var(--primary);
}

.setup-help ol {
    margin-top: 12px;
    padding-left: 20px;
    font-size: 12.5px;
    color: var(--text-secondary);
    line-height: 1.8;
}

.setup-help ul {
    margin-top: 4px;
    padding-left: 18px;
    font-size: 12px;
    color: var(--text-muted);
}

.setup-help code {
    font-size: 11.5px;
    background: var(--primary-pale);
    color: var(--primary-light);
    padding: 1px 5px;
    border-radius: 3px;
    word-break: break-all;
}
'@)

$script:appJsBytes = [System.Text.Encoding]::UTF8.GetBytes(@'
/* ═══════════════════════════════════════════════════════════════════════════
   Assignment Checker — Frontend (ZeroToTrust Edition)
   Supports dual mode:
     - Backend mode: PowerShell HTTP server at /api/*
     - SPA mode: MSAL.js + direct Graph API calls (for GitHub Pages)
   ═══════════════════════════════════════════════════════════════════════════ */

(function () {
    "use strict";

    // ── DOM references ──────────────────────────────────────────────────
    var groupList       = document.getElementById("groupList");
    var groupSearch     = document.getElementById("groupSearch");
    var groupCount      = document.getElementById("groupCount");
    var sidebarLoading  = document.getElementById("sidebarLoading");
    var sidebarError    = document.getElementById("sidebarError");
    var sidebarErrorMsg = document.getElementById("sidebarErrorMsg");

    var emptyState      = document.getElementById("emptyState");
    var contentLoading  = document.getElementById("contentLoading");
    var contentError    = document.getElementById("contentError");
    var contentErrorMsg = document.getElementById("contentErrorMsg");
    var assignments     = document.getElementById("assignments");

    var selectedGroupName    = document.getElementById("selectedGroupName");
    var selectedGroupDesc    = document.getElementById("selectedGroupDesc");
    var membershipRuleEl     = document.getElementById("membershipRule");
    var membershipRuleQuery  = document.getElementById("membershipRuleQuery");
    var categoryTabs      = document.getElementById("categoryTabs");
    var cardGrid          = document.getElementById("cardGrid");
    var categoryEmpty     = document.getElementById("categoryEmpty");
    var platformFilter    = document.getElementById("platformFilter");

    var connectionBadge = document.getElementById("connectionBadge");
    var badgeDot        = connectionBadge ? connectionBadge.querySelector(".badge-dot") : null;
    var badgeText       = connectionBadge ? connectionBadge.querySelector(".badge-text") : null;

    var scriptModal      = document.getElementById("scriptModal");
    var scriptModalTitle = document.getElementById("scriptModalTitle");
    var scriptModalFile  = document.getElementById("scriptModalFile");
    var scriptModalBody  = document.getElementById("scriptModalBody");
    var btnCopyScript    = document.getElementById("btnCopyScript");
    var copyBtnLabel     = document.getElementById("copyBtnLabel");

    var btnGroupFilter = document.getElementById("btnGroupFilter");

    // Setup screen elements
    var setupScreen   = document.getElementById("setupScreen");
    var appHeader     = document.querySelector(".app-header");
    var appLayout     = document.querySelector(".app-layout");

    // ── State ───────────────────────────────────────────────────────────
    var allGroups          = [];
    var assignedGroupIds   = new Set();
    var groupAssignCounts  = {};   // groupId -> total assignment count
    var groupMemberCounts  = {};   // groupId -> member count (populated lazily)
    var memberCountsToken  = 0;    // invalidates in-flight fetches when groups reload
    var filterAssigned     = true;
    var filterMinCount     = 0;    // min assignment count filter (0 = no filter)
    var filterMaxCount     = 0;    // max assignment count filter (0 = no filter)
    var showAllDevices     = true; // toggle for All Devices assignments
    var showAllUsers       = true; // toggle for All Users assignments
    var activeGroupId      = null;
    var assignmentData     = null;
    var nestedData         = null;  // nested/inherited assignments via parent groups
    var orphanedData       = null;  // orphaned items (no assignments)
    var showNested         = true;  // toggle for nested group assignments
    var activeCategory     = "configurations";
    var activePlatformFilter = null; // null = All, or "Android"/"iOS"/"Windows"/"macOS"

    // Mode: "backend" or "spa"
    var appMode = "backend";

    // Synthetic groups for All Devices / All Users / Orphaned. Defined here
    // (not later in the file) so renderGroupList can never read it before
    // its initializer has run — an earlier definition lower in the IIFE
    // manifested as "Cannot read properties of undefined (reading 'filter')"
    // when renderGroupList fired from an async path.
    var SYNTHETIC_GROUPS = [
        { id: "__allDevices__", displayName: "All Devices", description: "Policies and apps assigned to all devices", _synthetic: true },
        { id: "__allUsers__",   displayName: "All Users",   description: "Policies and apps assigned to all licensed users", _synthetic: true },
        { id: "__orphaned__",   displayName: "Orphaned Items", description: "Items with no assignments — review for deletion", _synthetic: true }
    ];

    // Per-launch backend API secret. The PowerShell script opens the
    // browser at http://localhost:PORT/#k=<secret>. We read the fragment
    // once at startup, scrub it from the address bar, and attach it as
    // X-Backend-Key on every /api/* request. Without this key the local
    // HTTP listener returns 401 for all API routes — so other processes
    // running as the same user cannot piggyback on the Graph session.
    var _backendKey = null;
    (function extractBackendKey() {
        try {
            var m = /^#k=([A-Za-z0-9_\-]+)/.exec(window.location.hash || "");
            if (m) {
                _backendKey = m[1];
                window.history.replaceState(null, "",
                    window.location.pathname + window.location.search);
            }
        } catch (e) { /* ignore */ }
    })();

    // ── SPA session inactivity timeout ──────────────────────────────────
    var SPA_IDLE_TIMEOUT_MS = 30 * 60 * 1000; // 30 minutes
    var _idleTimer = null;

    function resetIdleTimer() {
        if (appMode !== "spa" || !_idleTimer) return;
        clearTimeout(_idleTimer);
        _idleTimer = setTimeout(onIdleTimeout, SPA_IDLE_TIMEOUT_MS);
    }

    function startIdleTimer() {
        if (appMode !== "spa") return;
        _idleTimer = setTimeout(onIdleTimeout, SPA_IDLE_TIMEOUT_MS);
        ["mousemove", "keydown", "click", "scroll", "touchstart"].forEach(function (evt) {
            document.addEventListener(evt, resetIdleTimer, { passive: true });
        });
    }

    function stopIdleTimer() {
        if (_idleTimer) { clearTimeout(_idleTimer); _idleTimer = null; }
        ["mousemove", "keydown", "click", "scroll", "touchstart"].forEach(function (evt) {
            document.removeEventListener(evt, resetIdleTimer);
        });
    }

    function onIdleTimeout() {
        stopIdleTimer();
        alert("Your session has expired due to inactivity. Please sign in again.");
        logout();
    }

    // ── Boot ────────────────────────────────────────────────────────────
    // Hide main app immediately to prevent flash while detectMode runs
    appHeader.style.display = "none";
    appLayout.style.display = "none";

    initTheme();
    detectMode();

    groupSearch.addEventListener("input", function () { renderGroupList(); });
    document.getElementById("btnRetry").addEventListener("click", function () { loadGroups(); });
    var _btnLogout = document.getElementById("btnLogout");
    if (_btnLogout) _btnLogout.addEventListener("click", logout);
    document.getElementById("btnTheme").addEventListener("click", toggleTheme);
    document.getElementById("btnModalClose").addEventListener("click", closeScriptModal);
    if (btnCopyScript) btnCopyScript.addEventListener("click", copyScriptContent);
    btnGroupFilter.addEventListener("click", toggleGroupFilter);

    // Count filter controls
    document.getElementById("btnCountFilter").addEventListener("click", function () {
        var panel = document.getElementById("countFilterPanel");
        panel.style.display = panel.style.display === "none" ? "block" : "none";
    });
    document.getElementById("btnCountApply").addEventListener("click", function () {
        filterMinCount = parseInt(document.getElementById("filterMinCount").value, 10) || 0;
        filterMaxCount = parseInt(document.getElementById("filterMaxCount").value, 10) || 0;
        document.getElementById("countFilterPanel").style.display = "none";
        var btn = document.getElementById("btnCountFilter");
        btn.classList.toggle("active", filterMinCount > 0 || filterMaxCount > 0);
        renderGroupList();
    });
    document.getElementById("btnCountClear").addEventListener("click", function () {
        filterMinCount = 0;
        filterMaxCount = 0;
        document.getElementById("filterMinCount").value = "";
        document.getElementById("filterMaxCount").value = "";
        document.getElementById("countFilterPanel").style.display = "none";
        document.getElementById("btnCountFilter").classList.remove("active");
        renderGroupList();
    });
    // Null-guarded: if this element is missing (e.g. cached old index.html)
    // don't let a null throw abort the rest of init — that would break the
    // setup screen's Sign In button wiring further down.
    var _btnCountExport = document.getElementById("btnCountExport");
    if (_btnCountExport) _btnCountExport.addEventListener("click", exportFilteredGroupsCsv);

    // All Devices / All Users toggles
    document.getElementById("btnShowAllDevices").addEventListener("click", function () {
        showAllDevices = !showAllDevices;
        this.classList.toggle("active", showAllDevices);
        updateCounts();
        renderCards();
    });
    document.getElementById("btnShowAllUsers").addEventListener("click", function () {
        showAllUsers = !showAllUsers;
        this.classList.toggle("active", showAllUsers);
        updateCounts();
        renderCards();
    });

    document.getElementById("btnShowNested").addEventListener("click", function () {
        showNested = !showNested;
        this.classList.toggle("active", showNested);
        updateCounts();
        renderCards();
    });

    // Export CSV
    document.getElementById("btnExportCsv").addEventListener("click", exportCsv);

    scriptModal.addEventListener("click", function (e) {
        if (e.target === scriptModal) closeScriptModal();
    });

    categoryTabs.addEventListener("click", function (e) {
        var tab = e.target.closest(".tab");
        if (!tab) return;
        activeCategory = tab.dataset.category;
        highlightTab();
        if (activeGroupId === "__orphaned__") {
            updateOrphanedCounts();
            renderOrphanedCards();
        } else {
            renderCards();
        }
    });

    platformFilter.addEventListener("click", function (e) {
        var btn = e.target.closest(".platform-btn");
        if (!btn) return;
        activePlatformFilter = btn.dataset.platform || null;
        platformFilter.querySelectorAll(".platform-btn").forEach(function (b) {
            b.classList.toggle("active", b === btn);
        });
        updateOrphanedCounts();
        renderOrphanedCards();
    });

    // Setup screen connect button
    var _btnSetupConnect = document.getElementById("btnSetupConnect");
    if (_btnSetupConnect) _btnSetupConnect.addEventListener("click", setupConnect);

    // ── Mode Detection ──────────────────────────────────────────────────

    async function detectMode() {
        // Try to reach the PowerShell backend via the /api/status endpoint.
        // If no backend key is present in the URL fragment, skip the probe
        // entirely — the backend will reject us anyway, and the request
        // might come from a misrouted SPA-mode load.
        if (_backendKey) {
            try {
                var resp = await fetch("/api/status", {
                    headers: { "X-Backend-Key": _backendKey }
                });
                if (resp.ok) {
                    appMode = "backend";
                    showApp();
                    loadGroups();
                    return;
                }
            } catch (e) {
                // Backend not available — fall through to SPA mode
            }
        }

        // SPA mode
        appMode = "spa";

        // Security: warn if SPA mode is running over HTTP (excluding localhost)
        if (window.location.protocol === "http:" &&
            window.location.hostname !== "localhost" &&
            window.location.hostname !== "127.0.0.1") {
            console.warn("Security warning: running over HTTP. OAuth tokens may be intercepted. Use HTTPS.");
            alert("Security warning: this page is served over HTTP. Your authentication tokens could be intercepted by an attacker. Please use HTTPS.");
        }

        var savedClientId = localStorage.getItem("iac_clientId");
        var savedTenantId = localStorage.getItem("iac_tenantId");

        if (savedClientId && savedTenantId) {
            try {
                // Init MSAL, handle any pending redirect, check for cached account
                var account = await GraphClient.init(savedClientId, savedTenantId);
                if (account) {
                    showApp();
                    setConnection("connected", account.username || "Connected");
                    startIdleTimer();
                    loadGroups();
                    return;
                }
            } catch (err) {
                console.error("MSAL init error:", err);
            }
        }

        // Show setup screen
        showSetup(savedClientId, savedTenantId);
    }

    // ── Setup Screen ────────────────────────────────────────────────────

    function showSetup(savedClientId, savedTenantId) {
        if (setupScreen) setupScreen.style.display = "flex";
        appHeader.style.display   = "none";
        appLayout.style.display   = "none";

        // Pre-fill saved values
        var tenantInput  = document.getElementById("setupTenantId");
        var clientInput  = document.getElementById("setupClientId");
        if (tenantInput && savedTenantId) tenantInput.value = savedTenantId;
        if (clientInput && savedClientId) clientInput.value = savedClientId;
    }

    function hideSetup() {
        if (setupScreen) setupScreen.style.display = "none";
        appHeader.style.display   = "";
        appLayout.style.display   = "";
    }

    function showApp() {
        hideSetup();
        appHeader.style.display = "";
        appLayout.style.display = "";
    }

    var GUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    var DOMAIN_RE = /^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/i;

    async function setupConnect() {
        var tenantId = document.getElementById("setupTenantId").value.trim();
        var clientId = document.getElementById("setupClientId").value.trim();

        if (!tenantId || !clientId) {
            alert("Please enter both Tenant ID and Client ID.");
            return;
        }

        // Length limits to prevent abuse
        if (tenantId.length > 253 || clientId.length > 36) {
            alert("Tenant ID must be at most 253 characters and Client ID must be at most 36 characters.");
            return;
        }

        // Validate Client ID is a GUID
        if (!GUID_RE.test(clientId)) {
            alert("Client ID must be a valid GUID (e.g. 12345678-abcd-1234-abcd-123456789abc).");
            return;
        }

        // Validate Tenant ID is a GUID or a domain name
        if (!GUID_RE.test(tenantId) && !DOMAIN_RE.test(tenantId)) {
            alert("Tenant ID must be a valid GUID or domain (e.g. contoso.onmicrosoft.com).");
            return;
        }

        // If tenant or client changed, reset MSAL so a fresh instance is created
        var prevTenant = localStorage.getItem("iac_tenantId");
        var prevClient = localStorage.getItem("iac_clientId");
        if (GraphClient.isInitialised() && (prevTenant !== tenantId || prevClient !== clientId)) {
            GraphClient.reset();
        }

        // Save to localStorage so we can pick up after redirect
        localStorage.setItem("iac_tenantId", tenantId);
        localStorage.setItem("iac_clientId", clientId);

        try {
            // Init MSAL (idempotent — reuses if already initialised)
            await GraphClient.init(clientId, tenantId);

            // Redirect to Microsoft login. On return, detectMode() picks up the token.
            await GraphClient.signIn();
        } catch (err) {
            console.error("Sign-in failed:", err);
            alert("Sign-in failed: " + (err.message || err));
        }
    }

    // ── Dark mode ─────────────────────────────────────────────────────

    function initTheme() {
        var saved = localStorage.getItem("theme");
        if (saved === "dark" || (!saved && window.matchMedia("(prefers-color-scheme: dark)").matches)) {
            document.documentElement.setAttribute("data-theme", "dark");
        }
        updateThemeIcon();
    }

    function toggleTheme() {
        var isDark = document.documentElement.getAttribute("data-theme") === "dark";
        if (isDark) {
            document.documentElement.removeAttribute("data-theme");
            localStorage.setItem("theme", "light");
        } else {
            document.documentElement.setAttribute("data-theme", "dark");
            localStorage.setItem("theme", "dark");
        }
        updateThemeIcon();
    }

    function updateThemeIcon() {
        var isDark = document.documentElement.getAttribute("data-theme") === "dark";
        document.getElementById("iconSun").style.display  = isDark ? "block" : "none";
        document.getElementById("iconMoon").style.display = isDark ? "none"  : "block";
    }

    // ── API helpers ─────────────────────────────────────────────────────

    async function apiFetch(url, options) {
        options = options || {};
        var headers = {};
        // Merge caller-provided headers without mutating their object
        if (options.headers) {
            Object.keys(options.headers).forEach(function (k) { headers[k] = options.headers[k]; });
        }
        if (_backendKey) headers["X-Backend-Key"] = _backendKey;
        var fetchInit = {
            method: options.method || "GET",
            headers: headers
        };
        if (options.body !== undefined) fetchInit.body = options.body;
        var resp = await fetch(url, fetchInit);
        if (!resp.ok) {
            var body = await resp.json().catch(function () { return {}; });
            if (resp.status === 401 && body && body.expired) {
                onBackendSessionExpired();
            }
            throw new Error(body.error || "HTTP " + resp.status);
        }
        return resp.json();
    }

    var _backendSessionExpiredShown = false;
    function onBackendSessionExpired() {
        if (_backendSessionExpiredShown) return;
        _backendSessionExpiredShown = true;
        stopIdleTimer();
        setConnection("error", "Session expired");
        alert("Your backend session expired due to inactivity. " +
              "Please close this tab and restart the script to sign in again.");
    }

    // ── Load groups ─────────────────────────────────────────────────────

    async function loadGroups() {
        sidebarLoading.style.display = "flex";
        sidebarError.style.display   = "none";
        groupList.innerHTML          = "";

        try {
            var groups, assignedIds;

            if (appMode === "spa") {
                var results = await Promise.all([
                    GraphClient.getAllGroups(),
                    GraphClient.getAssignedGroupIds().catch(function () { return { ids: [], counts: {} }; })
                ]);
                groups = results[0];
                assignedIds = results[1].ids || results[1];
                groupAssignCounts = results[1].counts || {};
            } else {
                var backendResults = await Promise.all([
                    apiFetch("/api/groups"),
                    apiFetch("/api/assigned-group-ids").catch(function () { return []; })
                ]);
                groups = backendResults[0];
                var backendIdData = backendResults[1];
                assignedIds = backendIdData.ids || backendIdData;
                groupAssignCounts = backendIdData.counts || {};
            }

            if (!Array.isArray(groups)) {
                console.error("Unexpected /api/groups response (not an array):", groups);
                throw new Error("Server returned an unexpected groups response. Check the PowerShell console for errors.");
            }
            allGroups = groups;
            assignedGroupIds = new Set(Array.isArray(assignedIds) ? assignedIds : Object.keys(groupAssignCounts));
            // Reset any previously-fetched counts so a reload doesn't show
            // stale data while the new batch is in flight.
            groupMemberCounts = {};
            renderGroupList();
            setConnection("connected", appMode === "spa" ? (GraphClient.getAccount()?.username || "Connected") : "Connected");
            // Fetch member counts in the background — the list is already
            // usable and counts stream in as batches complete.
            loadGroupMemberCounts();
        } catch (err) {
            console.error("Failed to load groups:", err);
            sidebarErrorMsg.textContent = "Failed to load groups. " + (err.message || "Please check your connection and try again.");
            sidebarError.style.display  = "flex";
            setConnection("error", "Disconnected");
        } finally {
            sidebarLoading.style.display = "none";
        }
    }

    // ── Filter logic shared by renderGroupList and the CSV exporter ─────
    //
    // Kept in one place so the sidebar list and the export always agree on
    // which groups are "in view" — search box, assigned-only toggle, and
    // the min/max assignment-count range are all applied here.

    function getFilteredGroups() {
        var query = groupSearch.value.trim().toLowerCase();
        var filtered = allGroups;

        if (filterAssigned && assignedGroupIds.size > 0) {
            filtered = filtered.filter(function (g) { return assignedGroupIds.has(g.id); });
        }

        if (filterMinCount > 0 || filterMaxCount > 0) {
            filtered = filtered.filter(function (g) {
                var cnt = groupAssignCounts[g.id] || 0;
                if (filterMinCount > 0 && cnt < filterMinCount) return false;
                if (filterMaxCount > 0 && cnt > filterMaxCount) return false;
                return true;
            });
        }

        if (query) {
            filtered = filtered.filter(function (g) {
                return (g.displayName || "").toLowerCase().indexOf(query) !== -1 ||
                       (g.description || "").toLowerCase().indexOf(query) !== -1;
            });
        }

        return filtered;
    }

    // ── Render group list (with search filter) ──────────────────────────

    function renderGroupList() {
        var query = groupSearch.value.trim().toLowerCase();
        var filtered = getFilteredGroups();

        groupList.innerHTML = "";

        filtered.forEach(function (g) {
            var li = document.createElement("li");
            li.className = "group-item" + (g.id === activeGroupId ? " active" : "");
            li.dataset.id = g.id;

            var groupType = getGroupType(g);
            var assignCount = groupAssignCounts[g.id] || 0;
            var gName = g.displayName || "Unnamed Group";
            var memberBadge = buildMemberBadge(g.id);

            li.innerHTML =
                '<div class="group-item-header">' +
                    '<div class="group-item-name" title="' + escapeHtml(gName) + '">' + escapeHtml(gName) + '</div>' +
                    '<div class="group-item-copy"></div>' +
                '</div>' +
                (g.description ? '<div class="group-item-desc" title="' + escapeHtml(g.description) + '">' + escapeHtml(g.description) + '</div>' : '') +
                '<div class="group-item-badges">' +
                    '<span class="group-item-type">' + escapeHtml(groupType) + '</span>' +
                    (assignCount > 0 ? '<span class="group-item-count" title="Total assignments">' + assignCount + ' assignment' + (assignCount !== 1 ? 's' : '') + '</span>' : '') +
                    memberBadge +
                '</div>';

            li.querySelector(".group-item-copy").appendChild(createCopyButton(function () { return gName; }));
            li.addEventListener("click", function () { selectGroup(g); });
            groupList.appendChild(li);
        });

        // Render synthetic groups in the sticky bottom section
        var stickyList = document.getElementById("groupListSticky");
        if (stickyList) {
            stickyList.innerHTML = "";
            var syntheticFiltered = SYNTHETIC_GROUPS.filter(function (g) {
                return !query || (g.displayName || "").toLowerCase().indexOf(query) !== -1;
            });

            syntheticFiltered.forEach(function (g) {
                var li = document.createElement("li");
                li.className = "group-item group-item-synthetic" + (g.id === activeGroupId ? " active" : "");
                li.dataset.id = g.id;

                var icon;
                if (g.id === "__allDevices__") {
                    icon = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>';
                } else if (g.id === "__orphaned__") {
                    icon = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>';
                } else {
                    icon = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>';
                }

                li.innerHTML =
                    '<div class="group-item-name">' + icon + ' ' + escapeHtml(g.displayName) + '</div>';

                li.addEventListener("click", function () { selectGroup(g); });
                stickyList.appendChild(li);
            });
        }

        groupCount.textContent = filtered.length;
    }

    function getGroupType(group) {
        var types = group.groupTypes || [];
        if (types.indexOf("DynamicMembership") !== -1) return "Dynamic";
        if (group.membershipRule) return "Dynamic";
        return "Assigned";
    }

    // ── Member count badge ──────────────────────────────────────────────
    //
    // Returns the HTML for a group's member-count badge. When the count
    // hasn't been resolved yet we render a dimmed placeholder so users can
    // see that counts are still loading instead of a blank space.

    function buildMemberBadge(groupId) {
        if (Object.prototype.hasOwnProperty.call(groupMemberCounts, groupId)) {
            var n = groupMemberCounts[groupId];
            var cls = "group-item-members" + (n === 0 ? " group-item-members-empty" : "");
            var label = n + " member" + (n !== 1 ? "s" : "");
            return '<span class="' + cls + '" title="Group members">' + label + '</span>';
        }
        return '<span class="group-item-members group-item-members-loading" title="Loading member count…">…</span>';
    }

    // Kick off background fetching of member counts for every loaded group.
    // Uses a token to cancel stale fetches if the user reloads before this
    // completes. We fetch for ALL groups so users can scroll the unfiltered
    // list and still see counts; the Graph $batch endpoint keeps this
    // reasonably cheap.

    async function loadGroupMemberCounts() {
        memberCountsToken += 1;
        var myToken = memberCountsToken;
        var ids = allGroups.map(function (g) { return g.id; }).filter(Boolean);
        if (ids.length === 0) return;

        function applyPartial(partial) {
            if (myToken !== memberCountsToken) return;
            Object.keys(partial).forEach(function (k) {
                groupMemberCounts[k] = partial[k];
            });
            renderGroupList();
        }

        try {
            if (appMode === "spa") {
                await GraphClient.getGroupMemberCounts(ids, applyPartial);
            } else {
                // Backend fetches server-side in 20-group batches.
                var data = await apiFetch("/api/group-member-counts", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ ids: ids })
                });
                if (myToken !== memberCountsToken) return;
                applyPartial((data && data.counts) || {});
            }
        } catch (err) {
            console.warn("Failed to load member counts:", err);
        }
    }

    // ── Group filter toggle ─────────────────────────────────────────────

    function toggleGroupFilter() {
        filterAssigned = !filterAssigned;
        btnGroupFilter.classList.toggle("active", filterAssigned);
        btnGroupFilter.title = filterAssigned
            ? "Showing groups with assignments \u2014 click to show all"
            : "Showing all groups \u2014 click to filter to assigned only";
        renderGroupList();
    }

    // ── Populate group header with copy buttons and dynamic rule ───────

    function populateGroupHeader(group) {
        var name = group.displayName || "Unnamed Group";
        var desc = group.description || "";
        var rule = group.membershipRule || "";

        // Group name with copy button
        selectedGroupName.textContent = name;
        // Remove any previous copy button
        var existingCopy = selectedGroupName.parentNode.querySelector(".btn-copy-name");
        if (existingCopy) existingCopy.remove();
        var nameCopy = createCopyButton(function () { return name; });
        nameCopy.classList.add("btn-copy-name");
        selectedGroupName.parentNode.insertBefore(nameCopy, selectedGroupName.nextSibling);

        // Description with copy button
        selectedGroupDesc.textContent = desc;
        var existingDescCopy = selectedGroupDesc.parentNode.querySelector(".btn-copy-desc");
        if (existingDescCopy) existingDescCopy.remove();
        if (desc) {
            var descCopy = createCopyButton(function () { return desc; });
            descCopy.classList.add("btn-copy-desc");
            selectedGroupDesc.parentNode.insertBefore(descCopy, selectedGroupDesc.nextSibling);
        }

        // Dynamic membership rule
        if (membershipRuleEl) {
            if (rule) {
                membershipRuleQuery.textContent = rule;
                membershipRuleEl.style.display = "";
                // Copy button for rule
                var existingRuleCopy = membershipRuleEl.querySelector(".btn-copy");
                if (existingRuleCopy) existingRuleCopy.remove();
                membershipRuleEl.appendChild(createCopyButton(function () { return rule; }));
            } else {
                membershipRuleEl.style.display = "none";
            }
        }
    }

    // ── Select a group ──────────────────────────────────────────────────

    async function selectGroup(group) {
        activeGroupId = group.id;
        nestedData = null;
        orphanedData = null;
        // Show/hide the Groups tab (only relevant in Orphaned Items view)
        var groupsTab = categoryTabs.querySelector('[data-category="groups"]');
        if (groupsTab) groupsTab.style.display = (group.id === "__orphaned__") ? "" : "none";

        if (group.id !== "__orphaned__") {
            activePlatformFilter = null;
            platformFilter.style.display = "none";
            platformFilter.querySelectorAll(".platform-btn").forEach(function (b) {
                b.classList.toggle("active", !b.dataset.platform);
            });
        }
        renderGroupList();
        showPanel("loading");

        try {
            if (group._synthetic && group.id === "__orphaned__") {
                // Orphaned items view
                if (appMode === "spa") {
                    orphanedData = await GraphClient.getOrphanedItems(allGroups, assignedGroupIds);
                } else {
                    orphanedData = await apiFetch("/api/orphaned-items");
                }
                assignmentData = null;
                populateGroupHeader(group);
                updateOrphanedCounts();
                activeCategory = getFirstNonEmptyOrphanedCategory() || "configurations";
                highlightTab();
                platformFilter.style.display = "flex";
                renderOrphanedCards();
                showPanel("assignments");
                return;
            } else if (group._synthetic) {
                // Synthetic group: fetch by target type
                var targetType = group.id === "__allDevices__"
                    ? "#microsoft.graph.allDevicesAssignmentTarget"
                    : "#microsoft.graph.allLicensedUsersAssignmentTarget";
                var label = group.id === "__allDevices__" ? "All Devices" : "All Users";

                if (appMode === "spa") {
                    assignmentData = await GraphClient.getAssignmentsByTargetType(targetType, label);
                } else {
                    assignmentData = await apiFetch("/api/assignments-by-target?type=" + encodeURIComponent(targetType));
                }
            } else if (appMode === "spa") {
                var groupResults = await Promise.all([
                    GraphClient.getAssignmentsForGroup(group.id),
                    GraphClient.getNestedAssignments(group.id).catch(function () { return null; })
                ]);
                assignmentData = groupResults[0];
                nestedData = groupResults[1];
            } else {
                var backendGroupResults = await Promise.all([
                    apiFetch("/api/groups/" + group.id + "/assignments"),
                    apiFetch("/api/groups/" + group.id + "/nested-assignments").catch(function () { return null; })
                ]);
                assignmentData = backendGroupResults[0];
                nestedData = backendGroupResults[1];
            }

            populateGroupHeader(group);
            updateCounts();
            activeCategory = getFirstNonEmptyCategory() || "configurations";
            highlightTab();
            renderCards();
            showPanel("assignments");
        } catch (err) {
            console.error("Failed to load assignments:", err);
            // Try to show partial results if we got any data at all
            if (assignmentData) {
                populateGroupHeader(group);
                updateCounts();
                activeCategory = getFirstNonEmptyCategory() || "configurations";
                highlightTab();
                renderCards();
                showPanel("assignments");
            } else {
                contentErrorMsg.textContent = err.message || "Failed to load assignments.";
                showPanel("error");
            }
        }
    }

    // ── Panel visibility ────────────────────────────────────────────────

    function showPanel(panel) {
        emptyState.style.display     = panel === "empty"       ? "flex" : "none";
        contentLoading.style.display = panel === "loading"     ? "flex" : "none";
        contentError.style.display   = panel === "error"       ? "flex" : "none";
        assignments.style.display    = panel === "assignments" ? "block" : "none";
    }

    // ── Tabs & counts ───────────────────────────────────────────────────

    var CATEGORIES = [
        { key: "configurations",  countId: "countConfigurations"  },
        { key: "compliance",      countId: "countCompliance"      },
        { key: "settingsCatalog", countId: "countSettingsCatalog" },
        { key: "applications",    countId: "countApplications"    },
        { key: "scripts",         countId: "countScripts"         },
        { key: "remediations",    countId: "countRemediations"    },
        { key: "groups",           countId: "countGroups"          }
    ];

    function getFilteredItems(key) {
        var items = assignmentData[key] || [];
        var filtered = items.filter(function (item) {
            if (!showAllDevices && item.assignmentType === "All Devices") return false;
            if (!showAllUsers && item.assignmentType === "All Users") return false;
            return true;
        });

        // Merge nested/inherited assignments if available and enabled
        if (showNested && nestedData && nestedData[key]) {
            var nestedItems = nestedData[key] || [];
            // Avoid duplicates: only add nested items not already in the direct list
            var directIds = {};
            filtered.forEach(function (item) {
                directIds[item.id + "|" + (item.assignmentType || "")] = true;
            });
            nestedItems.forEach(function (item) {
                var dedupKey = item.id + "|" + (item.assignmentType || "");
                if (!directIds[dedupKey]) {
                    filtered.push(item);
                }
            });
        }

        return filtered;
    }

    function updateCounts() {
        if (!assignmentData) return;
        var errors = assignmentData._errors || {};
        CATEGORIES.forEach(function (c) {
            var el = document.getElementById(c.countId);
            if (el) {
                if (errors[c.key]) {
                    el.textContent = "!";
                    el.title = "Failed to load — click to retry";
                } else {
                    el.textContent = getFilteredItems(c.key).length;
                    el.title = "";
                }
            }
        });
    }

    function highlightTab() {
        categoryTabs.querySelectorAll(".tab").forEach(function (t) {
            t.classList.toggle("active", t.dataset.category === activeCategory);
        });
    }

    function getFirstNonEmptyCategory() {
        if (!assignmentData) return null;
        for (var i = 0; i < CATEGORIES.length; i++) {
            if (getFilteredItems(CATEGORIES[i].key).length > 0) return CATEGORIES[i].key;
        }
        return null;
    }

    // ── Intune deep links ───────────────────────────────────────────────

    var INTUNE_BASE = "https://intune.microsoft.com/";

    function getIntuneUrl(category, itemId) {
        var encodedId = itemId ? encodeURIComponent(itemId) : "";
        switch (category) {
            case "configurations":
                return INTUNE_BASE + "#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configuration";
            case "compliance":
                return INTUNE_BASE + "#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance";
            case "settingsCatalog":
                return INTUNE_BASE + "#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configuration";
            case "applications":
                return INTUNE_BASE + "#view/Microsoft_Intune_Apps/SettingsMenu/appId/" + encodedId;
            case "scripts":
                return INTUNE_BASE + "#view/Microsoft_Intune_DeviceSettings/ConfigureWMPolicyMenuBlade/policyId/" + encodedId + "/policyType~/0";
            case "remediations":
                return INTUNE_BASE + "#view/Microsoft_Intune_Enrollment/UNTRemediations";
            case "groups":
                return "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/Overview/groupId/" + encodedId;
        }
        return null;
    }

    // ── Render assignment cards ─────────────────────────────────────────

    function renderCards() {
        if (!assignmentData) return;

        var errors = assignmentData._errors || {};
        var categoryError = errors[activeCategory];
        var items = getFilteredItems(activeCategory);
        cardGrid.innerHTML = "";

        // Show error banner if this category failed
        var existingBanner = document.getElementById("categoryErrorBanner");
        if (existingBanner) existingBanner.remove();

        if (categoryError) {
            var banner = document.createElement("div");
            banner.id = "categoryErrorBanner";
            banner.className = "category-error-banner";
            banner.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>' +
                '<span>Failed to load this category. The Graph API returned an error — this is usually temporary. Try selecting the group again.</span>';
            cardGrid.parentNode.insertBefore(banner, cardGrid);
        }

        if (items.length === 0) {
            cardGrid.style.display     = "none";
            categoryEmpty.style.display = categoryError ? "none" : "flex";
            return;
        }

        cardGrid.style.display      = "grid";
        categoryEmpty.style.display = "none";

        items.forEach(function (item) {
            var card = document.createElement("div");
            card.className = "assignment-card";

            var badges = [];
            if (item.assignmentType) {
                var isExclude = item.assignmentType === "Exclude";
                badges.push(
                    '<span class="badge ' + (isExclude ? "badge-exclude" : "badge-include") + '">' + escapeHtml(item.assignmentType) + '</span>'
                );
            }
            if (item.intent) {
                badges.push('<span class="badge badge-intent">' + escapeHtml(item.intent) + '</span>');
            }
            if (item.filterType && item.filterType !== "none") {
                badges.push('<span class="badge badge-filter">Filter: ' + escapeHtml(item.filterType) + '</span>');
            }
            if (item.inheritedFrom) {
                badges.push('<span class="badge badge-inherited" title="Inherited via nested group membership">Inherited: ' + escapeHtml(item.inheritedFrom) + '</span>');
            }
            if (item.platform) {
                badges.push('<span class="badge badge-platform">' + escapeHtml(item.platform) + '</span>');
            }

            var url = getIntuneUrl(activeCategory, item.id);
            var linkIcon = '<svg class="link-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>';
            var nameHtml = url
                ? '<a href="' + escapeHtml(url) + '" target="_blank" rel="noopener noreferrer" title="Open in Intune">' + escapeHtml(item.displayName || "Unnamed") + linkIcon + '</a>'
                : escapeHtml(item.displayName || "Unnamed");

            var showPreview = activeCategory === "scripts" && item.id;
            var previewBtn = showPreview
                ? '<button class="btn-preview" data-script-id="' + escapeHtml(item.id) + '" data-script-name="' + escapeHtml(item.displayName || "Script") + '" title="View script content"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg></button>'
                : "";

            card.innerHTML =
                '<div class="card-header">' +
                    '<div class="card-name">' + nameHtml + '</div>' +
                    '<div class="card-actions">' + previewBtn + '</div>' +
                '</div>' +
                (item.description ? '<div class="card-desc">' + escapeHtml(item.description) + '</div>' : '') +
                '<div class="card-meta">' + badges.join("") + '</div>';

            // Add copy button to card actions
            var cardActions = card.querySelector(".card-actions");
            var itemName = item.displayName || "Unnamed";
            cardActions.appendChild(createCopyButton(function () { return itemName; }));

            if (showPreview) {
                var btn = card.querySelector(".btn-preview");
                if (btn) {
                    btn.addEventListener("click", function (e) {
                        e.stopPropagation();
                        openScriptModal(item.id, item.displayName || "Script");
                    });
                }
            }

            cardGrid.appendChild(card);
        });
    }

    // ── Orphaned items helpers ─────────────────────────────────────────

    function getFilteredOrphanedItems(key) {
        var items = orphanedData[key] || [];
        if (key === "groups") return items; // groups don't have platforms
        if (!activePlatformFilter) return items;
        return items.filter(function (item) {
            return item.platform === activePlatformFilter;
        });
    }

    function updateOrphanedCounts() {
        if (!orphanedData) return;
        var errors = orphanedData._errors || {};
        CATEGORIES.forEach(function (c) {
            var el = document.getElementById(c.countId);
            if (el) {
                if (errors[c.key]) {
                    el.textContent = "!";
                    el.title = "Failed to load — click to retry";
                } else {
                    el.textContent = getFilteredOrphanedItems(c.key).length;
                    el.title = "";
                }
            }
        });
    }

    function getFirstNonEmptyOrphanedCategory() {
        if (!orphanedData) return null;
        for (var i = 0; i < CATEGORIES.length; i++) {
            if ((orphanedData[CATEGORIES[i].key] || []).length > 0) return CATEGORIES[i].key;
        }
        return null;
    }

    function renderOrphanedCards() {
        if (!orphanedData) return;

        var errors = orphanedData._errors || {};
        var categoryError = errors[activeCategory];
        var items = getFilteredOrphanedItems(activeCategory);
        cardGrid.innerHTML = "";

        // Show error banner if this category failed
        var existingBanner = document.getElementById("categoryErrorBanner");
        if (existingBanner) existingBanner.remove();

        if (categoryError) {
            var banner = document.createElement("div");
            banner.id = "categoryErrorBanner";
            banner.className = "category-error-banner";
            banner.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>' +
                '<span>Failed to load this category.</span>';
            cardGrid.parentNode.insertBefore(banner, cardGrid);
        }

        // "Orphaned" Groups are only orphaned from an Intune-assignment perspective.
        // Warn before the user treats this list as safe-to-delete.
        var existingGroupsNotice = document.getElementById("groupsScopeNotice");
        if (existingGroupsNotice) existingGroupsNotice.remove();

        if (activeCategory === "groups") {
            var notice = document.createElement("div");
            notice.id = "groupsScopeNotice";
            notice.className = "category-info-banner";
            notice.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>' +
                '<span><strong>Heads up:</strong> &ldquo;Orphaned&rdquo; here means these groups have no Intune assignments. They may still be used elsewhere in Microsoft 365 (Exchange, SharePoint, Teams, licensing, Conditional Access, etc.). Review in the Entra admin center before deleting.</span>';
            cardGrid.parentNode.insertBefore(notice, cardGrid);
        }

        if (items.length === 0) {
            cardGrid.style.display     = "none";
            categoryEmpty.style.display = categoryError ? "none" : "flex";
            return;
        }

        cardGrid.style.display      = "grid";
        categoryEmpty.style.display = "none";

        items.forEach(function (item) {
            var card = document.createElement("div");
            card.className = "assignment-card orphaned-card";

            var url = getIntuneUrl(activeCategory, item.id);
            var linkIcon = '<svg class="link-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>';
            var nameHtml = url
                ? '<a href="' + escapeHtml(url) + '" target="_blank" rel="noopener noreferrer" title="Open in Intune">' + escapeHtml(item.displayName || "Unnamed") + linkIcon + '</a>'
                : escapeHtml(item.displayName || "Unnamed");

            card.innerHTML =
                '<div class="card-header">' +
                    '<div class="card-name">' + nameHtml + '</div>' +
                    '<div class="card-actions"></div>' +
                '</div>' +
                (item.description ? '<div class="card-desc">' + escapeHtml(item.description) + '</div>' : '') +
                '<div class="card-meta">' +
                    (activeCategory === "groups" && item.groupType
                        ? '<span class="badge badge-platform">' + escapeHtml(item.groupType) + '</span>'
                        : (item.platform ? '<span class="badge badge-platform">' + escapeHtml(item.platform) + '</span>' : '')) +
                    '<span class="badge badge-orphaned">No Assignments</span>' +
                '</div>';

            var cardActions = card.querySelector(".card-actions");
            var itemName = item.displayName || "Unnamed";
            cardActions.appendChild(createCopyButton(function () { return itemName; }));

            cardGrid.appendChild(card);
        });
    }

    function exportOrphanedCsv() {
        if (!orphanedData) return;

        // Group ID column is populated for the "groups" category (orphaned
        // groups have a real Graph ID worth keeping); blank for orphaned
        // policies/apps/scripts since those IDs aren't group IDs.
        var rows = [["Category", "Group ID", "Name", "Description", "Platform / Group Type"]];

        CATEGORIES.forEach(function (c) {
            var items = getFilteredOrphanedItems(c.key);
            var label = c.key.replace(/([A-Z])/g, " $1").replace(/^./, function (s) { return s.toUpperCase(); });
            items.forEach(function (item) {
                rows.push([
                    label,
                    c.key === "groups" ? exportableGroupId(item.id) : "",
                    item.displayName || "",
                    item.description || "",
                    c.key === "groups" ? (item.groupType || "") : (item.platform || "")
                ]);
            });
        });

        var csv = rows.map(function (row) {
            return row.map(function (cell) {
                var s = String(cell).trim();
                if (/^[=+\-@\t\r]/.test(s)) { s = "'" + s; }
                s = s.replace(/"/g, '""');
                return '"' + s + '"';
            }).join(",");
        }).join("\r\n");

        var blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
        var url = URL.createObjectURL(blob);
        var a = document.createElement("a");
        a.href = url;
        a.download = "orphaned_items.csv";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    // ── Script preview modal ────────────────────────────────────────────

    async function openScriptModal(scriptId, scriptName) {
        scriptModalTitle.textContent = scriptName;
        scriptModalFile.textContent  = "";
        scriptModalBody.innerHTML    = '<div class="modal-loading"><div class="spinner"></div><p>Loading script content...</p></div>';
        copyBtnLabel.textContent = "Copy Script";
        btnCopyScript.classList.remove("copied");
        scriptModal.classList.add("active");

        try {
            var data;
            if (appMode === "spa") {
                data = await GraphClient.getScriptContent(scriptId);
            } else {
                data = await apiFetch("/api/scripts/" + scriptId + "/content");
            }
            scriptModalFile.textContent = data.fileName ? "(" + data.fileName + ")" : "";

            if (data.content) {
                var pre = document.createElement("pre");
                pre.textContent = data.content;
                scriptModalBody.innerHTML = "";
                scriptModalBody.appendChild(pre);
            } else {
                scriptModalBody.innerHTML = '<p style="color:var(--text-muted);text-align:center;padding:32px;">No script content available.</p>';
            }
        } catch (err) {
            console.error("Failed to load script content:", err);
            scriptModalBody.innerHTML = '<p style="color:#f87171;text-align:center;padding:32px;">' + escapeHtml(err.message || "Failed to load script content.") + '</p>';
        }
    }

    function closeScriptModal() {
        scriptModal.classList.remove("active");
    }

    function copyScriptContent() {
        var pre = scriptModalBody.querySelector("pre");
        if (!pre) return;
        navigator.clipboard.writeText(pre.textContent).then(function () {
            copyBtnLabel.textContent = "Copied!";
            btnCopyScript.classList.add("copied");
            setTimeout(function () {
                copyBtnLabel.textContent = "Copy Script";
                btnCopyScript.classList.remove("copied");
            }, 2000);
        });
    }

    // ── Connection badge ────────────────────────────────────────────────

    function setConnection(state, text) {
        if (badgeDot) badgeDot.className = "badge-dot " + state;
        if (badgeText) badgeText.textContent = text;
    }

    // ── CSV helpers ─────────────────────────────────────────────────────
    //
    // Synthetic group IDs (__allDevices__, __allUsers__, __orphaned__) are
    // internal placeholders with no Graph-side equivalent — never write them
    // to an export, leave the column blank instead.

    function exportableGroupId(id) {
        if (!id || typeof id !== "string") return "";
        if (id.indexOf("__") === 0) return "";
        return id;
    }

    // ── Export the current filtered group list to CSV ──────────────────
    //
    // Dumps whatever the sidebar is currently showing — honours the search
    // box, assigned-only toggle, and the min/max assignment-count filter.
    // Columns: Group Name, Group Type, Number of Assignments, Member Count.
    // Member count is left blank for groups whose count hasn't loaded yet
    // (rather than writing a misleading 0).

    function exportFilteredGroupsCsv() {
        var filtered = getFilteredGroups();
        if (!filtered.length) {
            alert("No groups match the current filter — nothing to export.");
            return;
        }

        var rows = [["Group ID", "Group Name", "Group Type", "Number of Assignments", "Member Count"]];
        filtered.forEach(function (g) {
            var assignCount = groupAssignCounts[g.id] || 0;
            var memberCount = Object.prototype.hasOwnProperty.call(groupMemberCounts, g.id)
                ? groupMemberCounts[g.id]
                : "";
            rows.push([
                exportableGroupId(g.id),
                g.displayName || "Unnamed Group",
                getGroupType(g),
                assignCount,
                memberCount
            ]);
        });

        var csv = rows.map(function (row) {
            return row.map(function (cell) {
                var s = String(cell).trim();
                // Prevent CSV formula injection in Excel
                if (/^[=+\-@\t\r]/.test(s)) {
                    s = "'" + s;
                }
                s = s.replace(/"/g, '""');
                return '"' + s + '"';
            }).join(",");
        }).join("\r\n");

        var blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
        var url = URL.createObjectURL(blob);
        var a = document.createElement("a");
        a.href = url;

        // Tag filename with filter state so exports are self-describing.
        var nameParts = ["groups"];
        if (filterAssigned) nameParts.push("assigned");
        if (filterMinCount > 0 || filterMaxCount > 0) {
            nameParts.push("count-" + (filterMinCount || 0) + "-to-" + (filterMaxCount || "any"));
        }
        var stamp = new Date().toISOString().slice(0, 10);
        a.download = nameParts.join("_") + "_" + stamp + ".csv";

        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    // ── Export CSV ─────────────────────────────────────────────────────

    function exportCsv() {
        // Handle orphaned items export
        if (activeGroupId === "__orphaned__") {
            exportOrphanedCsv();
            return;
        }

        if (!assignmentData) return;

        var groupName = selectedGroupName.textContent || "Group";
        var groupIdCell = exportableGroupId(activeGroupId);
        var rows = [["Group ID", "Group Name", "Category", "Name", "Description", "Platform", "Assignment Type", "Intent", "Filter Type", "Inherited From"]];

        CATEGORIES.forEach(function (c) {
            var items = getFilteredItems(c.key);
            var label = c.key.replace(/([A-Z])/g, " $1").replace(/^./, function (s) { return s.toUpperCase(); });
            items.forEach(function (item) {
                rows.push([
                    groupIdCell,
                    groupName,
                    label,
                    item.displayName || "",
                    item.description || "",
                    item.platform || "",
                    item.assignmentType || "",
                    item.intent || "",
                    item.filterType && item.filterType !== "none" ? item.filterType : "",
                    item.inheritedFrom || ""
                ]);
            });
        });

        var csv = rows.map(function (row) {
            return row.map(function (cell) {
                var s = String(cell).trim();
                // Prevent CSV formula injection in Excel
                if (/^[=+\-@\t\r]/.test(s)) {
                    s = "'" + s;
                }
                s = s.replace(/"/g, '""');
                return '"' + s + '"';
            }).join(",");
        }).join("\r\n");

        var blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
        var url = URL.createObjectURL(blob);
        var a = document.createElement("a");
        a.href = url;
        a.download = groupName.replace(/[^a-z0-9]/gi, "_") + "_assignments.csv";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    // ── Logout ────────────────────────────────────────────────────────

    async function logout() {
        stopIdleTimer();

        if (appMode === "spa") {
            if (!confirm("Sign out from Microsoft Graph?")) return;

            try {
                await GraphClient.signOut();
            } catch (err) {
                console.error("Logout error:", err);
            }

            // Reset UI
            allGroups         = [];
            assignedGroupIds  = new Set();
            groupAssignCounts = {};
            groupMemberCounts = {};
            memberCountsToken += 1;
            activeGroupId     = null;
            assignmentData    = null;
            nestedData        = null;
            orphanedData      = null;
            groupList.innerHTML    = "";
            groupCount.textContent = "0";
            groupSearch.value      = "";
            showPanel("empty");
            setConnection("error", "Signed out");

            // Show setup screen again
            showSetup(
                localStorage.getItem("iac_clientId"),
                localStorage.getItem("iac_tenantId")
            );
        } else {
            if (!confirm("Sign out from Microsoft Graph? You will need to restart the script to sign in again.")) {
                return;
            }

            try {
                var logoutHeaders = {};
                if (_backendKey) logoutHeaders["X-Backend-Key"] = _backendKey;
                var resp = await fetch("/api/logout", { method: "POST", headers: logoutHeaders });
                var data = await resp.json().catch(function () { return {}; });

                allGroups         = [];
                assignedGroupIds  = new Set();
                groupAssignCounts = {};
                groupMemberCounts = {};
                memberCountsToken += 1;
                activeGroupId     = null;
                assignmentData    = null;
                groupList.innerHTML    = "";
                groupCount.textContent = "0";
                groupSearch.value      = "";
                showPanel("empty");

                setConnection("error", "Signed out");
                contentErrorMsg.textContent = data.message || "Signed out. Restart the script to sign in again.";
            } catch (err) {
                console.error("Logout failed:", err);
                alert("Failed to sign out. Please try again.");
            }
        }
    }

    // ── Utilities ───────────────────────────────────────────────────────

    function escapeHtml(str) {
        var div = document.createElement("div");
        div.textContent = str;
        return div.innerHTML;
    }

    // ── Copy-to-clipboard helper ─────────────────────────────────────────

    var COPY_ICON_SVG = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>';
    var CHECK_ICON_SVG = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>';

    function createCopyButton(textFn) {
        var btn = document.createElement("button");
        btn.className = "btn-copy";
        btn.title = "Copy to clipboard";
        btn.innerHTML = COPY_ICON_SVG;
        btn.addEventListener("click", function (e) {
            e.stopPropagation();
            var text = typeof textFn === "function" ? textFn() : textFn;
            navigator.clipboard.writeText(text).then(function () {
                btn.innerHTML = CHECK_ICON_SVG;
                btn.classList.add("copied");
                setTimeout(function () {
                    btn.innerHTML = COPY_ICON_SVG;
                    btn.classList.remove("copied");
                }, 1500);
            });
        });
        return btn;
    }
})();
'@)

$script:graphJsBytes = [System.Text.Encoding]::UTF8.GetBytes(@'
/* ═══════════════════════════════════════════════════════════════════════════
   Assignment Checker — SPA Graph Client (MSAL.js)
   Handles authentication and direct Graph API calls when running without
   the PowerShell backend (e.g. GitHub Pages).
   ═══════════════════════════════════════════════════════════════════════════ */

// eslint-disable-next-line no-unused-vars
var GraphClient = (function () {
    "use strict";

    var REDIRECT_URI = window.location.origin + window.location.pathname;
    var GRAPH_BASE = "https://graph.microsoft.com";
    var SCOPES = [
        "DeviceManagementConfiguration.Read.All",
        "DeviceManagementApps.Read.All",
        "DeviceManagementManagedDevices.Read.All",
        "DeviceManagementScripts.Read.All",
        "Group.Read.All",
        "User.Read.All"
    ];

    var GUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

    function validateGuid(id, label) {
        if (!id || !GUID_RE.test(id)) {
            throw new Error("Invalid " + (label || "ID") + " format. Expected a valid GUID.");
        }
    }

    var msalInstance = null;
    var activeAccount = null;
    var initPromise = null; // tracks the full init+handleRedirect sequence

    // ── Initialise MSAL and handle any pending redirect ──────────────────

    function init(clientId, tenantId) {
        // If already initialising/initialised, return the same promise
        if (initPromise) return initPromise;

        initPromise = _doInit(clientId, tenantId);
        return initPromise;
    }

    async function _doInit(clientId, tenantId) {
        var authority = "https://login.microsoftonline.com/" + tenantId;

        var msalConfig = {
            auth: {
                clientId: clientId,
                authority: authority,
                redirectUri: REDIRECT_URI
            },
            cache: {
                cacheLocation: "sessionStorage",
                storeAuthStateInCookie: false
            }
        };

        msalInstance = new msal.PublicClientApplication(msalConfig);

        // initialize() is required in MSAL 2.x before any operations
        if (typeof msalInstance.initialize === "function") {
            await msalInstance.initialize();
        }

        // handleRedirectPromise MUST be called once after init to clear
        // any pending redirect state — otherwise loginRedirect will refuse
        // to start a new interaction ("interaction_in_progress").
        try {
            var response = await msalInstance.handleRedirectPromise();
            if (response && response.account) {
                activeAccount = response.account;
            }
        } catch (err) {
            console.warn("handleRedirectPromise error (clearing state):", err);
            // Clear stale interaction state so future logins work
            _clearInteractionState();
        }

        // Check for existing accounts from cache
        if (!activeAccount) {
            var accounts = msalInstance.getAllAccounts();
            if (accounts.length > 0) {
                activeAccount = accounts[0];
            }
        }

        return activeAccount;
    }

    // Clear MSAL's interaction-in-progress flag from sessionStorage
    function _clearInteractionState() {
        try {
            var keys = Object.keys(sessionStorage);
            for (var i = 0; i < keys.length; i++) {
                if (keys[i].indexOf("msal.") === 0 && keys[i].indexOf("interaction") !== -1) {
                    sessionStorage.removeItem(keys[i]);
                }
            }
        } catch (e) {
            // sessionStorage not available
        }
    }

    // ── Sign in ──────────────────────────────────────────────────────────

    async function signIn() {
        if (!msalInstance) throw new Error("MSAL not initialised. Call init() first.");

        // Clear any leftover interaction state before starting a new login
        _clearInteractionState();

        // Use redirect flow — page navigates to Microsoft login, then back
        await msalInstance.loginRedirect({ scopes: SCOPES });
        return null;
    }

    // ── Sign out ─────────────────────────────────────────────────────────

    async function signOut() {
        if (!msalInstance) return;
        var account = activeAccount || (msalInstance.getAllAccounts()[0] || null);
        activeAccount = null;
        initPromise = null;
        if (account) {
            try {
                await msalInstance.logoutRedirect({ account: account });
            } catch (e) {
                msalInstance.clearCache();
            }
        }
    }

    // ── Acquire token silently (with fallback to redirect) ───────────────

    async function getToken() {
        if (!msalInstance) throw new Error("MSAL not initialised.");
        var account = activeAccount || (msalInstance.getAllAccounts()[0] || null);
        if (!account) throw new Error("No signed-in account. Please sign in first.");

        var request = { scopes: SCOPES, account: account };
        try {
            var response = await msalInstance.acquireTokenSilent(request);
            return response.accessToken;
        } catch (err) {
            if (err instanceof msal.InteractionRequiredAuthError) {
                _clearInteractionState();
                await msalInstance.acquireTokenRedirect(request);
                return null;
            }
            throw err;
        }
    }

    // ── Graph API fetch with auth header and retry logic ────────────────

    var MAX_RETRIES = 3;
    var FETCH_TIMEOUT_MS = 30000;

    async function graphFetch(url) {
        var token = await getToken();
        var attempt = 0;

        while (true) {
            var controller = new AbortController();
            var timeoutId = setTimeout(function () { controller.abort(); }, FETCH_TIMEOUT_MS);

            var resp;
            try {
                resp = await fetch(url, {
                    headers: { "Authorization": "Bearer " + token },
                    signal: controller.signal
                });
            } catch (err) {
                clearTimeout(timeoutId);
                if (err.name === "AbortError") {
                    throw new Error("Request timed out after " + (FETCH_TIMEOUT_MS / 1000) + "s");
                }
                throw err;
            }
            clearTimeout(timeoutId);

            // Retry on 429 (throttled) or 5xx (server error)
            if ((resp.status === 429 || resp.status >= 500) && attempt < MAX_RETRIES) {
                attempt++;
                // Use Retry-After header if present, otherwise exponential backoff
                var retryAfter = resp.headers.get("Retry-After");
                var delay = retryAfter ? parseInt(retryAfter, 10) * 1000 : Math.pow(2, attempt) * 1000;
                console.warn("Graph API " + resp.status + " on attempt " + attempt + ", retrying in " + delay + "ms");
                await new Promise(function (resolve) { setTimeout(resolve, delay); });
                // Refresh token in case it expired during the wait
                token = await getToken();
                continue;
            }

            if (!resp.ok) {
                var body = await resp.json().catch(function () { return {}; });
                var msg = (body.error && body.error.message) || "HTTP " + resp.status;
                throw new Error(msg);
            }

            // Validate response Content-Type before parsing
            var contentType = (resp.headers.get("Content-Type") || "").split(";")[0].trim();
            if (contentType !== "application/json") {
                throw new Error("Unexpected response type: " + contentType);
            }

            return resp.json();
        }
    }

    // ── Paginated fetch (follows @odata.nextLink) ────────────────────────

    async function graphFetchAll(url) {
        var results = [];
        var nextUrl = url;
        while (nextUrl) {
            var data = await graphFetch(nextUrl);
            if (data.value) {
                results = results.concat(data.value);
            }
            // Only follow nextLink if it points to the Graph API (prevent token leakage)
            var link = data["@odata.nextLink"] || null;
            if (link) {
                try {
                    var parsed = new URL(link);
                    if (parsed.protocol !== "https:" || parsed.hostname !== "graph.microsoft.com") {
                        console.warn("Ignoring untrusted @odata.nextLink");
                        link = null;
                    }
                } catch (e) {
                    console.warn("Ignoring malformed @odata.nextLink");
                    link = null;
                }
            }
            nextUrl = link;
        }
        return results;
    }

    // ── Public API methods (mirror the PowerShell backend endpoints) ─────

    async function getAllGroups() {
        var url = GRAPH_BASE + "/v1.0/groups?$select=id,displayName,description,groupTypes,membershipRule&$top=999";
        var groups = await graphFetchAll(url);
        groups.sort(function (a, b) {
            return (a.displayName || "").localeCompare(b.displayName || "");
        });
        return groups;
    }

    // ── Member count batch fetch (Graph $batch, up to 20 per request) ─────
    //
    // Takes an array of group IDs and returns { id: count } for each that
    // responded 200. Dynamic groups that are still resolving may return 0.
    // Calls onProgress(partialCounts) after each batch so the UI can update
    // progressively instead of waiting for the full sweep.

    async function getGroupMemberCounts(ids, onProgress) {
        var counts = {};
        if (!Array.isArray(ids) || ids.length === 0) return counts;

        // Filter to valid GUIDs and de-dupe
        var unique = [];
        var seen = {};
        for (var i = 0; i < ids.length; i++) {
            var id = ids[i];
            if (id && GUID_RE.test(id) && !seen[id]) {
                seen[id] = true;
                unique.push(id);
            }
        }

        var BATCH_SIZE = 20;
        var batches = [];
        for (var j = 0; j < unique.length; j += BATCH_SIZE) {
            batches.push(unique.slice(j, j + BATCH_SIZE));
        }

        for (var b = 0; b < batches.length; b++) {
            var chunk = batches[b];
            var requests = chunk.map(function (gid, idx) {
                return {
                    id: String(idx),
                    method: "GET",
                    url: "/groups/" + gid + "/members/$count",
                    headers: { "ConsistencyLevel": "eventual" }
                };
            });

            var token;
            try {
                token = await getToken();
            } catch (e) {
                console.warn("Member count batch aborted (auth):", e.message);
                break;
            }

            var resp;
            try {
                resp = await fetch(GRAPH_BASE + "/v1.0/$batch", {
                    method: "POST",
                    headers: {
                        "Authorization": "Bearer " + token,
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({ requests: requests })
                });
            } catch (e) {
                console.warn("Member count batch network error:", e.message);
                continue;
            }

            if (!resp.ok) {
                console.warn("Member count batch failed: HTTP " + resp.status);
                continue;
            }

            var data = await resp.json().catch(function () { return null; });
            if (!data || !Array.isArray(data.responses)) continue;

            var batchCounts = {};
            data.responses.forEach(function (r) {
                var idx = parseInt(r.id, 10);
                if (isNaN(idx) || idx < 0 || idx >= chunk.length) return;
                var gid = chunk[idx];
                if (r.status === 200) {
                    // Batch responses wrap the /$count body; it may arrive as
                    // a number, a numeric string, or (for text/plain) an
                    // object with the raw value. Normalise all of them.
                    var body = r.body;
                    var n;
                    if (typeof body === "number") {
                        n = body;
                    } else if (typeof body === "string") {
                        n = parseInt(body, 10);
                    } else {
                        n = NaN;
                    }
                    if (!isNaN(n)) {
                        counts[gid] = n;
                        batchCounts[gid] = n;
                    }
                }
            });

            if (typeof onProgress === "function" && Object.keys(batchCounts).length) {
                try { onProgress(batchCounts); } catch (e) { /* ignore */ }
            }
        }

        return counts;
    }

    function extractAssignment(assignment, groupId) {
        var target = assignment.target || {};
        var targetGroupId = target.groupId || null;
        var odataType = target["@odata.type"] || "";

        if (odataType === "#microsoft.graph.allDevicesAssignmentTarget") {
            return { match: true, assignmentType: "All Devices" };
        }
        if (odataType === "#microsoft.graph.allLicensedUsersAssignmentTarget") {
            return { match: true, assignmentType: "All Users" };
        }
        if (targetGroupId === groupId) {
            if (odataType.indexOf("exclusion") !== -1) {
                return { match: true, assignmentType: "Exclude" };
            }
            return { match: true, assignmentType: "Include" };
        }
        return { match: false };
    }

    function detectPlatform(item, categoryKey) {
        if (categoryKey === "scripts" || categoryKey === "remediations") {
            return "Windows";
        }
        if (categoryKey === "settingsCatalog") {
            var platforms = (item.platforms || "").toLowerCase();
            if (platforms.indexOf("windows") !== -1) return "Windows";
            if (platforms.indexOf("ios") !== -1) return "iOS";
            if (platforms.indexOf("macos") !== -1 || platforms.indexOf("macos") !== -1) return "macOS";
            if (platforms.indexOf("android") !== -1) return "Android";
            return "";
        }
        var odataType = (item["@odata.type"] || "").toLowerCase();
        if (odataType.indexOf("ios") !== -1 || odataType.indexOf("iphone") !== -1) return "iOS";
        if (odataType.indexOf("android") !== -1) return "Android";
        if (odataType.indexOf("windows") !== -1 || odataType.indexOf("win32") !== -1 || odataType.indexOf("microsoftstore") !== -1 || odataType.indexOf("winget") !== -1) return "Windows";
        if (odataType.indexOf("macos") !== -1) return "macOS";
        return "";
    }

    function buildItem(policy, assignmentInfo, platform) {
        var a = assignmentInfo.source || {};
        return {
            id: policy.id,
            displayName: policy.displayName || policy.name || "Unnamed",
            description: policy.description || "",
            assignmentType: assignmentInfo.assignmentType,
            intent: a.intent || "",
            filterId: (a.target && a.target.deviceAndAppManagementAssignmentFilterId) || "",
            filterType: (a.target && a.target.deviceAndAppManagementAssignmentFilterType) || "none",
            platform: platform || ""
        };
    }

    async function getAssignmentsForCategory(url, groupId, categoryKey) {
        var items = await graphFetchAll(url);
        var matched = [];
        items.forEach(function (item) {
            var assignments = item.assignments || [];
            var platform = detectPlatform(item, categoryKey);
            assignments.forEach(function (a) {
                var info = extractAssignment(a, groupId);
                if (info.match) {
                    matched.push(buildItem(item, { assignmentType: info.assignmentType, source: a }, platform));
                }
            });
        });
        return matched;
    }

    async function getAssignmentsByTargetType(targetOdataType, label) {
        var endpoints = {
            configurations: GRAPH_BASE + "/beta/deviceManagement/deviceConfigurations?$expand=assignments&$select=id,displayName,description,assignments",
            settingsCatalog: GRAPH_BASE + "/beta/deviceManagement/configurationPolicies?$expand=assignments&$select=id,name,description,assignments,platforms",
            applications: GRAPH_BASE + "/beta/deviceAppManagement/mobileApps?$expand=assignments&$filter=isAssigned eq true&$select=id,displayName,description,assignments",
            scripts: GRAPH_BASE + "/beta/deviceManagement/deviceManagementScripts?$expand=assignments&$select=id,displayName,description,assignments",
            remediations: GRAPH_BASE + "/beta/deviceManagement/deviceHealthScripts?$expand=assignments&$select=id,displayName,description,assignments"
        };

        var keys = Object.keys(endpoints);
        var promises = keys.map(function (key) {
            return graphFetchAll(endpoints[key]).then(function (items) {
                var matched = [];
                items.forEach(function (item) {
                    var platform = detectPlatform(item, key);
                    (item.assignments || []).forEach(function (a) {
                        var t = (a.target && a.target["@odata.type"]) || "";
                        if (t === targetOdataType) {
                            matched.push(buildItem(item, { assignmentType: label, source: a }, platform));
                        }
                    });
                });
                return matched;
            }).catch(function (err) {
                console.error("Failed to fetch " + key + ":", err);
                return { _error: err.message || "Failed to load" };
            });
        });
        var results = await Promise.all(promises);

        var data = { _errors: {} };
        keys.forEach(function (key, i) {
            if (results[i] && results[i]._error) {
                data[key] = [];
                data._errors[key] = results[i]._error;
            } else {
                data[key] = results[i];
            }
            if (key === "settingsCatalog" && Array.isArray(data[key])) {
                data[key].forEach(function (item) {
                    if (!item.displayName && item.name) {
                        item.displayName = item.name;
                    }
                });
            }
        });
        return data;
    }

    async function getAssignmentsForGroup(groupId) {
        validateGuid(groupId, "group ID");
        var endpoints = {
            configurations: GRAPH_BASE + "/beta/deviceManagement/deviceConfigurations?$expand=assignments&$select=id,displayName,description,assignments",
            settingsCatalog: GRAPH_BASE + "/beta/deviceManagement/configurationPolicies?$expand=assignments&$select=id,name,description,assignments,platforms",
            applications: GRAPH_BASE + "/beta/deviceAppManagement/mobileApps?$expand=assignments&$filter=isAssigned eq true&$select=id,displayName,description,assignments",
            scripts: GRAPH_BASE + "/beta/deviceManagement/deviceManagementScripts?$expand=assignments&$select=id,displayName,description,assignments",
            remediations: GRAPH_BASE + "/beta/deviceManagement/deviceHealthScripts?$expand=assignments&$select=id,displayName,description,assignments"
        };

        var keys = Object.keys(endpoints);
        var promises = keys.map(function (key) {
            return getAssignmentsForCategory(endpoints[key], groupId, key)
                .catch(function (err) {
                    console.error("Failed to fetch " + key + ":", err);
                    return { _error: err.message || "Failed to load" };
                });
        });
        var results = await Promise.all(promises);

        var data = { _errors: {} };
        keys.forEach(function (key, i) {
            if (results[i] && results[i]._error) {
                data[key] = [];
                data._errors[key] = results[i]._error;
            } else {
                data[key] = results[i];
            }
            if (key === "settingsCatalog" && Array.isArray(data[key])) {
                data[key].forEach(function (item) {
                    if (!item.displayName && item.name) {
                        item.displayName = item.name;
                    }
                });
            }
        });
        return data;
    }

    async function getGroupParents(groupId) {
        validateGuid(groupId, "group ID");
        var url = GRAPH_BASE + "/v1.0/groups/" + groupId + "/transitiveMemberOf/microsoft.graph.group?$select=id,displayName&$top=999";
        return graphFetchAll(url);
    }

    async function getNestedAssignments(groupId) {
        validateGuid(groupId, "group ID");
        var parents = await getGroupParents(groupId);
        if (!parents || parents.length === 0) {
            return {
                configurations: [], settingsCatalog: [], applications: [],
                scripts: [], remediations: [], _errors: {}
            };
        }

        // Build lookup of parent group IDs to names
        var parentLookup = {};
        parents.forEach(function (p) {
            if (p.id) parentLookup[p.id] = p.displayName || p.id;
        });

        var endpoints = {
            configurations: GRAPH_BASE + "/beta/deviceManagement/deviceConfigurations?$expand=assignments&$select=id,displayName,description,assignments",
            settingsCatalog: GRAPH_BASE + "/beta/deviceManagement/configurationPolicies?$expand=assignments&$select=id,name,description,assignments,platforms",
            applications: GRAPH_BASE + "/beta/deviceAppManagement/mobileApps?$expand=assignments&$filter=isAssigned eq true&$select=id,displayName,description,assignments",
            scripts: GRAPH_BASE + "/beta/deviceManagement/deviceManagementScripts?$expand=assignments&$select=id,displayName,description,assignments",
            remediations: GRAPH_BASE + "/beta/deviceManagement/deviceHealthScripts?$expand=assignments&$select=id,displayName,description,assignments"
        };

        var keys = Object.keys(endpoints);
        var promises = keys.map(function (key) {
            return graphFetchAll(endpoints[key]).then(function (items) {
                var matched = [];
                items.forEach(function (item) {
                    var platform = detectPlatform(item, key);
                    (item.assignments || []).forEach(function (a) {
                        var t = a.target || {};
                        var tGroupId = t.groupId || null;
                        if (tGroupId && parentLookup[tGroupId]) {
                            var odataType = t["@odata.type"] || "";
                            var assignmentType = odataType.indexOf("exclusion") !== -1 ? "Exclude" : "Include";
                            var built = buildItem(item, { assignmentType: assignmentType, source: a }, platform);
                            built.inheritedFrom = parentLookup[tGroupId];
                            built.inheritedFromId = tGroupId;
                            matched.push(built);
                        }
                    });
                });
                return matched;
            }).catch(function (err) {
                console.error("Failed to fetch nested " + key + ":", err);
                return { _error: err.message || "Failed to load" };
            });
        });

        var results = await Promise.all(promises);
        var data = { _errors: {} };
        keys.forEach(function (key, i) {
            if (results[i] && results[i]._error) {
                data[key] = [];
                data._errors[key] = results[i]._error;
            } else {
                data[key] = results[i];
            }
            if (key === "settingsCatalog" && Array.isArray(data[key])) {
                data[key].forEach(function (item) {
                    if (!item.displayName && item.name) item.displayName = item.name;
                });
            }
        });
        return data;
    }

    async function getOrphanedItems(allGroups, assignedGroupIdSet) {
        var endpoints = {
            configurations: GRAPH_BASE + "/beta/deviceManagement/deviceConfigurations?$expand=assignments&$select=id,displayName,description,assignments",
            settingsCatalog: GRAPH_BASE + "/beta/deviceManagement/configurationPolicies?$expand=assignments&$select=id,name,description,assignments,platforms",
            applications: GRAPH_BASE + "/beta/deviceAppManagement/mobileApps?$expand=assignments&$select=id,displayName,description,assignments",
            scripts: GRAPH_BASE + "/beta/deviceManagement/deviceManagementScripts?$expand=assignments&$select=id,displayName,description,assignments",
            remediations: GRAPH_BASE + "/beta/deviceManagement/deviceHealthScripts?$expand=assignments&$select=id,displayName,description,assignments"
        };

        var keys = Object.keys(endpoints);
        var promises = keys.map(function (key) {
            return graphFetchAll(endpoints[key]).then(function (items) {
                var orphaned = [];
                items.forEach(function (item) {
                    var assignments = item.assignments || [];
                    if (assignments.length === 0) {
                        orphaned.push({
                            id: item.id,
                            displayName: item.displayName || item.name || "Unnamed",
                            description: item.description || "",
                            platform: detectPlatform(item, key)
                        });
                    }
                });
                return orphaned;
            }).catch(function (err) {
                console.error("Failed to fetch orphaned " + key + ":", err);
                return { _error: err.message || "Failed to load" };
            });
        });

        var results = await Promise.all(promises);
        var data = { _errors: {} };
        keys.forEach(function (key, i) {
            if (results[i] && results[i]._error) {
                data[key] = [];
                data._errors[key] = results[i]._error;
            } else {
                data[key] = results[i];
            }
            if (key === "settingsCatalog" && Array.isArray(data[key])) {
                data[key].forEach(function (item) {
                    if (!item.displayName && item.name) item.displayName = item.name;
                });
            }
        });

        // Compute unassigned groups (groups with no Intune assignments)
        var unassignedGroups = [];
        if (allGroups && assignedGroupIdSet) {
            allGroups.forEach(function (g) {
                if (!assignedGroupIdSet.has(g.id)) {
                    unassignedGroups.push({
                        id: g.id,
                        displayName: g.displayName || "Unnamed",
                        description: g.description || "",
                        groupType: (g.groupTypes && g.groupTypes.indexOf("DynamicMembership") !== -1) ? "Dynamic" : "Assigned"
                    });
                }
            });
        }
        data.groups = unassignedGroups;

        return data;
    }

    async function getAssignedGroupIds() {
        var endpoints = [
            GRAPH_BASE + "/beta/deviceManagement/deviceConfigurations?$expand=assignments&$select=id,assignments",
            GRAPH_BASE + "/beta/deviceManagement/configurationPolicies?$expand=assignments&$select=id,assignments",
            GRAPH_BASE + "/beta/deviceAppManagement/mobileApps?$expand=assignments&$filter=isAssigned eq true&$select=id,assignments",
            GRAPH_BASE + "/beta/deviceManagement/deviceManagementScripts?$expand=assignments&$select=id,assignments",
            GRAPH_BASE + "/beta/deviceManagement/deviceHealthScripts?$expand=assignments&$select=id,assignments"
        ];

        var promises = endpoints.map(function (url) {
            return graphFetchAll(url).catch(function () { return []; });
        });
        var allResults = await Promise.all(promises);

        var counts = {};  // groupId -> assignment count
        allResults.forEach(function (items) {
            items.forEach(function (item) {
                (item.assignments || []).forEach(function (a) {
                    var gid = a.target && a.target.groupId;
                    if (gid) {
                        counts[gid] = (counts[gid] || 0) + 1;
                    }
                });
            });
        });
        return { ids: Object.keys(counts), counts: counts };
    }

    async function getScriptContent(scriptId) {
        validateGuid(scriptId, "script ID");
        var data = await graphFetch(
            GRAPH_BASE + "/beta/deviceManagement/deviceManagementScripts/" + scriptId
        );
        var content = "";
        if (data.scriptContent) {
            try {
                content = atob(data.scriptContent);
            } catch (e) {
                content = data.scriptContent;
            }
        }
        return {
            id: data.id,
            fileName: data.fileName || "",
            content: content
        };
    }

    // Reset MSAL state so a new tenant/client can be used without a page reload
    function reset() {
        if (msalInstance) {
            try { msalInstance.clearCache(); } catch (e) { /* ignore */ }
        }
        msalInstance = null;
        activeAccount = null;
        initPromise = null;
        // Clear all MSAL keys from sessionStorage
        try {
            var keys = Object.keys(sessionStorage);
            for (var i = 0; i < keys.length; i++) {
                if (keys[i].indexOf("msal.") === 0 || keys[i].indexOf("msal:") === 0) {
                    sessionStorage.removeItem(keys[i]);
                }
            }
        } catch (e) { /* sessionStorage not available */ }
    }

    function isInitialised() {
        return msalInstance !== null;
    }

    function getAccount() {
        if (activeAccount) return activeAccount;
        if (msalInstance) {
            var accounts = msalInstance.getAllAccounts();
            if (accounts.length > 0) return accounts[0];
        }
        return null;
    }

    return {
        init: init,
        reset: reset,
        signIn: signIn,
        signOut: signOut,
        isInitialised: isInitialised,
        getAccount: getAccount,
        getAllGroups: getAllGroups,
        getGroupMemberCounts: getGroupMemberCounts,
        getAssignedGroupIds: getAssignedGroupIds,
        getAssignmentsForGroup: getAssignmentsForGroup,
        getAssignmentsByTargetType: getAssignmentsByTargetType,
        getScriptContent: getScriptContent,
        getGroupParents: getGroupParents,
        getNestedAssignments: getNestedAssignments,
        getOrphanedItems: getOrphanedItems
    };
})();
'@)

$script:inMemoryAssets = @{
    '/static/css/style.css'    = @{ bytes = $script:cssBytes;     mime = 'text/css; charset=utf-8' }
    '/static/js/app.js'        = @{ bytes = $script:appJsBytes;   mime = 'application/javascript; charset=utf-8' }
    '/static/js/graph.js'      = @{ bytes = $script:graphJsBytes; mime = 'application/javascript; charset=utf-8' }
}
# -----------------------------------------------------------------------------
# 7. Start the HTTP listener
# -----------------------------------------------------------------------------

$listener = New-Object System.Net.HttpListener
$prefix   = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
}
catch {
    Write-Error "Could not start HTTP listener on port $Port. Is it already in use? Error: $_"
    exit 1
}

Write-Host "  ======================================================" -ForegroundColor Cyan
Write-Host "  Web server running at http://localhost:$Port          " -ForegroundColor Cyan
Write-Host "  Press Ctrl+C to stop.                                " -ForegroundColor Cyan
Write-Host "  ======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  NOTE: The server uses HTTP (not HTTPS). This is acceptable" -ForegroundColor Yellow
Write-Host "  for localhost-only access, but traffic could be observed by" -ForegroundColor Yellow
Write-Host "  other processes on this machine with elevated privileges." -ForegroundColor Yellow
Write-Host ""

# Open default browser. The API secret is passed as a URL fragment so it is
# never sent on the wire (fragments stay client-side) and so other local
# processes that simply GET / cannot learn it. The SPA reads the fragment,
# scrubs it from the address bar, and attaches it as X-Backend-Key on every
# /api/* call.
$launchUrl = "http://localhost:$Port/#k=$script:apiSecret"
try {
    Start-Process $launchUrl
}
catch {
    Write-Host "  Open $launchUrl in your browser." -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# 8. Request loop
# -----------------------------------------------------------------------------

# Rate limiting: sliding window of request timestamps
$script:rateLimitTimestamps = [System.Collections.ArrayList]::new()
$script:rateLimitMax        = 120   # max requests per window
$script:rateLimitWindowSec  = 60    # window size in seconds

try {
    while ($listener.IsListening) {
        $contextTask = $listener.GetContextAsync()
        # Allow Ctrl+C to interrupt
        while (-not $contextTask.AsyncWaitHandle.WaitOne(500)) { }
        $ctx = $contextTask.GetAwaiter().GetResult()

        $req  = $ctx.Request
        $resp = $ctx.Response
        $path = $req.Url.AbsolutePath

        try {
            Set-SecurityHeaders -Response $resp

            # -- Rate limiting -----------------------------------------
            $nowTicks = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $cutoff   = $nowTicks - $script:rateLimitWindowSec
            $script:rateLimitTimestamps = [System.Collections.ArrayList]@(
                $script:rateLimitTimestamps | Where-Object { $_ -gt $cutoff }
            )
            if ($script:rateLimitTimestamps.Count -ge $script:rateLimitMax) {
                $resp.StatusCode = 429
                $body   = '{"error":"Too many requests. Please try again later."}'
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
                $resp.ContentType     = "application/json; charset=utf-8"
                $resp.ContentLength64 = $buffer.Length
                $resp.Headers.Set("Retry-After", "10")
                $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                $resp.OutputStream.Close()
                continue
            }
            [void]$script:rateLimitTimestamps.Add($nowTicks)

            # -- CORS preflight ----------------------------------------
            if ($req.HttpMethod -eq "OPTIONS") {
                $resp.StatusCode = 204
                $resp.OutputStream.Close()
                continue
            }

            # -- Origin validation for API routes ----------------------
            if ($path.StartsWith("/api/") -and -not (Test-ApiOrigin -Request $req)) {
                $resp.StatusCode = 403
                $body   = '{"error":"Forbidden: invalid origin."}'
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
                $resp.ContentType     = "application/json; charset=utf-8"
                $resp.ContentLength64 = $buffer.Length
                $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                $resp.OutputStream.Close()
                continue
            }

            # -- API secret validation (per-launch token) --------------
            # Reject any /api/* request that does not present the launch
            # secret. This blocks other local processes from piggybacking
            # on the signed-in Graph session even if they forge Origin.
            if ($path.StartsWith("/api/")) {
                $providedKey = $req.Headers["X-Backend-Key"]
                $expected    = $script:apiSecret
                $isValid     = $false
                if ($providedKey -and $expected -and $providedKey.Length -eq $expected.Length) {
                    # Constant-time compare to avoid timing side channels.
                    $diff = 0
                    for ($i = 0; $i -lt $expected.Length; $i++) {
                        $diff = $diff -bor ([int][char]$providedKey[$i] -bxor [int][char]$expected[$i])
                    }
                    $isValid = ($diff -eq 0)
                }
                if (-not $isValid) {
                    $resp.StatusCode = 401
                    $body   = '{"error":"Unauthorized: missing or invalid backend key."}'
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                    $resp.OutputStream.Close()
                    continue
                }
            }

            # -- Idle timeout enforcement ------------------------------
            # After $script:idleTimeoutSec of inactivity, disconnect
            # Graph and reject further /api/* calls until the script is
            # restarted. This prevents an abandoned terminal from leaving
            # delegated Graph access open indefinitely.
            if ($path.StartsWith("/api/")) {
                $nowSec = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                if (-not $script:sessionExpired -and
                    ($nowSec - $script:lastActivityTime) -gt $script:idleTimeoutSec) {
                    try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch { }
                    $script:sessionExpired = $true
                    Write-Host "  Session expired due to inactivity. Graph disconnected." -ForegroundColor Yellow
                }
                if ($script:sessionExpired) {
                    $resp.StatusCode = 401
                    $body   = '{"error":"Session expired due to inactivity. Please restart the script to sign in again.","expired":true}'
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                    $resp.OutputStream.Close()
                    continue
                }
                # Authenticated, non-expired API call — record activity.
                $script:lastActivityTime = $nowSec
            }

            # -- API: status (backend mode detection) ------------------
            if ($path -eq "/api/status" -and ($req.HttpMethod -eq "GET" -or $req.HttpMethod -eq "HEAD")) {
                $statusBody = '{"mode":"backend"}'
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($statusBody)
                $resp.ContentType     = "application/json; charset=utf-8"
                $resp.ContentLength64 = $buffer.Length
                $resp.StatusCode      = 200
                $resp.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            # -- API: list groups ------------------------------------
            elseif ($path -eq "/api/groups" -and $req.HttpMethod -eq "GET") {
                $groups = @(Get-AllGroups)
                $json   = ConvertTo-SafeJson -InputObject $groups -AsArray
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                $resp.ContentType     = "application/json; charset=utf-8"
                $resp.ContentLength64 = $buffer.Length
                $resp.StatusCode      = 200
                $resp.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            # -- API: assigned group IDs -----------------------------
            elseif ($path -eq "/api/assigned-group-ids" -and $req.HttpMethod -eq "GET") {
                try {
                    $result = Get-AssignedGroupIds
                    $json   = ConvertTo-Json -InputObject $result -Depth 10 -Compress
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 200
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
                catch {
                    Write-Warning "Failed to fetch assigned group IDs: $($_.Exception.Message)"
                    $errBody = ConvertTo-Json -InputObject @{ error = "Failed to fetch assigned group IDs. Please try again." } -Compress
                    $buffer  = [System.Text.Encoding]::UTF8.GetBytes($errBody)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 502
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
            # -- API: group parent groups (nested membership) ----------
            elseif ($path -match "^/api/groups/([^/]+)/parents$" -and $req.HttpMethod -eq "GET") {
                $groupId    = $Matches[1]
                $parsedGuid = [System.Guid]::Empty
                if (-not [System.Guid]::TryParse($groupId, [ref]$parsedGuid)) {
                    $resp.StatusCode = 400
                    $body   = '{"error":"Invalid group ID format. Expected a valid GUID."}'
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                    continue
                }
                $groupId = $parsedGuid.ToString()
                try {
                    $parents = @(Get-GroupParentGroups -GroupId $groupId)
                    $json    = ConvertTo-SafeJson -InputObject $parents -AsArray
                    $buffer  = [System.Text.Encoding]::UTF8.GetBytes($json)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 200
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
                catch {
                    Write-Warning "Parent group fetch failed for $groupId : $($_.Exception.Message)"
                    $errBody = ConvertTo-Json -InputObject @{ error = "Failed to fetch parent groups." } -Compress
                    $buffer  = [System.Text.Encoding]::UTF8.GetBytes($errBody)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 502
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
            # -- API: nested group assignments -------------------------
            elseif ($path -match "^/api/groups/([^/]+)/nested-assignments$" -and $req.HttpMethod -eq "GET") {
                $groupId    = $Matches[1]
                $parsedGuid = [System.Guid]::Empty
                if (-not [System.Guid]::TryParse($groupId, [ref]$parsedGuid)) {
                    $resp.StatusCode = 400
                    $body   = '{"error":"Invalid group ID format. Expected a valid GUID."}'
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                    continue
                }
                $groupId = $parsedGuid.ToString()
                try {
                    $parents = @(Get-GroupParentGroups -GroupId $groupId)
                    if ($parents.Count -gt 0) {
                        $nestedResult = Get-NestedGroupAssignments -GroupId $groupId -ParentGroups $parents
                    } else {
                        $nestedResult = @{
                            configurations  = @()
                            settingsCatalog = @()
                            applications    = @()
                            scripts         = @()
                            remediations    = @()
                            _errors         = @{}
                        }
                    }
                    $json   = ConvertTo-SafeJson -InputObject $nestedResult
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 200
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
                catch {
                    Write-Warning "Nested assignment fetch failed for $groupId : $($_.Exception.Message)"
                    $errBody = ConvertTo-Json -InputObject @{ error = "Failed to fetch nested assignments." } -Compress
                    $buffer  = [System.Text.Encoding]::UTF8.GetBytes($errBody)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 502
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
            # -- API: orphaned items -----------------------------------
            elseif ($path -eq "/api/orphaned-items" -and $req.HttpMethod -eq "GET") {
                try {
                    $orphanedResult = Get-OrphanedItems
                    $json   = ConvertTo-SafeJson -InputObject $orphanedResult
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 200
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
                catch {
                    Write-Warning "Orphaned items fetch failed: $($_.Exception.Message)"
                    $errBody = ConvertTo-Json -InputObject @{ error = "Failed to fetch orphaned items." } -Compress
                    $buffer  = [System.Text.Encoding]::UTF8.GetBytes($errBody)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 502
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
            # -- API: group assignments ------------------------------
            elseif ($path -match "^/api/groups/([^/]+)/assignments$" -and $req.HttpMethod -eq "GET") {
                $groupId    = $Matches[1]
                $parsedGuid = [System.Guid]::Empty
                if (-not [System.Guid]::TryParse($groupId, [ref]$parsedGuid)) {
                    $resp.StatusCode = 400
                    $body   = '{"error":"Invalid group ID format. Expected a valid GUID."}'
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                    continue
                }
                $groupId = $parsedGuid.ToString()
                try {
                    $assignmentsResult = Get-AssignmentsForGroup -GroupId $groupId
                    $json   = ConvertTo-SafeJson -InputObject $assignmentsResult
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 200
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
                catch {
                    Write-Warning "Assignment fetch failed for group $groupId : $($_.Exception.Message)"
                    $errBody = ConvertTo-Json -InputObject @{ error = "Failed to fetch assignments. Please try again." } -Compress
                    $buffer  = [System.Text.Encoding]::UTF8.GetBytes($errBody)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 502
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
            # -- API: assignments by target type -----------------------
            elseif ($path -eq "/api/assignments-by-target" -and $req.HttpMethod -eq "GET") {
                $targetType = $req.QueryString["type"]
                $validTypes = @(
                    "#microsoft.graph.allDevicesAssignmentTarget",
                    "#microsoft.graph.allLicensedUsersAssignmentTarget"
                )
                if (-not $targetType -or $targetType -notin $validTypes) {
                    $resp.StatusCode = 400
                    $body   = '{"error":"Invalid or missing target type parameter."}'
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                    continue
                }
                try {
                    $assignmentsResult = Get-AssignmentsByTargetType -TargetOdataType $targetType
                    $json   = ConvertTo-Json -InputObject $assignmentsResult -Depth 10 -Compress
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 200
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
                catch {
                    Write-Warning "Assignment fetch by target type failed: $($_.Exception.Message)"
                    $errBody = ConvertTo-Json -InputObject @{ error = "Failed to fetch assignments. Please try again." } -Compress
                    $buffer  = [System.Text.Encoding]::UTF8.GetBytes($errBody)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 502
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
            # -- API: script content ---------------------------------
            elseif ($path -match "^/api/scripts/([^/]+)/content$" -and $req.HttpMethod -eq "GET") {
                $scriptId   = $Matches[1]
                $parsedGuid = [System.Guid]::Empty
                if (-not [System.Guid]::TryParse($scriptId, [ref]$parsedGuid)) {
                    $resp.StatusCode = 400
                    $body   = '{"error":"Invalid script ID format. Expected a valid GUID."}'
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                    continue
                }
                $scriptId = $parsedGuid.ToString()
                try {
                    $scriptObj  = Invoke-MgGraphRequest -Method GET -Uri "/beta/deviceManagement/deviceManagementScripts/$scriptId" -OutputType PSObject
                    $b64Content = Get-SafeValue $scriptObj 'scriptContent'
                    $fileName   = Get-SafeValue $scriptObj 'fileName'
                    $decoded    = ""
                    if ($b64Content) {
                        $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64Content))
                    }
                    $result = @{
                        id          = $scriptId
                        fileName    = if ($fileName) { $fileName } else { "" }
                        content     = $decoded
                    }
                    $json   = ConvertTo-SafeJson -InputObject $result
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 200
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
                catch {
                    Write-Warning "Script content fetch failed for $scriptId : $($_.Exception.Message)"
                    $errBody = ConvertTo-Json -InputObject @{ error = "Failed to fetch script content. Please try again." } -Compress
                    $buffer  = [System.Text.Encoding]::UTF8.GetBytes($errBody)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 502
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
            # -- API: group member counts (batch) --------------------
            elseif ($path -eq "/api/group-member-counts" -and $req.HttpMethod -eq "POST") {
                try {
                    $reader  = New-Object System.IO.StreamReader($req.InputStream, $req.ContentEncoding)
                    $rawBody = $reader.ReadToEnd()
                    $reader.Close()

                    $payload = $null
                    if ($rawBody) {
                        try { $payload = $rawBody | ConvertFrom-Json } catch { $payload = $null }
                    }

                    $idsInput = $null
                    if ($payload -and ($payload.PSObject.Properties.Match('ids').Count)) {
                        $idsInput = $payload.ids
                    }

                    if (-not $idsInput) {
                        $resp.StatusCode = 400
                        $errBody = '{"error":"Missing or invalid ids array in request body."}'
                        $buffer  = [System.Text.Encoding]::UTF8.GetBytes($errBody)
                        $resp.ContentType     = "application/json; charset=utf-8"
                        $resp.ContentLength64 = $buffer.Length
                        $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                        continue
                    }

                    $idArray = @($idsInput | ForEach-Object { "$_" })
                    # Cap the number of IDs per request to protect the backend
                    if ($idArray.Count -gt 2000) {
                        $idArray = $idArray[0..1999]
                    }

                    $counts = Get-GroupMemberCounts -GroupIds $idArray
                    $json   = ConvertTo-Json -InputObject @{ counts = $counts } -Depth 10 -Compress
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 200
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
                catch {
                    Write-Warning "Group member count fetch failed: $($_.Exception.Message)"
                    $errBody = ConvertTo-Json -InputObject @{ error = "Failed to fetch group member counts." } -Compress
                    $buffer  = [System.Text.Encoding]::UTF8.GetBytes($errBody)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 502
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
            # -- API: logout -----------------------------------------
            elseif ($path -eq "/api/logout" -and $req.HttpMethod -eq "POST") {
                # Origin validation is handled globally above for all /api/* routes
                try {
                    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
                    $script:sessionExpired = $true
                    Write-Host "  User logged out via web UI." -ForegroundColor Yellow
                    $body   = '{"success":true,"message":"Disconnected from Microsoft Graph. Restart the script to sign in again."}'
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.StatusCode      = 200
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
                catch {
                    $resp.StatusCode = 500
                    $body   = '{"error":"Failed to disconnect."}'
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
                    $resp.ContentType     = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $buffer.Length
                    $resp.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
            # -- Serve index.html (embedded) -------------------------
            elseif ($path -eq "/" -or $path -eq "/index.html") {
                $bytes = $script:htmlBytes
                $resp.ContentType     = "text/html; charset=utf-8"
                $resp.ContentLength64 = $bytes.Length
                $resp.StatusCode      = 200
                $resp.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            # -- Serve static files (embedded) ----------------------
            elseif ($script:inMemoryAssets.ContainsKey($path)) {
                $asset = $script:inMemoryAssets[$path]
                $bytes = $asset.bytes
                $resp.ContentType     = $asset.mime
                $resp.ContentLength64 = $bytes.Length
                $resp.StatusCode      = 200
                $resp.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            # -- 404 ------------------------------------------------
            else {
                $resp.StatusCode = 404
                $body   = '{"error":"Not found"}'
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
                $resp.ContentType     = "application/json"
                $resp.ContentLength64 = $buffer.Length
                $resp.OutputStream.Write($buffer, 0, $buffer.Length)
            }
        }
        catch {
            Write-Warning "Request error ($path): $_"
            try {
                Set-SecurityHeaders -Response $resp
                $resp.StatusCode = 500
                $errBody = '{"error":"An internal error occurred. Please try again later."}'
                $buffer  = [System.Text.Encoding]::UTF8.GetBytes($errBody)
                $resp.ContentType     = "application/json"
                $resp.ContentLength64 = $buffer.Length
                $resp.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            catch { }
        }
        finally {
            $resp.OutputStream.Close()
        }
    }
}
finally {
    Write-Host ""
    Write-Host "  Shutting down..." -ForegroundColor Yellow
    if ($null -ne (Get-Variable -Name listener -ValueOnly -ErrorAction SilentlyContinue)) {
        try { $listener.Stop() } catch { }
        try { $listener.Close() } catch { }
    }
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  Disconnected from Microsoft Graph. Goodbye!" -ForegroundColor Green
}
