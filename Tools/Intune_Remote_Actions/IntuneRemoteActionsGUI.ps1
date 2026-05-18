<#
.SYNOPSIS
    Intune Remote Actions script with GUI - HTML Web Interface.

.DESCRIPTION
    Launches a local web interface for managing Intune-enrolled devices via Microsoft Graph.
    Supported actions: Wipe, Retire, Sync, Lock (Android/iOS/macOS), Delete, Restart, Shutdown.
    Devices can be targeted by Device Name, Serial Number, or Azure AD Group.

    Run the script and a browser will open automatically at http://localhost:8765/

.NOTES
    - Requires Microsoft.Graph PowerShell SDK modules.
    - Authenticates interactively via Microsoft Graph on first use.
    - For more information:
        https://github.com/UoS-CAVE/Intune_Remote_Actions
        https://learn.microsoft.com/en-us/graph/api/resources/intune-devices-manageddevice?view=graph-rest-1.0
        https://learn.microsoft.com/en-us/mem/intune/remote-actions/device-management
#>

#region Graph Functions

function Get-InnerErrorMessage {
    param ($ErrorRecord)
    $ex = $ErrorRecord.Exception
    $msgs = @()
    while ($ex) {
        if ($ex.Message) { $msgs += $ex.Message }
        $ex = $ex.InnerException
    }
    return ($msgs | Select-Object -Unique) -join ' --> '
}

function Get-DevicesFromAADGroup {
    param ([string]$GroupName)
    try {
        Write-Host "Searching for AAD Group '$GroupName'..." -ForegroundColor Cyan

    # Use $filter with ConsistencyLevel: eventual for exact display name match.
    # $search tokenises on hyphens so is unreliable for names like "Lab-AP2".
    $escaped   = $GroupName -replace "'", "''"
    $groupUri  = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$escaped'&`$count=true&`$select=id,displayName"
    Write-Host "  Graph URI: $groupUri" -ForegroundColor DarkGray

    $groupResp = Invoke-MgGraphRequest -Uri $groupUri -Method GET `
             -Headers @{ ConsistencyLevel = 'eventual' } -ErrorAction Stop

    $group = $groupResp.value | Select-Object -First 1

        if (-not $group) {
            Write-Host "Group '$GroupName' not found in Azure AD." -ForegroundColor Yellow
            return $null
        }

        Write-Host "Found group '$GroupName' (ID: $($group.id))" -ForegroundColor Green

        # Retrieve members, paging through nextLink
        $membersUri = "https://graph.microsoft.com/v1.0/groups/$($group.id)/members?`$top=999"
        $allMembers = @()
        do {
            $membResp   = Invoke-MgGraphRequest -Uri $membersUri -Method GET -ErrorAction Stop
            $allMembers += $membResp.value
            $membersUri  = $membResp.'@odata.nextLink'
        } while ($membersUri)

        Write-Host "  Total group members: $($allMembers.Count)" -ForegroundColor DarkGray

        $devices = @()
        foreach ($member in $allMembers) {
            if ($member.'@odata.type' -ne '#microsoft.graph.device') { continue }
            try {
                $devUri    = "https://graph.microsoft.com/v1.0/devices/$($member.id)?`$select=id,deviceId,displayName"
                $deviceObj = Invoke-MgGraphRequest -Uri $devUri -Method GET -ErrorAction Stop
                if ($deviceObj.deviceId) {
                    $intuneDevice = Get-MgDeviceManagementManagedDevice `
                        -Filter "azureADDeviceId eq '$($deviceObj.deviceId)'" -ErrorAction SilentlyContinue
                    if ($intuneDevice) { $devices += $intuneDevice }
                }
            }
            catch {
                Write-Host "  Could not resolve member $($member.id): $(Get-InnerErrorMessage $_)" -ForegroundColor Yellow
            }
        }

        Write-Host "Found $($devices.Count) Intune device(s) in group '$GroupName'." -ForegroundColor Green
        return $devices
    }
    catch {
        Write-Host "Error retrieving devices from group '$GroupName': $(Get-InnerErrorMessage $_)" -ForegroundColor Red
        return $null
    }
}

function Search-IntuneDevices {
    param (
        [string]$SearchType,
        [string[]]$Values
    )
    $results = @()
    foreach ($val in $Values) {
        $val = $val.Trim()
        if (-not $val) { continue }
        try {
            switch ($SearchType) {
                'displayname' {
                    $devs = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$val'" -ErrorAction SilentlyContinue
                    if ($devs) { $results += @($devs) }
                }
                'serial' {
                    $devs = Get-MgDeviceManagementManagedDevice -Filter "contains(serialNumber,'$val')" -ErrorAction SilentlyContinue
                    if ($devs) { $results += @($devs) }
                }
                'group' {
                    $devs = Get-DevicesFromAADGroup -GroupName $val
                    if ($devs) { $results += @($devs) }
                }
            }
        }
        catch {
            Write-Host "Search error for '$val': $_" -ForegroundColor Yellow
        }
    }
    return $results
}

function Invoke-DeviceAction {
    param (
        [string]$DeviceId,
        [string]$DeviceName,
        [string]$Action
    )
    try {
        switch ($Action) {
            "Wipe"     { Clear-MgDeviceManagementManagedDevice -ManagedDeviceId $DeviceId }
            "Retire"   { Invoke-MgRetireDeviceManagementManagedDevice -ManagedDeviceId $DeviceId }
            "Delete"   { Remove-MgDeviceManagementManagedDevice -ManagedDeviceId $DeviceId -Force }
            "Sync"     { Sync-MgDeviceManagementManagedDevice -ManagedDeviceId $DeviceId }
            "Lock"     { Lock-MgDeviceManagementManagedDeviceRemote -ManagedDeviceId $DeviceId }
            "Restart"  { Restart-MgDeviceManagementManagedDeviceNow -ManagedDeviceId $DeviceId }
            "Shutdown" { Invoke-MgDownDeviceManagementManagedDeviceShut -ManagedDeviceId $DeviceId }
        }
        Write-Host "[OK] $Action on '$DeviceName' succeeded." -ForegroundColor Green
        return @{ success = $true; device = $DeviceName; action = $Action; message = "$Action initiated successfully." }
    }
    catch {
        Write-Host "[ERROR] $Action on '$DeviceName': $($_.Exception.Message)" -ForegroundColor Red
        return @{ success = $false; device = $DeviceName; action = $Action; message = $_.Exception.Message }
    }
}

#endregion

#region HTML Content

$script:HtmlPage = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Intune Remote Actions</title>
<style>
:root{--bg0:#0d1117;--bg1:#161b22;--bg2:#21262d;--border:#30363d;--tx1:#e6edf3;--tx2:#8b949e;--blue:#1f6feb;--blue-h:#388bfd;--green:#238636;--green-t:#3fb950;--red:#da3633;--red-h:#f85149;--orange:#b45309;--orange-t:#e3b341}
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,'Segoe UI',Tahoma,sans-serif;background:var(--bg0);color:var(--tx1);height:100vh;display:flex;flex-direction:column;overflow:hidden}
.hdr{background:var(--bg1);border-bottom:1px solid var(--border);padding:12px 20px;display:flex;align-items:center;justify-content:space-between;flex-shrink:0}
.hdr-left{display:flex;align-items:center;gap:12px}
.hdr h1{font-size:1rem;font-weight:600}
.hdr-sub{font-size:0.75rem;color:var(--tx2)}
.conn-badge{display:flex;align-items:center;gap:7px;padding:5px 11px;border-radius:6px;font-size:0.82rem;font-weight:500}
.conn-badge.off{background:rgba(218,54,51,.12);color:var(--red-h);border:1px solid rgba(218,54,51,.3)}
.conn-badge.on{background:rgba(35,134,54,.12);color:var(--green-t);border:1px solid rgba(35,134,54,.3)}
.dot{width:7px;height:7px;border-radius:50%;background:currentColor}
.layout{display:grid;grid-template-columns:370px 1fr;flex:1;overflow:hidden}
.sidebar{background:var(--bg1);border-right:1px solid var(--border);overflow-y:auto;padding:16px;display:flex;flex-direction:column;gap:14px}
.main{overflow-y:auto;padding:16px;display:flex;flex-direction:column;gap:14px}
.card{background:var(--bg2);border:1px solid var(--border);border-radius:8px;overflow:hidden}
.card-hdr{padding:10px 14px;border-bottom:1px solid var(--border);font-weight:600;font-size:0.85rem;display:flex;align-items:center;justify-content:space-between}
.card-hdr-l{display:flex;align-items:center;gap:7px}
.card-body{padding:14px}
.tabs{display:flex;border-bottom:1px solid var(--border);margin-bottom:10px}
.tab{padding:7px 14px;cursor:pointer;font-size:0.82rem;color:var(--tx2);border-bottom:2px solid transparent;transition:all .15s;user-select:none}
.tab:hover{color:var(--tx1)}
.tab.active{color:var(--blue-h);border-bottom-color:var(--blue-h)}
label{display:block;font-size:0.78rem;color:var(--tx2);margin-bottom:5px}
textarea{width:100%;background:var(--bg0);border:1px solid var(--border);color:var(--tx1);border-radius:6px;padding:8px 10px;font-size:0.82rem;font-family:'Consolas','Courier New',monospace;resize:vertical;min-height:90px}
textarea:focus{outline:none;border-color:var(--blue)}
.btn{padding:7px 14px;border-radius:6px;border:none;cursor:pointer;font-size:0.82rem;font-weight:500;transition:all .15s;display:inline-flex;align-items:center;gap:6px}
.btn:disabled{opacity:.45;cursor:not-allowed}
.btn-primary{background:var(--blue);color:#fff}
.btn-primary:hover:not(:disabled){background:var(--blue-h)}
.btn-danger{background:var(--red);color:#fff}
.btn-danger:hover:not(:disabled){background:var(--red-h)}
.btn-ghost{background:var(--bg2);color:var(--tx1);border:1px solid var(--border)}
.btn-ghost:hover:not(:disabled){background:var(--border)}
.btn-full{width:100%;justify-content:center}
.btn-sm{padding:4px 10px;font-size:0.78rem}
.action-grid{display:grid;grid-template-columns:1fr 1fr;gap:7px}
.at{padding:10px 8px;border-radius:6px;border:1px solid var(--border);cursor:pointer;text-align:center;font-size:0.82rem;font-weight:500;transition:all .15s;background:var(--bg0);color:var(--tx2);user-select:none}
.at:hover{border-color:var(--tx2);color:var(--tx1)}
.at.sel-safe{border-color:var(--blue-h);color:var(--blue-h);background:rgba(31,111,235,.1)}
.at.sel-warn{border-color:var(--orange-t);color:var(--orange-t);background:rgba(180,83,9,.1)}
.at.sel-danger{border-color:var(--red-h);color:var(--red-h);background:rgba(218,54,51,.1)}
.at.span2{grid-column:span 2}
.alert{padding:8px 12px;border-radius:6px;font-size:0.79rem}
.alert-info{background:rgba(31,111,235,.1);border:1px solid rgba(31,111,235,.3);color:#79c0ff}
.alert-warn{background:rgba(180,83,9,.1);border:1px solid rgba(180,83,9,.3);color:var(--orange-t)}
.tbl-wrap{overflow-x:auto}
table{width:100%;border-collapse:collapse;font-size:0.8rem}
thead th{padding:9px 11px;text-align:left;font-weight:600;color:var(--tx2);border-bottom:1px solid var(--border);white-space:nowrap;background:var(--bg1)}
tbody td{padding:9px 11px;border-bottom:1px solid var(--border)}
tbody tr:last-child td{border-bottom:none}
tbody tr:hover{background:rgba(255,255,255,.025)}
tbody tr.sel-row{background:rgba(31,111,235,.07)}
input[type=checkbox]{width:14px;height:14px;cursor:pointer;accent-color:var(--blue-h)}
.badge{display:inline-flex;align-items:center;padding:2px 8px;border-radius:10px;font-size:0.73rem;font-weight:500}
.badge-ok{background:rgba(35,134,54,.2);color:var(--green-t)}
.badge-no{background:rgba(218,54,51,.2);color:var(--red-h)}
.badge-unk{background:rgba(139,148,158,.2);color:var(--tx2)}
.pill{background:var(--blue);color:#fff;border-radius:10px;padding:1px 8px;font-size:0.73rem;font-weight:600;margin-left:5px}
.log-box{background:var(--bg0);border:1px solid var(--border);border-radius:6px;padding:10px;font-family:'Consolas','Courier New',monospace;font-size:0.78rem;min-height:120px;max-height:220px;overflow-y:auto}
.le{padding:2px 0;border-bottom:1px solid rgba(255,255,255,.04)}
.le:last-child{border-bottom:none}
.le-ok{color:var(--green-t)}.le-err{color:var(--red-h)}.le-info{color:var(--tx2)}.le-warn{color:var(--orange-t)}
.empty{text-align:center;padding:36px 20px;color:var(--tx2)}
.empty-icon{font-size:2rem;margin-bottom:10px}
.overlay{position:fixed;inset:0;background:rgba(0,0,0,.72);z-index:200;display:flex;align-items:center;justify-content:center}
.overlay.hidden{display:none}
.modal{background:var(--bg1);border:1px solid var(--border);border-radius:12px;padding:22px;max-width:480px;width:92%}
.modal h3{font-size:0.95rem;margin-bottom:8px}
.modal p{color:var(--tx2);font-size:0.82rem;margin-bottom:14px;line-height:1.5}
.modal-list{background:var(--bg0);border:1px solid var(--border);border-radius:6px;padding:10px;max-height:180px;overflow-y:auto;margin-bottom:16px;font-size:0.8rem}
.modal-item{padding:4px 0;border-bottom:1px solid rgba(255,255,255,.05);color:var(--tx2)}
.modal-item:last-child{border-bottom:none}
.modal-item strong{color:var(--tx1)}
.modal-footer{display:flex;gap:8px;justify-content:flex-end}
.spin{display:inline-block;width:13px;height:13px;border:2px solid rgba(255,255,255,.3);border-top-color:#fff;border-radius:50%;animation:rot .7s linear infinite}
@keyframes rot{to{transform:rotate(360deg)}}
#execBtn{padding:11px 14px;font-size:0.85rem;border-radius:7px;transition:all .15s}
.device-card{flex:1;min-height:200px;display:flex;flex-direction:column}
#devContainer{flex:1;min-height:0;overflow:auto}
</style>
</head>
<body>
<div class="hdr">
  <div class="hdr-left">
    <svg width="26" height="26" viewBox="0 0 23 23" fill="none"><rect x="1" y="1" width="10" height="10" fill="#f25022"/><rect x="12" y="1" width="10" height="10" fill="#7fba00"/><rect x="1" y="12" width="10" height="10" fill="#00a4ef"/><rect x="12" y="12" width="10" height="10" fill="#ffb900"/></svg>
    <div><h1>Intune Remote Actions</h1><div class="hdr-sub">Microsoft Endpoint Manager</div></div>
  </div>
  <div style="display:flex;align-items:center;gap:10px">
    <div id="connBadge" class="conn-badge off"><div class="dot"></div><span id="connText">Not Connected</span></div>
    <button class="btn btn-primary" id="connBtn" onclick="handleConnect()">Connect to Graph</button>
  </div>
</div>
<div class="layout">
  <div class="sidebar">
    <div class="card">
      <div class="card-hdr"><div class="card-hdr-l"><svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M8 1a7 7 0 1 0 0 14A7 7 0 0 0 8 1zM0 8a8 8 0 1 1 16 0A8 8 0 0 1 0 8z"/><path d="M8 5a3 3 0 1 0 0 6A3 3 0 0 0 8 5zm-4 3a4 4 0 1 1 8 0 4 4 0 0 1-8 0z"/></svg>Target Devices</div></div>
      <div class="card-body">
        <div class="tabs">
          <div class="tab active" onclick="setTab('displayname',this)">Device Names</div>
          <div class="tab" onclick="setTab('serial',this)">Serials</div>
          <div class="tab" onclick="setTab('group',this)">AAD Groups</div>
        </div>
        <div id="tabHint" class="alert alert-info" style="margin-bottom:10px;font-size:0.77rem">Enter one device name per line</div>
        <label>Values <span style="color:var(--tx2)">(one per line)</span></label>
        <textarea id="targetInput" placeholder="e.g.&#10;DESKTOP-ABC123&#10;LAPTOP-XYZ789"></textarea>
        <button class="btn btn-primary btn-full" style="margin-top:9px" id="searchBtn" onclick="handleSearch()" disabled>
          <svg width="13" height="13" viewBox="0 0 16 16" fill="currentColor"><path d="M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1.007 1.007 0 0 0-.115-.099zM2.5 6.5a4 4 0 1 1 8 0 4 4 0 0 1-8 0z"/></svg>
          Search Devices
        </button>
      </div>
    </div>
    <div class="card">
      <div class="card-hdr"><div class="card-hdr-l"><svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14zm0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16z"/><path d="M10.97 4.97a.235.235 0 0 0-.02.022L7.477 9.417 5.384 7.323a.75.75 0 0 0-1.06 1.06L6.97 11.03a.75.75 0 0 0 1.079-.02l3.992-4.99a.75.75 0 0 0-1.071-1.05z"/></svg>Select Action</div></div>
      <div class="card-body">
        <div class="alert alert-warn" style="margin-bottom:11px;font-size:0.77rem">&#9888;&#65039; Wipe, Retire &amp; Delete are irreversible</div>
        <div class="action-grid">
          <div class="at" id="at-Sync" onclick="selAction('Sync',this,'safe')">&#x1F504; Sync</div>
          <div class="at" id="at-Restart" onclick="selAction('Restart',this,'safe')">&#x21BA; Restart</div>
          <div class="at" id="at-Lock" onclick="selAction('Lock',this,'warn')">&#x1F512; Lock</div>
          <div class="at" id="at-Shutdown" onclick="selAction('Shutdown',this,'warn')">&#x23FB; Shutdown</div>
          <div class="at" id="at-Retire" onclick="selAction('Retire',this,'warn')">&#x1F4E4; Retire</div>
          <div class="at" id="at-Delete" onclick="selAction('Delete',this,'danger')">&#x1F5D1; Delete</div>
          <div class="at span2" id="at-Wipe" onclick="selAction('Wipe',this,'danger')">&#x26A0;&#65039; Wipe</div>
        </div>
      </div>
    </div>
    <button class="btn btn-full" id="execBtn" onclick="handleExecute()" disabled style="padding:11px;border:1px solid var(--border)">Execute Action on Selected Devices</button>
  </div>
  <div class="main">
        <div class="card device-card">
      <div class="card-hdr">
        <div class="card-hdr-l"><svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M1 3.5A1.5 1.5 0 0 1 2.5 2h11A1.5 1.5 0 0 1 15 3.5v9a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 1 12.5v-9zm13 0a.5.5 0 0 0-.5-.5h-11a.5.5 0 0 0-.5.5v9a.5.5 0 0 0 .5.5h11a.5.5 0 0 0 .5-.5v-9z"/></svg>Devices<span id="devPill" class="pill" style="display:none">0</span></div>
        <div style="display:flex;gap:7px">
          <button class="btn btn-ghost btn-sm" onclick="selAll(true)">Select All</button>
          <button class="btn btn-ghost btn-sm" onclick="selAll(false)">Deselect All</button>
        </div>
      </div>
      <div id="devContainer">
        <div class="empty"><div class="empty-icon">&#x1F5A5;</div><div>No devices loaded</div><div style="font-size:0.78rem;margin-top:7px">Connect to Graph, then search for devices</div></div>
      </div>
    </div>
    <div class="card">
      <div class="card-hdr">
        <div class="card-hdr-l"><svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M5 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2H5zm0 1h6a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1z"/><path d="M6 7h4v1H6V7zm0 2h4v1H6V9z"/></svg>Action Log</div>
        <button class="btn btn-ghost btn-sm" onclick="clearLog()">Clear</button>
      </div>
      <div class="card-body" style="padding:8px">
        <div class="log-box" id="logBox"><div class="le le-info">[System] Ready. Connect to Microsoft Graph to begin.</div></div>
      </div>
    </div>
  </div>
</div>
<div class="overlay hidden" id="confirmModal">
  <div class="modal">
    <h3 id="mTitle">Confirm Action</h3>
    <p id="mDesc">Are you sure?</p>
    <div class="modal-list" id="mList"></div>
    <div class="modal-footer">
      <button class="btn btn-ghost" onclick="closeModal()">Cancel</button>
      <button class="btn btn-danger" id="mConfirmBtn" onclick="doExecute()">Confirm</button>
    </div>
  </div>
</div>
<script>
var tab='displayname',action=null,actionRisk=null,devices=[],pending=null;
var tabHints={displayname:'Enter one device name (hostname) per line',serial:'Enter one serial number per line',group:'Enter one Azure AD group display name per line'};
var tabPH={displayname:'e.g.\nDESKTOP-ABC123\nLAPTOP-XYZ789',serial:'e.g.\nC02ABC1234\nXYZ789012',group:'e.g.\nMarketing Devices\nFinance Laptops'};
var riskColor={safe:'#1f6feb',warn:'#b45309',danger:'#da3633'};
window.addEventListener('load',checkStatus);
function checkStatus(){fetch('/status').then(function(r){return r.json()}).then(function(d){if(d.connected)setConnected(d.account,d.tenant)}).catch(function(){})}
function setTab(t,el){tab=t;document.querySelectorAll('.tab').forEach(function(x){x.classList.remove('active')});el.classList.add('active');document.getElementById('tabHint').textContent=tabHints[t];var ta=document.getElementById('targetInput');ta.value='';ta.placeholder=tabPH[t]}
function selAction(a,el,risk){document.querySelectorAll('.at').forEach(function(x){x.className=x.className.replace(/\bsel-\w+/g,'').trim()});el.classList.add('sel-'+risk);action=a;actionRisk=risk;updateExecBtn();addLog('Action selected: '+a,'info')}
function updateExecBtn(){var btn=document.getElementById('execBtn');var sel=devices.filter(function(d){return d._sel});btn.disabled=!action||sel.length===0;if(action&&sel.length>0){btn.textContent='Execute "'+action+'" on '+sel.length+' device'+(sel.length>1?'s':'');btn.style.background=riskColor[actionRisk]||'#1f6feb';btn.style.color='#fff';btn.style.border='none';btn.style.cursor='pointer'}else{btn.textContent='Execute Action on Selected Devices';btn.style.background='';btn.style.color='';btn.style.border='1px solid var(--border)'}}
async function handleConnect(){var btn=document.getElementById('connBtn');var status=await fetch('/status').then(function(r){return r.json()}).catch(function(){return{connected:false}});if(status.connected){btn.disabled=true;btn.innerHTML='<span class="spin"></span> Disconnecting...';try{await fetch('/disconnect',{method:'POST'});setDisconnected();addLog('Disconnected from Microsoft Graph.','warn')}catch(e){addLog('Disconnect error: '+e.message,'err')}finally{btn.disabled=false}}else{btn.disabled=true;btn.innerHTML='<span class="spin"></span> Connecting...';addLog('Connecting to Microsoft Graph... (a browser authentication window may open)','info');try{var res=await fetch('/connect',{method:'POST'});var data=await res.json();if(data.success){setConnected(data.account,data.tenant);addLog('Connected as '+data.account+' | Tenant: '+data.tenant,'ok')}else{addLog('Connection failed: '+(data.error||'Unknown error'),'err');btn.disabled=false;btn.textContent='Connect to Graph';btn.className='btn btn-primary'}}catch(e){addLog('Connection error: '+e.message,'err');btn.disabled=false;btn.textContent='Connect to Graph';btn.className='btn btn-primary'}}}
function setConnected(account,tenant){var b=document.getElementById('connBadge');b.className='conn-badge on';document.getElementById('connText').textContent=account||'Connected';var btn=document.getElementById('connBtn');btn.textContent='Disconnect';btn.className='btn btn-ghost';btn.disabled=false;document.getElementById('searchBtn').disabled=false}
function setDisconnected(){var b=document.getElementById('connBadge');b.className='conn-badge off';document.getElementById('connText').textContent='Not Connected';var btn=document.getElementById('connBtn');btn.textContent='Connect to Graph';btn.className='btn btn-primary';btn.disabled=false;document.getElementById('searchBtn').disabled=true;devices=[];renderTable()}
async function handleSearch(){var raw=document.getElementById('targetInput').value.trim();if(!raw){addLog('Enter at least one search value.','warn');return}var values=raw.split('\n').map(function(v){return v.trim()}).filter(function(v){return v});var btn=document.getElementById('searchBtn');btn.disabled=true;btn.innerHTML='<span class="spin"></span> Searching...';addLog('Searching '+values.length+' target(s) by '+tab+'...','info');try{var res=await fetch('/search',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({searchType:tab,values:values})});var data=await res.json();if(data.success){devices=(data.devices||[]).map(function(d){return Object.assign({},d,{_sel:true})});renderTable();addLog('Found '+devices.length+' device(s).',devices.length>0?'ok':'warn')}else{addLog('Search error: '+(data.error||'Unknown'),'err')}}catch(e){addLog('Search failed: '+e.message,'err')}finally{btn.disabled=false;btn.innerHTML='<svg width="13" height="13" viewBox="0 0 16 16" fill="currentColor"><path d="M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1.007 1.007 0 0 0-.115-.099zM2.5 6.5a4 4 0 1 1 8 0 4 4 0 0 1-8 0z"/></svg> Search Devices'}updateExecBtn()}
function renderTable(){var c=document.getElementById('devContainer');var pill=document.getElementById('devPill');if(!devices.length){c.innerHTML='<div class="empty"><div class="empty-icon">&#x1F5A5;</div><div>No devices found</div><div style="font-size:0.78rem;margin-top:7px">Try different search terms</div></div>';pill.style.display='none';return}pill.textContent=devices.length;pill.style.display='inline';var rows=devices.map(function(d,i){var bc=d.compliance==='compliant'?'badge-ok':d.compliance==='noncompliant'?'badge-no':'badge-unk';return'<tr class="'+(d._sel?'sel-row':'')+'" onclick="toggleDev('+i+')" style="cursor:pointer"><td><input type="checkbox"'+(d._sel?' checked':'')+' onclick="event.stopPropagation();toggleDev('+i+')"></td><td><strong>'+esc(d.name)+'</strong></td><td style="color:var(--tx2);font-family:Consolas,monospace">'+esc(d.serial)+'</td><td>'+esc(d.os)+'</td><td style="color:var(--tx2)">'+esc(d.osVersion)+'</td><td style="color:var(--tx2)">'+esc(d.lastSync)+'</td><td><span class="badge '+bc+'">'+esc(d.compliance||'unknown')+'</span></td></tr>'}).join('');c.innerHTML='<div class="tbl-wrap"><table><thead><tr><th style="width:34px"></th><th>Device Name</th><th>Serial Number</th><th>OS</th><th>Version</th><th>Last Sync</th><th>Compliance</th></tr></thead><tbody>'+rows+'</tbody></table></div>'}
function toggleDev(i){devices[i]._sel=!devices[i]._sel;renderTable();updateExecBtn()}
function selAll(v){devices=devices.map(function(d){return Object.assign({},d,{_sel:v})});renderTable();updateExecBtn()}
function handleExecute(){if(!action){addLog('Select an action first.','warn');return}var sel=devices.filter(function(d){return d._sel});if(!sel.length){addLog('Select at least one device.','warn');return}pending={action:action,risk:actionRisk,devices:sel.map(function(d){return{id:d.id,name:d.name,serial:d.serial}})};var isDanger=actionRisk==='danger'||actionRisk==='warn';document.getElementById('mTitle').textContent=(isDanger?'\u26a0 ':'')+' Confirm: '+action;document.getElementById('mDesc').textContent='You are about to perform "'+action+'" on '+sel.length+' device'+(sel.length>1?'s':'')+'.'+(actionRisk==='danger'?' This action is IRREVERSIBLE and cannot be undone.':'');document.getElementById('mList').innerHTML=sel.map(function(d){return'<div class="modal-item"><strong>'+esc(d.name)+'</strong>'+(d.serial?' &mdash; '+esc(d.serial):'')+' </div>'}).join('');var cb=document.getElementById('mConfirmBtn');cb.textContent='Confirm '+action;cb.className=actionRisk==='danger'?'btn btn-danger':'btn btn-primary';document.getElementById('confirmModal').classList.remove('hidden')}
function closeModal(){document.getElementById('confirmModal').classList.add('hidden');pending=null}
async function doExecute(){if(!pending)return;closeModal();var act=pending.action,devs=pending.devices;var btn=document.getElementById('execBtn');btn.disabled=true;btn.innerHTML='<span class="spin"></span> Executing...';addLog('Executing "'+act+'" on '+devs.length+' device(s)...','info');try{var res=await fetch('/execute',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:act,devices:devs})});var data=await res.json();if(data.results){data.results.forEach(function(r){if(r.success)addLog('\u2713 '+r.device+': '+r.message,'ok');else addLog('\u2717 '+r.device+': '+r.message,'err')})}}catch(e){addLog('Execution error: '+e.message,'err')}finally{updateExecBtn()}}
function addLog(msg,type){var box=document.getElementById('logBox');var ts=new Date().toLocaleTimeString('en-GB');var div=document.createElement('div');div.className='le le-'+(type||'info');div.textContent='['+ts+'] '+msg;box.appendChild(div);box.scrollTop=box.scrollHeight}
function clearLog(){document.getElementById('logBox').innerHTML='';addLog('Log cleared.','info')}
function esc(s){if(s==null)return'';return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;')}
document.getElementById('confirmModal').addEventListener('click',function(e){if(e.target===this)closeModal()});
</script>
</body>
</html>
'@

#endregion

#region HTTP Server

function Send-Response {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [string]$Content,
        [string]$ContentType = "text/html; charset=utf-8",
        [int]$StatusCode = 200
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
    $Response.StatusCode = $StatusCode
    $Response.ContentType = $ContentType
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Response.Close()
}

function Get-RequestBody {
    param([System.Net.HttpListenerRequest]$Request)
    $reader = [System.IO.StreamReader]::new($Request.InputStream, [System.Text.Encoding]::UTF8)
    $body = $reader.ReadToEnd()
    $reader.Close()
    return $body
}

function Start-WebInterface {
    $port    = 8765
    $baseUrl = "http://localhost:$port/"

    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add($baseUrl)

    try {
        $listener.Start()
    }
    catch {
        Write-Host ""
        Write-Host "  ERROR: Could not start web server on port $port." -ForegroundColor Red
        Write-Host "  Ensure no other process is using port $port, or run as Administrator." -ForegroundColor Yellow
        Write-Host "  Details: $_" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "  ======================================================" -ForegroundColor Cyan
    Write-Host "   Intune Remote Actions - Web Interface" -ForegroundColor Green
    Write-Host "  ======================================================" -ForegroundColor Cyan
    Write-Host "   URL  : $baseUrl" -ForegroundColor White
    Write-Host "   Stop : Ctrl+C" -ForegroundColor Yellow
    Write-Host "  ======================================================" -ForegroundColor Cyan
    Write-Host ""

    Start-Process $baseUrl

    try {
        while ($listener.IsListening) {
            $pendingRequest = $listener.BeginGetContext($null, $null)
            if (-not $pendingRequest.AsyncWaitHandle.WaitOne(200)) {
                continue
            }

            $context = $listener.EndGetContext($pendingRequest)
            $req     = $context.Request
            $res     = $context.Response
            $path    = $req.Url.LocalPath
            $method  = $req.HttpMethod

            try {
                # GET / - Serve the HTML page
                if ($method -eq 'GET' -and $path -eq '/') {
                    Send-Response -Response $res -Content $script:HtmlPage
                }

                # GET /status - Check Graph connection
                elseif ($method -eq 'GET' -and $path -eq '/status') {
                    $ctx = Get-MgContext -ErrorAction SilentlyContinue
                    if ($ctx) {
                        $json = [pscustomobject]@{ connected = $true; tenant = $ctx.TenantId; account = $ctx.Account } | ConvertTo-Json -Compress
                    }
                    else {
                        $json = '{"connected":false}'
                    }
                    Send-Response -Response $res -Content $json -ContentType "application/json"
                }

                # POST /connect - Authenticate to Microsoft Graph
                elseif ($method -eq 'POST' -and $path -eq '/connect') {
                    try {
                        Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All","Group.Read.All","GroupMember.Read.All" -NoWelcome -ErrorAction Stop
                        $ctx  = Get-MgContext
                        $json = [pscustomobject]@{ success = $true; tenant = $ctx.TenantId; account = $ctx.Account } | ConvertTo-Json -Compress
                    }
                    catch {
                        $errMsg = $_.Exception.Message -replace '"', "'"
                        $json   = "{`"success`":false,`"error`":`"$errMsg`"}"
                    }
                    Send-Response -Response $res -Content $json -ContentType "application/json"
                }

                # POST /disconnect - Sign out of Graph
                elseif ($method -eq 'POST' -and $path -eq '/disconnect') {
                    try { Disconnect-MgGraph | Out-Null } catch {}
                    Send-Response -Response $res -Content '{"success":true}' -ContentType "application/json"
                }

                # POST /search - Find Intune devices
                elseif ($method -eq 'POST' -and $path -eq '/search') {
                    $body   = Get-RequestBody -Request $req | ConvertFrom-Json
                    $values = @($body.values)
                    $found  = Search-IntuneDevices -SearchType $body.searchType -Values $values

                    if ($found -and $found.Count -gt 0) {
                        $list = @($found) | ForEach-Object {
                            $ls = if ($_.LastSyncDateTime) { $_.LastSyncDateTime.ToString("yyyy-MM-dd HH:mm") } else { "Never" }
                            [pscustomobject]@{
                                id         = $_.Id
                                name       = $_.DeviceName
                                serial     = $_.SerialNumber
                                os         = $_.OperatingSystem
                                osVersion  = $_.OsVersion
                                lastSync   = $ls
                                compliance = $_.ComplianceState
                            }
                        }
                        # Build JSON array manually - works on all PS versions
                        $devicesJson = '[' + ((@($list) | ForEach-Object { ConvertTo-Json -InputObject $_ -Depth 5 -Compress }) -join ',') + ']'
                        $json = "{`"success`":true,`"devices`":$devicesJson}"
                    }
                    else {
                        $json = '{"success":true,"devices":[]}'
                    }
                    Send-Response -Response $res -Content $json -ContentType "application/json"
                }

                # POST /execute - Run a remote action on selected devices
                elseif ($method -eq 'POST' -and $path -eq '/execute') {
                    $body       = Get-RequestBody -Request $req | ConvertFrom-Json
                    $action     = $body.action
                    $deviceList = @($body.devices)

                    $results = foreach ($device in $deviceList) {
                        Invoke-DeviceAction -DeviceId $device.id -DeviceName $device.name -Action $action
                    }

                    $resultsJson = '[' + ((@($results) | ForEach-Object { ConvertTo-Json -InputObject $_ -Depth 5 -Compress }) -join ',') + ']'
                    $json = "{`"results`":$resultsJson}"
                    Send-Response -Response $res -Content $json -ContentType "application/json"
                }

                else {
                    $res.StatusCode = 404
                    $res.Close()
                }
            }
            catch {
                $errMsg  = $_.Exception.Message -replace '"', "'"
                $errJson = "{`"error`":`"$errMsg`"}"
                try {
                    $res.StatusCode = 500
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($errJson)
                    $res.ContentType = "application/json"
                    $res.ContentLength64 = $bytes.Length
                    $res.OutputStream.Write($bytes, 0, $bytes.Length)
                    $res.Close()
                }
                catch {}
                Write-Host "  [Request Error] $method $path - $_" -ForegroundColor Red
            }
        }
    }
    catch [System.Net.HttpListenerException] {
        # Normal shutdown via Ctrl+C
    }
    finally {
        if ($listener.IsListening) { $listener.Stop() }
        Write-Host ""
        Write-Host "  Web interface stopped." -ForegroundColor Yellow
    }
}

#endregion

# Entry point
Start-WebInterface
