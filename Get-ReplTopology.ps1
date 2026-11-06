<#
.SYNOPSIS
    Discovers and draws SQL Server replication topology (transactional, snapshot,
    merge, peer-to-peer) across many servers, including republishing chains and
    Always On availability groups, with agent health, audit findings and changes
    since a previous run. Three modes: the topology report (default), -Monitor (live
    replication monitor in the browser) and -Console (the same monitor in the console window).

.DESCRIPTION
    Script  : Get-ReplTopology.ps1
    Version : 1.9
    Author  : Wojtek Kuncewicz
    Created : 2017-03-14

    Version history:
        1.0  2017-03-14  Wojtek  Initial version.
        1.1  2026-11-05  Wojtek  Review of how the script works. All text translated
                                 to English. Mermaid library can be embedded in the HTML
                                 (works offline), CDN fallback chain added.
                                 PDF export (topology.pdf) via headless Edge/Chrome
                                 (browser console output hidden).
        1.2  2026-11-05  Wojtek  Agent health on the diagram (status, latency, last sync,
                                 pending commands, last error). Articles (tables) per
                                 publication. Comparison with a previous run (-CompareTo).
                                 Arrows between the same databases merged into one.
                                 Filter redraws the diagram. PDF paper size and pages per
                                 server. Name aliases (AG listeners, IPs, -Alias).
                                 Merge status no longer read from MSmerge_subscriptions
                                 (column not used by SQL Server). Microsoft.Data.SqlClient
                                 support (Encrypt Strict, Entra ID), certificate validation
                                 (-StrictCert), servers queried in parallel.
        1.3  2026-11-05  Wojtek  Connection test before the report (DNS, port, login, with
                                 hints) and -TestOnly. Servers on non-default ports: ports from
                                 the server list, AG listeners and read-only routing URLs are
                                 reused while crawling. SQL login with -SqlUser (password
                                 prompt). Availability groups: databases in an AG are shown
                                 under the listener, so a failover does not change the
                                 topology. Agent jobs (disabled, not running, SQL Server Agent
                                 stopped, -SkipErrors), Log Reader health, publisher log usage,
                                 failures in the last hours, row counts publisher vs subscriber.
                                 Findings: version compatibility and upgrade limits, end of
                                 support, distribution database, publication settings,
                                 security, leftovers. Table lineage, impact view (click a
                                 database or a server). Fixes: '-Servers .', instances on
                                 different ports of one host, pending commands without
                                 sysadmin/db_owner, -CompareTo with an unreachable
                                 distributor, slow article list, CSV for Excel.
        1.4  2026-11-05  Wojtek  -Monitor: live replication monitor in the browser, served by the
                                 script itself (no IIS, no modules). Agent status, latency, pending
                                 commands (Replication Monitor rules, one query for all
                                 subscriptions, no db_owner needed), age of the oldest undelivered
                                 transaction, flow in commands per second, agent sessions with the
                                 current wait and the blocking chain (head blocker and its SQL), wait
                                 profile of every agent and server, AG replica state (a synchronous
                                 secondary that is not synchronized holds the Log Reader back),
                                 replication errors with the cause and the failing command
                                 (sp_browsereplcmds), events, filters, sorting, diagram with live
                                 colors and moving flow. Detail of a subscription: history charts,
                                 pending commands per article, largest pending transactions, agent
                                 statistics (reader or writer bottleneck), tracer tokens.
        1.5  2026-11-05  Wojtek  -Console: the live monitor drawn in the console window
                                 (full-screen text view, keys, the same data as the web page:
                                 subscriptions, Log Readers, blocking and waits, AG, errors with
                                 the failing command, events, servers, findings, detail with
                                 history, pending per article, agent statistics, tracer tokens).
                                 Line mode where the window cannot draw it (ISE, remote session,
                                 redirected output). Monitor: a continuous agent whose oldest
                                 undelivered transaction is 5+ minutes old is flagged even when
                                 SQL Server reports it as running; agent statistics shown as text;
                                 errors ordered correctly across distribution databases.
        1.6  2026-11-05  Wojtek  Full review of both monitors. A server that stops answering no
                                 longer leaves its last data on screen (no stale health, sessions,
                                 waits or pending counts). Agent sessions at the subscriber are also
                                 found by the end of their program name (named instances) and with
                                 case-sensitive collations. Console: views are cached (moving the
                                 selection and scrolling are instant; new data waits while keys are
                                 pressed), only characters of the console code pages 437/850/852,
                                 small windows and drawing errors do not stop it, the console colors
                                 are restored on exit. One faulty answer no longer stops a monitor.
                                 Errors per hour by the distributor's clock, invariant date format,
                                 per-session wait snapshots pruned, clear message for a wrong
                                 -ListenAddress.
        1.6.1 2026-11-06 Wojtek  Error list of the monitors: the details of an error (written
                                 under the next id) stay with their error also when the error came
                                 with the previous refresh or lies just outside the first window,
                                 so no more "unknown agent" entries; "scheduled for retry" messages
                                 name their agent too. Web page: a .NET stack trace in an agent
                                 error is folded, long words wrap. Console: no stray separator in
                                 the detail when the status is empty, clearer message for c.
        1.7  2026-11-06  Wojtek  Finding for replication with availability groups: every replica of a
                                 published AG database has to be a publisher at the distributor
                                 (msdb.dbo.MSdistpublishers) and the original publisher has to be
                                 redirected to the listener - otherwise a failover stops the Log
                                 Reader. Console: the job state fits the Status column. Both monitors:
                                 the pending commands per article show when they were read. Test bed
                                 for development in tests/ (Docker, see tests/README.md).
        1.7.1 2026-11-06 Wojtek  Diagram: server frames no longer overlap (Mermaid sizes a frame by its
                                 content, not by its title - long titles such as an AG listener with
                                 its primary pushed frames over each other). Titles go on several
                                 lines and an invisible copy keeps the room for them.
        1.8  2026-11-06  Wojtek  -Scan / -ScanHost: SQL Server instances on this computer and from
                                 SQL Browser (UDP 1434), picked from a list, saved to servers.txt.
                                 Repairs: a catalog of fixes for the common problems (agent jobs,
                                 snapshot, reinitialize, data errors 20598/2601/2627 - skip the
                                 transaction or tablediff, sp_replrestart, sp_repldone, passwords,
                                 clean up job, AG registration and redirection) with levels safe
                                 (-AllowRepair), full (-AllowAllRepair, typed confirmation) and
                                 script (never run). Monitors: Repairs in the detail (T-SQL, save,
                                 run step by step, repairs.log); report: repairs.sql. Reports for
                                 an AI assistant (monitor item or whole run) with names and values
                                 masked, the tokens in a separate file (-NoMask to switch off).
        1.9  2026-11-06  Wojtek  Article filters: the row filter and the columns a column filter leaves
                                 out are read always (also in the monitors) and shown in the Articles
                                 table, articles.csv, the monitor detail and the AI report.
                                 -FilteredRowCounts counts the publisher rows with the row filter, so
                                 filtered tables are compared too. A data error on a filtered article
                                 offers a filtered count comparison instead of tablediff (its fix would
                                 copy the rows and columns the filter leaves out).

    How it works:
    - No modules to install (uses System.Data.SqlClient from .NET). Runs in Windows
      PowerShell 5.1 and PowerShell 7. Microsoft.Data.SqlClient (SqlServer module) is
      loaded only for -Encrypt Strict, -Authentication or -SqlClient Microsoft.
    - First every start server is tested (in parallel): name resolution, TCP port, login.
      The table shows the real server name, port, login and sysadmin rights, or the reason
      of the failure with a hint. -TestOnly stops here.
    - Then the script crawls from the reachable servers. On each server it reads databases,
      availability groups, replication agent jobs (msdb), the distributor (local or remote)
      and from every distribution database: publications, subscriptions, articles, agent
      health (sp_replmonitorhelpsubscription - the procedure Replication Monitor uses, last
      agent messages, errors, failures in the last -HistoryHours), pending commands
      (sp_replmonitorsubscriptionpendingcmds), distribution database size and retention,
      AG redirections (MSredirected_publishers).
    - Every publisher, subscriber and distributor found is added to the crawl. A server
      that was reached on a special port (from the list, an AG listener port, a read-only
      routing URL) is always contacted the same way later.
    - Databases that belong to an availability group are drawn under the AG listener, so the
      picture and -CompareTo do not change after a failover.
    - Optionally row counts of every replicated table are compared between publisher and
      subscriber (from metadata, no data is read).
    - With -Monitor the same discovery runs first, then the script stays running as a small web
      server (http://localhost:8642; the address with an access key is printed and opened). Every
      server is queried on its own schedule (-RefreshSeconds) in the background and the page
      refreshes by itself. Stop with Ctrl+C or the Stop button. No files are written.
    - With -Console the monitor is drawn in the console window instead (no web server). Keys:
      1-8 views, Up/Down select, Enter detail, / filter, p quick filter, s sort, Esc back or clear,
      Space pause, r refresh now, +/- interval, q quit; in a detail h history, r reload,
      t tracer token, c failing command. In PowerShell ISE, a remote session or with redirected
      output the changes are printed line by line.

    Server list file (-Servers .\servers.txt), one entry per line, # starts a comment:
        SQL01                   # default instance, port 1433
        SQL02\INST1             # named instance through SQL Browser
        SQL03,50001             # non-default port
        SQL04\INST2,50002       # named instance on a fixed port (no SQL Browser needed)
        AGL-SALES,1450          # AG listener on a non-default port

    Output (in -OutputDir):
        topology.html    - interactive diagram (Mermaid), findings and tables
        topology.pdf     - the same page as PDF (needs Edge or Chrome; see -NoPdf)
        topology.mmd     - Mermaid diagram (wiki / Azure DevOps / GitHub / draw.io)
        topology.dot     - Graphviz:  dot -Tsvg topology.dot -o topology.svg
        topology.json    - all data; pass the folder to -CompareTo on the next run
        findings.csv     - everything worth a look, with recommendations
        edges.csv        - publication -> subscription relations with health
        articles.csv     - articles (tables) per publication
        rowcounts.csv    - row counts publisher vs subscriber
        servers.csv      - visited servers, versions, roles, errors
        connections.csv  - result of the connection test
        changes.csv      - differences against -CompareTo (only with -CompareTo)
    CSV files use the list separator of Windows regional settings and UTF-8 with BOM
    (they open correctly in Excel).

    The HTML diagram is drawn by the Mermaid library (automatic layout of servers,
    databases and arrows). If mermaid.min.js is next to the script, it is embedded
    in topology.html (works without internet). Otherwise the page loads Mermaid from
    the internet (jsDelivr / unpkg / cdnjs).

    Live monitor (-Monitor) - what Replication Monitor in SSMS does not show:
        Overview       diagram colored by live health (moving dashes = commands flowing, purple =
                       blocked), "Needs attention" list, state of every queried server
        Subscriptions  status, latency, pending commands with the time to deliver them, age of the
                       oldest undelivered transaction, commands/s, wait of the agent session,
                       problems, trends (sparklines)
        Log Readers    latency, commands/s, AG state of the published database
        Sessions & waits  blocking chains with the head blocker (often a sleeping session with an
                       open transaction) and its SQL, sessions blocked by an agent, agent sessions
                       (state, wait, CPU, reads/writes, SQL), waits per agent and per server
        Availability groups  roles, synchronization, send and redo queue, lag of every replica
        Errors         MSrepl_errors per error event with the cause, repeats collapsed, the failing
                       command (sp_browsereplcmds) and what to do about it
        Events         health changes, blocking, new errors, servers lost and back
        Findings       the audit of the discovery
    Clicking a subscription or a Log Reader shows history charts (latency, commands, status),
    pending commands per article, the largest pending transactions, errors, agent statistics (is
    reading from the distributor or applying at the subscriber the bottleneck) and tracer tokens.
    Quick filters (problems, errors, blocked, pending, not running, latency), the text filter and
    the server filter act on every tab and on the diagram. Colors: latency 30 s warning / 300 s
    error; pending commands -PendingWarn / 10 x -PendingWarn. The monitor only reads, except
    tracer tokens with -AllowTracerTokens.

    Permissions: sysadmin everywhere gives the full report. With less: in every distribution
    database db_datareader (the topology is read from the MS* tables - the replmonitor role
    alone cannot read them) and replmonitor (agent health); pending commands need db_owner in
    the distribution database; agent jobs, profiles and retention need read access to msdb
    (e.g. SQLAgentReaderRole); log usage, AG roles and SQL Server Agent state need
    VIEW SERVER STATE (SQL 2022: VIEW SERVER PERFORMANCE STATE); AG listeners and replicas
    need VIEW ANY DEFINITION; row counts need access to the replicated databases.
    Whatever could not be checked is listed under Findings (Coverage).
    Monitor: agent state and pending commands need db_datareader + replmonitor in the distribution
    database (no db_owner); sessions, blocking, waits and AG state need VIEW SERVER STATE on each
    server; tracer tokens need sysadmin or db_owner in the publication database.
    By default the script only reads - it changes no replication settings and no data. Writes
    are switched on by -AllowTracerTokens (tracer tokens) and -AllowRepair / -AllowAllRepair
    (repairs; jobs need SQLAgentOperatorRole or sysadmin, the other repairs db_owner or sysadmin).

.PARAMETER Servers
    Start servers (e.g. SQL01, SQL02\INST, 10.0.0.5,1433)
    or a path to a text file with one entry per line (see the format above). Not needed with -Scan.

.PARAMETER Scan
    Find SQL Server instances on this computer (registry, services) and in the local subnet (SQL
    Browser, UDP 1434 broadcast), pick them from a list and optionally save them to servers.txt.

.PARAMETER ScanHost
    Like -Scan, but asks SQL Browser on the given hosts (works across subnets).

.PARAMETER OutputDir
    Output folder (default: .\ReplTopology).

.PARAMETER SqlCredential
    SQL login as a credential object, e.g. $c = Get-Credential sa; -SqlCredential $c
    (useful when you run the script several times in one session).

.PARAMETER SqlUser
    SQL login name, e.g. -SqlUser sa. The script asks for the password. Without -SqlUser
    and -SqlCredential Windows authentication is used.

.PARAMETER Authentication
    Entra ID (Azure AD) authentication: ActiveDirectoryIntegrated, ActiveDirectoryInteractive,
    ActiveDirectoryPassword (with -SqlUser / -SqlCredential), ActiveDirectoryDefault,
    ActiveDirectoryManagedIdentity. Needs Microsoft.Data.SqlClient (SqlServer module).

.PARAMETER Encrypt
    Connection encryption: Optional (default), Mandatory or Strict (TDS 8, SQL 2022+;
    needs Microsoft.Data.SqlClient).

.PARAMETER StrictCert
    Validate the server certificate (by default any certificate is accepted).

.PARAMETER SqlClient
    Auto (default: System.Data.SqlClient, Microsoft.Data.SqlClient only when a feature
    needs it), System or Microsoft.

.PARAMETER TestOnly
    Only test the connections to the start servers (table + connections.csv), no report.

.PARAMETER NoCrawl
    Query only the given servers (plus their remote distributors), no crawling.

.PARAMETER KeepDomain
    Keep the domain in names (by default SQL01.company.local == SQL01).

.PARAMETER Alias
    Extra name mapping, e.g. @{ 'OLDNAME' = 'SQL01'; '10.0.0.5' = 'SQL02' }.

.PARAMETER HideDistributors
    Do not draw distributor nodes and publisher -> distributor lines.

.PARAMETER ExpandEdges
    One arrow per publication (by default arrows between the same two databases are
    merged into one).

.PARAMETER NoHealth
    Do not read agent health.

.PARAMETER NoPendingCommands
    Do not count pending commands (one sp_replmonitorsubscriptionpendingcmds call per
    transactional subscription; can be slow on a very large distribution database).

.PARAMETER NoRowCounts
    Do not compare row counts between publisher and subscriber tables.

.PARAMETER PendingWarn
    Pending commands from which a subscription is shown as a warning (default 10000).

.PARAMETER HistoryHours
    How many hours of agent history are checked for failures and retries (default 24).

.PARAMETER LogUsedWarn
    Percent of the publisher's transaction log in use (while the log waits for replication)
    from which a warning is shown (default 70; 90 and more is an error).

.PARAMETER CompareTo
    Folder (or topology.json) of a previous run. Differences are shown in the HTML/PDF,
    on the diagram (NEW / REMOVED / CHANGED) and written to changes.csv.

.PARAMETER NoOpen
    Do not open topology.html (or the monitor page) in the browser.

.PARAMETER NoPdf
    Do not create topology.pdf.

.PARAMETER PaperSize
    PDF paper size: A4 (default), A3 or A2 (landscape).

.PARAMETER PdfPerServer
    Add one diagram page per server (HTML and PDF).

.PARAMETER BrowserPath
    Path to msedge.exe / chrome.exe used for the PDF (default: found automatically).

.PARAMETER Direction
    Diagram layout: LR (horizontal, default) or TB (vertical).

.PARAMETER MaxServers
    Maximum number of servers to visit (default 200).

.PARAMETER ConnectTimeout
    Connection timeout in seconds (default 10).

.PARAMETER QueryTimeout
    Query timeout in seconds (default 120).

.PARAMETER ThrottleLimit
    How many servers are queried at the same time (default 8; 1 = one by one).

.PARAMETER MermaidJs
    Path to mermaid.min.js embedded in the HTML (default: next to the script).

.PARAMETER Monitor
    After the discovery start the live replication monitor in the browser (see "Live monitor").
    No report files are written; row counts and the PDF are skipped.

.PARAMETER Port
    TCP port of the monitor page (default 8642; the next free port is used when it is taken).

.PARAMETER ListenAddress
    Address the monitor listens on: 127.0.0.1 (default, this computer only), or e.g. 0.0.0.0 to
    open it from other computers (the URL contains an access key; the traffic is plain HTTP).

.PARAMETER RefreshSeconds
    How often the monitor queries each server (default 10; can be changed on the page).

.PARAMETER PendingEvery
    The monitor counts pending commands every N-th refresh (default 3) - counting can be heavy on
    a large distribution database. "Refresh now" on the page counts them at once.

.PARAMETER AllowTracerTokens
    Enable the "Post tracer token" button (sp_posttracertoken at the publisher).

.PARAMETER AllowRepair
    Monitors: run the safe repairs (start / enable agent jobs, Snapshot Agent, clean up job) after
    a confirmation. Every run is written to repairs.log in -OutputDir.

.PARAMETER AllowAllRepair
    Monitors: run also the repairs that change data or settings (skip a transaction, reinitialize,
    sp_replrestart, sp_repldone, redirect), each after typing its confirmation word. Repairs that
    need a password stay scripts. Implies -AllowRepair.

.PARAMETER FilteredRowCounts
    Row counts: count the publisher rows of row-filtered articles with the article's own WHERE (a
    COUNT on the publisher table - can take time on big tables), so they are compared too.

.PARAMETER NoMask
    Write the reports for an AI assistant without masking the names and data values.

.PARAMETER Console
    The live monitor drawn in this console window instead of the browser (implies -Monitor).
    Needs a console window of at least 70 x 16 characters.

.EXAMPLE
    .\Get-ReplTopology.ps1 -Servers SQLPUB1, SQLPUB2

.EXAMPLE
    .\Get-ReplTopology.ps1 -Servers .\servers.txt -TestOnly
    Only checks the connections to every server in the file.

.EXAMPLE
    .\Get-ReplTopology.ps1 -Servers .\servers.txt -SqlUser sa
    Asks for the password of 'sa' and uses SQL authentication for every server.

.EXAMPLE
    .\Get-ReplTopology.ps1 -Servers SQLDIST1 -OutputDir C:\Repl\2026-11-06 -CompareTo C:\Repl\2026-11-05 -PaperSize A3 -PdfPerServer

.EXAMPLE
    .\Get-ReplTopology.ps1 -Servers .\servers.txt -Monitor
    Live replication monitor in the browser (http://localhost:8642/?t=<access key>).

.EXAMPLE
    .\Get-ReplTopology.ps1 -Servers SQLDIST1 -Monitor -SqlUser sa -RefreshSeconds 5 -AllowTracerTokens

.EXAMPLE
    .\Get-ReplTopology.ps1 -Servers .\servers.txt -Console
    Live replication monitor in this console window.

.EXAMPLE
    .\Get-ReplTopology.ps1 -Scan
    Find the instances around you, pick them from a list, then run the report.

.EXAMPLE
    .\Get-ReplTopology.ps1 -Servers .\servers.txt -Monitor -AllowRepair
    Live monitor that may run the safe repairs after a confirmation.
#>
[CmdletBinding()]
param(
    [string[]]$Servers = @(),
    [switch]$Scan,
    [string[]]$ScanHost,
    [string]$OutputDir = (Join-Path (Get-Location).Path 'ReplTopology'),
    [System.Management.Automation.PSCredential]$SqlCredential,
    [string]$SqlUser,
    [ValidateSet('Default', 'ActiveDirectoryIntegrated', 'ActiveDirectoryInteractive', 'ActiveDirectoryPassword',
                 'ActiveDirectoryDefault', 'ActiveDirectoryManagedIdentity')][string]$Authentication = 'Default',
    [ValidateSet('Optional', 'Mandatory', 'Strict')][string]$Encrypt = 'Optional',
    [switch]$StrictCert,
    [ValidateSet('Auto', 'System', 'Microsoft')][string]$SqlClient = 'Auto',
    [switch]$TestOnly,
    [switch]$NoCrawl,
    [switch]$KeepDomain,
    [hashtable]$Alias = @{},
    [switch]$HideDistributors,
    [switch]$ExpandEdges,
    [switch]$NoHealth,
    [switch]$NoPendingCommands,
    [switch]$NoRowCounts,
    [switch]$FilteredRowCounts,
    [int]$PendingWarn = 10000,
    [ValidateRange(1, 720)][int]$HistoryHours = 24,
    [ValidateRange(1, 100)][int]$LogUsedWarn = 70,
    [string]$CompareTo,
    [switch]$NoOpen,
    [switch]$NoPdf,
    [ValidateSet('A4', 'A3', 'A2')][string]$PaperSize = 'A4',
    [switch]$PdfPerServer,
    [string]$BrowserPath,
    [ValidateSet('LR', 'TB')][string]$Direction = 'LR',
    [int]$MaxServers = 200,
    [int]$ConnectTimeout = 10,
    [int]$QueryTimeout = 120,
    [ValidateRange(1, 64)][int]$ThrottleLimit = 8,
    [string]$MermaidJs = (Join-Path $PSScriptRoot 'mermaid.min.js'),
    [switch]$Monitor,
    [ValidateRange(1, 65535)][int]$Port = 8642,
    [string]$ListenAddress = '127.0.0.1',
    [ValidateRange(2, 3600)][int]$RefreshSeconds = 10,
    [ValidateRange(1, 1000)][int]$PendingEvery = 3,
    [switch]$AllowTracerTokens,
    [switch]$AllowRepair,
    [switch]$AllowAllRepair,
    [switch]$NoMask,
    [switch]$Console
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$scriptVersion = '1.9'
$levelRank = @{ '' = 0; ok = 1; unknown = 2; warn = 3; error = 4; removed = -1 }
if ($Console) { $Monitor = $true }   # -Console = the live monitor drawn in this console window
if ($Monitor) {
    # Live monitor: no report files and no row counts; pending commands are counted by the monitor itself
    $NoPdf = $true; $NoRowCounts = $true; $NoPendingCommands = $true; $NoHealth = $false; $CompareTo = ''
}

# ---------------------------------------------------------------------------
# Login and SQL client
# ---------------------------------------------------------------------------
if ($SqlUser -and -not $SqlCredential) {
    $SqlCredential = Get-Credential -UserName $SqlUser -Message "Password for SQL login '$SqlUser'"
    if (-not $SqlCredential) { throw 'No password given for -SqlUser.' }
}
if ($Authentication -ne 'Default') { $authText = "Entra ID ($Authentication)" }
elseif ($SqlCredential) { $authText = "SQL login '$($SqlCredential.UserName)'" }
else { $authText = "Windows login $([Environment]::UserDomainName)\$([Environment]::UserName)" }

$needMds = ($Encrypt -eq 'Strict') -or ($Authentication -ne 'Default')
$sqlNs = 'System.Data.SqlClient'
if ($SqlClient -eq 'Microsoft' -or ($SqlClient -eq 'Auto' -and $needMds)) {
    if (-not ('Microsoft.Data.SqlClient.SqlConnection' -as [type])) {
        $mod = Get-Module -ListAvailable -Name SqlServer | Sort-Object Version -Descending | Select-Object -First 1
        if ($mod) { Import-Module $mod -WarningAction SilentlyContinue }
    }
    if (-not ('Microsoft.Data.SqlClient.SqlConnection' -as [type])) {
        throw 'Microsoft.Data.SqlClient is needed (-Encrypt Strict, -Authentication or -SqlClient Microsoft) but was not found. Install it with: Install-Module SqlServer -Scope CurrentUser (version 22 or newer).'
    }
    $sqlNs = 'Microsoft.Data.SqlClient'
} elseif ($needMds) {
    throw "-SqlClient System does not support -Encrypt Strict or -Authentication $Authentication."
}

# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------
$srvSql = @'
DECLARE @srv nvarchar(400) =
  CASE WHEN OBJECT_ID(N'dbo.MSreplservers') IS NOT NULL
       THEN N'SELECT srvid AS id, srvname AS name FROM dbo.MSreplservers'
       ELSE N'SELECT server_id AS id, name FROM sys.servers' END;
'@

# Publications and subscriptions. Merge status is NULL: MSmerge_subscriptions.status
# is not used by SQL Server (health comes from sp_replmonitorhelpsubscription).
$edgeQuery = @'
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
'@ + $srvSql + @'
DECLARE @p2p nvarchar(200) =
  CASE WHEN COL_LENGTH(N'dbo.MSpublications', N'options') IS NOT NULL
       THEN N'CAST(p.options & 1 AS int)' ELSE N'0' END;
DECLARE @p2pAgg nvarchar(200) =
  CASE WHEN COL_LENGTH(N'dbo.MSpublications', N'options') IS NOT NULL
       THEN N'MAX(CAST(p.options & 1 AS int))' ELSE N'0' END;

DECLARE @hasMerge bit = CASE WHEN OBJECT_ID(N'dbo.MSmerge_subscriptions') IS NOT NULL THEN 1 ELSE 0 END;

DECLARE @merge nvarchar(max) = N'';
DECLARE @mergeNotExists nvarchar(max) = N'';
IF @hasMerge = 1
BEGIN
  SET @merge = N'
  UNION ALL
  SELECT p.publisher_id, p.publisher_db, p.publication, p.publication_type, ' + @p2pAgg + N',
         ms.subscriber_id, ms.subscriber_db, ms.subscription_type, NULL
  FROM dbo.MSpublications p
  JOIN dbo.MSmerge_subscriptions ms ON ms.publication_id = p.publication_id
  WHERE ms.subscriber_id >= 0
  GROUP BY p.publisher_id, p.publisher_db, p.publication, p.publication_type,
           ms.subscriber_id, ms.subscriber_db, ms.subscription_type';
  SET @mergeNotExists = N'
    AND NOT EXISTS (SELECT 1 FROM dbo.MSmerge_subscriptions ms
                    WHERE ms.publication_id = p.publication_id AND ms.subscriber_id >= 0)';
END;

DECLARE @sql nvarchar(max) = N'
WITH srv AS (' + @srv + N'),
e (publisher_id, publisher_db, publication, publication_type, is_p2p,
   subscriber_id, subscriber_db, subscription_type, status) AS (
  SELECT p.publisher_id, p.publisher_db, p.publication, p.publication_type, ' + @p2pAgg + N',
         s.subscriber_id, s.subscriber_db, s.subscription_type, MAX(s.status)
  FROM dbo.MSpublications p
  JOIN dbo.MSsubscriptions s ON s.publication_id = p.publication_id
  WHERE s.subscriber_id >= 0 AND s.subscriber_db <> N''virtual''
  GROUP BY p.publisher_id, p.publisher_db, p.publication, p.publication_type,
           s.subscriber_id, s.subscriber_db, s.subscription_type'
  + @merge + N'
  UNION ALL
  SELECT p.publisher_id, p.publisher_db, p.publication, p.publication_type, ' + @p2p + N',
         NULL, NULL, NULL, NULL
  FROM dbo.MSpublications p
  WHERE NOT EXISTS (SELECT 1 FROM dbo.MSsubscriptions s
                    WHERE s.publication_id = p.publication_id
                      AND s.subscriber_id >= 0 AND s.subscriber_db <> N''virtual'')'
  + @mergeNotExists + N'
)
SELECT DB_NAME() AS distribution_db,
       ISNULL(ps.name, N''publisher_id='' + CAST(e.publisher_id AS nvarchar(10))) AS pub_server,
       e.publisher_db AS pub_db,
       e.publication,
       e.publication_type,
       CASE WHEN e.is_p2p = 1 THEN N''P2P''
            WHEN e.publication_type = 0 THEN N''Transactional''
            WHEN e.publication_type = 1 THEN N''Snapshot''
            WHEN e.publication_type = 2 THEN N''Merge''
            ELSE N''Other'' END AS pub_type,
       CASE WHEN e.subscriber_id IS NULL THEN NULL
            ELSE ISNULL(ss.name, N''subscriber_id='' + CAST(e.subscriber_id AS nvarchar(10))) END AS sub_server,
       e.subscriber_db AS sub_db,
       CASE e.subscription_type WHEN 0 THEN N''Push'' WHEN 1 THEN N''Pull''
                                WHEN 2 THEN N''Anonymous'' END AS sub_type,
       e.status
FROM e
LEFT JOIN srv ps ON ps.id = e.publisher_id
LEFT JOIN srv ss ON ss.id = e.subscriber_id;';

EXEC sys.sp_executesql @sql;
'@

# Articles (transactional and snapshot; merge articles live only in the publication database)
$articleQuery = @'
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
'@ + $srvSql + @'
DECLARE @dest nvarchar(200) =
  CASE WHEN COL_LENGTH(N'dbo.MSarticles', N'destination_owner') IS NOT NULL
       THEN N'ISNULL(a.destination_owner + N''.'', N'''') + ' ELSE N'' END;
DECLARE @sql nvarchar(max) = N'
WITH srv AS (' + @srv + N')
SELECT ISNULL(ps.name, N''publisher_id='' + CAST(a.publisher_id AS nvarchar(10))) AS pub_server,
       a.publisher_db AS pub_db, p.publication, a.article,
       ISNULL(a.source_owner + N''.'', N'''') + a.source_object AS source_object,
       ' + @dest + N'a.destination_object AS destination_object
FROM dbo.MSarticles a
JOIN dbo.MSpublications p ON p.publication_id = a.publication_id
LEFT JOIN srv ps ON ps.id = a.publisher_id;';
EXEC sys.sp_executesql @sql;
'@

# Distribution (D), Log Reader (L), Snapshot (S) and merge (M) agents: job, profile, login,
# last message with errors, failures and retries in the last @h hours
$agentQuery = @'
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
'@ + $srvSql + @'
DECLARE @err nvarchar(max) = N'
OUTER APPLY (SELECT STUFF((SELECT N'' | '' + r.error_text FROM dbo.MSrepl_errors r
                           WHERE h.error_id <> 0 AND r.id = h.error_id ORDER BY r.[time]
                           FOR XML PATH(N''''), TYPE).value(N''.'', N''nvarchar(max)''), 1, 3, N'''') AS error_text) er';
DECLARE @sql nvarchar(max) = N'
WITH srv AS (' + @srv + N')
SELECT N''D'' AS kind, a.id AS agent_id, a.name, CONVERT(nvarchar(36), CONVERT(uniqueidentifier, a.job_id)) AS job_id,
       a.profile_id, a.subscription_type, CAST(a.subscriber_security_mode AS int) AS security_mode, a.subscriber_login AS login_name,
       ISNULL(ps.name, N'''') AS publisher, a.publisher_db, a.publication, ISNULL(ss.name, N'''') AS subscriber, a.subscriber_db,
       h.runstatus, h.[time], h.comments, er.error_text, st.fails, st.retries, st.max_latency
FROM dbo.MSdistribution_agents a
LEFT JOIN srv ps ON ps.id = a.publisher_id
LEFT JOIN srv ss ON ss.id = a.subscriber_id
OUTER APPLY (SELECT TOP (1) x.runstatus, x.[time], x.comments, x.error_id
             FROM dbo.MSdistribution_history x WHERE x.agent_id = a.id ORDER BY x.[timestamp] DESC) h' + @err + N'
OUTER APPLY (SELECT SUM(CASE WHEN x.runstatus = 6 THEN 1 ELSE 0 END) AS fails,
                    SUM(CASE WHEN x.runstatus = 5 THEN 1 ELSE 0 END) AS retries,
                    MAX(x.delivery_latency) AS max_latency
             FROM dbo.MSdistribution_history x
             WHERE x.agent_id = a.id AND x.[time] >= DATEADD(hour, -@hours, GETDATE())) st
UNION ALL
SELECT N''L'', a.id, a.name, CONVERT(nvarchar(36), CONVERT(uniqueidentifier, a.job_id)),
       a.profile_id, NULL, CAST(a.publisher_security_mode AS int), a.publisher_login,
       ISNULL(ps.name, N''''), a.publisher_db, a.publication, NULL, NULL,
       h.runstatus, h.[time], h.comments, er.error_text, st.fails, st.retries, st.max_latency
FROM dbo.MSlogreader_agents a
LEFT JOIN srv ps ON ps.id = a.publisher_id
OUTER APPLY (SELECT TOP (1) x.runstatus, x.[time], x.comments, x.error_id
             FROM dbo.MSlogreader_history x WHERE x.agent_id = a.id ORDER BY x.[timestamp] DESC) h' + @err + N'
OUTER APPLY (SELECT SUM(CASE WHEN x.runstatus = 6 THEN 1 ELSE 0 END) AS fails,
                    SUM(CASE WHEN x.runstatus = 5 THEN 1 ELSE 0 END) AS retries,
                    MAX(x.delivery_latency) AS max_latency
             FROM dbo.MSlogreader_history x
             WHERE x.agent_id = a.id AND x.[time] >= DATEADD(hour, -@hours, GETDATE())) st
UNION ALL
SELECT N''S'', a.id, a.name, CONVERT(nvarchar(36), CONVERT(uniqueidentifier, a.job_id)),
       a.profile_id, NULL, CAST(a.publisher_security_mode AS int), a.publisher_login,
       ISNULL(ps.name, N''''), a.publisher_db, a.publication, NULL, NULL,
       h.runstatus, h.[time], h.comments, er.error_text, NULL, NULL, NULL
FROM dbo.MSsnapshot_agents a
LEFT JOIN srv ps ON ps.id = a.publisher_id
OUTER APPLY (SELECT TOP (1) x.runstatus, x.[time], x.comments, x.error_id
             FROM dbo.MSsnapshot_history x WHERE x.agent_id = a.id ORDER BY x.[timestamp] DESC) h' + @err;
IF OBJECT_ID(N'dbo.MSmerge_agents') IS NOT NULL AND OBJECT_ID(N'dbo.MSmerge_history') IS NOT NULL
  SET @sql = @sql + N'
UNION ALL
SELECT N''M'', a.id, a.name, NULL, NULL, NULL, NULL, NULL, N'''', a.publisher_db, a.publication, N'''', NULL,
       NULL, h.[time], h.comments, er.error_text, NULL, NULL, NULL
FROM dbo.MSmerge_agents a
OUTER APPLY (SELECT TOP (1) x.[time], x.comments, x.error_id
             FROM dbo.MSmerge_history x WHERE x.agent_id = a.id ORDER BY x.[timestamp] DESC) h' + @err;
EXEC sys.sp_executesql @sql, N'@hours int', @hours = @h;
'@

# Pending commands: the "Undistributed commands" number of Replication Monitor
# (pooled connections keep the isolation level of earlier queries; this procedure needs READ COMMITTED)
$pendingQuery = @'
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
EXEC sp_replmonitorsubscriptionpendingcmds @publisher = @p, @publisher_db = @pd, @publication = @pub,
     @subscriber = @s, @subscriber_db = @sd, @subscription_type = @t;
'@

$redirectQuery = @'
SET NOCOUNT ON;
IF OBJECT_ID(N'dbo.MSredirected_publishers') IS NOT NULL
  SELECT original_publisher, publisher_db, redirected_publisher FROM dbo.MSredirected_publishers;
ELSE
  SELECT CAST(NULL AS sysname) AS original_publisher, CAST(NULL AS sysname) AS publisher_db,
         CAST(NULL AS sysname) AS redirected_publisher WHERE 1 = 0;
'@

$pubQuery = @'
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
'@ + $srvSql + @'
DECLARE @sql nvarchar(max) = N'
WITH srv AS (' + @srv + N')
SELECT ISNULL(ps.name, N''publisher_id='' + CAST(p.publisher_id AS nvarchar(10))) AS pub_server,
       p.publisher_db AS pub_db, p.publication, p.publication_type, CAST(p.immediate_sync AS int) AS immediate_sync,
       CAST(p.allow_anonymous AS int) AS allow_anonymous, CAST(p.independent_agent AS int) AS independent_agent, p.retention
FROM dbo.MSpublications p
LEFT JOIN srv ps ON ps.id = p.publisher_id;';
EXEC sys.sp_executesql @sql;
'@

$distHealthQuery = @'
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT
  (SELECT SUM(CAST(size AS bigint)) * 8 / 1024 FROM sys.database_files WHERE type = 0) AS data_mb,
  (SELECT SUM(CAST(size AS bigint)) * 8 / 1024 FROM sys.database_files WHERE type = 1) AS log_mb,
  (SELECT SUM(p.rows) FROM sys.partitions p WHERE p.object_id = OBJECT_ID(N'dbo.MSrepl_commands') AND p.index_id IN (0, 1)) AS commands,
  (SELECT SUM(p.rows) FROM sys.partitions p WHERE p.object_id = OBJECT_ID(N'dbo.MSrepl_transactions') AND p.index_id IN (0, 1)) AS transactions,
  (SELECT MIN(x.entry_time) FROM dbo.MSpublisher_databases d
     CROSS APPLY (SELECT TOP (1) t.entry_time FROM dbo.MSrepl_transactions t
                  WHERE t.publisher_database_id = d.id ORDER BY t.xact_seqno) x) AS oldest_entry,
  (SELECT COUNT(*) FROM sys.symmetric_keys WHERE name = N'##MS_DatabaseMasterKey##') AS has_dmk;
'@

$basicQuery = @'
SET NOCOUNT ON;
SELECT @@SERVERNAME AS srv,
       CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(50)) AS ver,
       CAST(SERVERPROPERTY('Edition') AS nvarchar(128)) AS ed,
       SUSER_SNAME() AS login_name,
       IS_SRVROLEMEMBER('sysadmin') AS is_sysadmin,
       HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') AS view_server_state,
       CAST(ISNULL(SERVERPROPERTY('IsHadrEnabled'), 0) AS int) AS hadr,
       CAST(CONNECTIONPROPERTY('net_transport') AS nvarchar(40)) AS net_transport,
       CAST(CONNECTIONPROPERTY('local_tcp_port') AS int) AS local_tcp_port;
'@

$agColumns = @'
SELECT ag.name AS ag_name, ar.replica_server_name, ar.read_only_routing_url, {ROLE} AS role_desc,
       l.dns_name, l.port
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ar.group_id = ag.group_id
{DMV}
LEFT JOIN sys.availability_group_listeners l ON l.group_id = ag.group_id;
'@

$q = @{
    Basic      = $basicQuery
    Listeners  = 'SELECT l.dns_name, l.port, ag.name AS ag_name FROM sys.availability_group_listeners l JOIN sys.availability_groups ag ON ag.group_id = l.group_id;'
    Ag         = $agColumns.Replace('{ROLE}', 'rs.role_desc').Replace('{DMV}', 'LEFT JOIN sys.dm_hadr_availability_replica_states rs ON rs.replica_id = ar.replica_id')
    AgNoDmv    = $agColumns.Replace('{ROLE}', 'CAST(NULL AS nvarchar(60))').Replace('{DMV}', '')
    AgDbs      = 'SELECT ag.name AS ag_name, adc.database_name FROM sys.availability_groups ag JOIN sys.availability_databases_cluster adc ON adc.group_id = ag.group_id;'
    Dbs        = 'SELECT name, state_desc, CAST(is_published AS int) AS is_published, CAST(is_merge_published AS int) AS is_merge_published, CAST(is_distributor AS int) AS is_distributor, log_reuse_wait_desc FROM sys.databases;'
    Perf       = "SELECT RTRIM(instance_name) AS db, RTRIM(counter_name) AS counter_name, cntr_value FROM sys.dm_os_performance_counters WHERE object_name LIKE N'%:Databases%' AND counter_name IN (N'Percent Log Used', N'Log File(s) Size (KB)');"
    AgentSvc   = @'
SET NOCOUNT ON;
DECLARE @s nvarchar(60) = NULL;
BEGIN TRY
  SELECT TOP (1) @s = status_desc FROM sys.dm_server_services WHERE servicename LIKE N'SQL Server Agent%';
END TRY BEGIN CATCH END CATCH;
IF @s IS NULL
  SELECT @s = CASE WHEN EXISTS (SELECT 1 FROM sys.dm_exec_sessions WHERE program_name LIKE N'SQLAgent - %')
                   THEN N'Running' ELSE N'Stopped' END;
SELECT @s AS agent_status;
'@
    Jobs       = @'
SET NOCOUNT ON;
DECLARE @session int = (SELECT MAX(session_id) FROM msdb.dbo.syssessions);
SELECT CONVERT(nvarchar(36), j.job_id) AS job_id, j.name, CAST(j.enabled AS int) AS enabled, c.name AS category,
       SUSER_SNAME(j.owner_sid) AS owner_name, st.command, st.subsystem, st.proxy_id,
       CASE WHEN a.start_execution_date IS NOT NULL AND a.stop_execution_date IS NULL THEN 1 ELSE 0 END AS running,
       h.run_status AS last_run_status,
       CASE WHEN h.run_date > 0 THEN msdb.dbo.agent_datetime(h.run_date, h.run_time) END AS last_run,
       h.message AS last_message
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.syscategories c ON c.category_id = j.category_id
OUTER APPLY (SELECT TOP (1) s.command, s.subsystem, s.proxy_id FROM msdb.dbo.sysjobsteps s
             WHERE s.job_id = j.job_id
             ORDER BY CASE WHEN s.subsystem IN (N'Distribution', N'LogReader', N'Snapshot', N'Merge', N'QueueReader') THEN 0 ELSE 1 END, s.step_id) st
LEFT JOIN msdb.dbo.sysjobactivity a ON a.job_id = j.job_id AND a.session_id = @session
OUTER APPLY (SELECT TOP (1) jh.run_status, jh.run_date, jh.run_time, jh.message FROM msdb.dbo.sysjobhistory jh
             WHERE jh.job_id = j.job_id AND jh.step_id = 0 ORDER BY jh.instance_id DESC) h
WHERE c.name LIKE N'REPL-%';
'@
    Profiles   = @'
IF OBJECT_ID(N'msdb.dbo.MSagent_profiles') IS NOT NULL AND OBJECT_ID(N'msdb.dbo.MSagent_parameters') IS NOT NULL
SELECT p.profile_id, p.profile_name, prm.parameter_name, prm.value
FROM msdb.dbo.MSagent_profiles p
JOIN msdb.dbo.MSagent_parameters prm ON prm.profile_id = p.profile_id
WHERE prm.parameter_name LIKE N'%SkipErrors%' OR prm.parameter_name LIKE N'%EncryptionLevel%';
ELSE
SELECT CAST(NULL AS int) AS profile_id, CAST(NULL AS sysname) AS profile_name, CAST(NULL AS sysname) AS parameter_name, CAST(NULL AS nvarchar(255)) AS value WHERE 1 = 0;
'@
    DistPubs   = 'SELECT name, distribution_db, working_directory, security_mode FROM msdb.dbo.MSdistpublishers;'
    Retention  = @'
IF OBJECT_ID(N'msdb.dbo.MSdistributiondbs') IS NOT NULL
  SELECT name, min_distretention, max_distretention, history_retention FROM msdb.dbo.MSdistributiondbs;
ELSE
  SELECT CAST(NULL AS sysname) AS name, 0 AS min_distretention, 0 AS max_distretention, 0 AS history_retention WHERE 1 = 0;
'@
    Edges      = $edgeQuery
    Articles   = $articleQuery
    Agents     = $agentQuery
    Pending    = $pendingQuery
    Redirect   = $redirectQuery
    Pubs       = $pubQuery
    DistHealth = $distHealthQuery
    Perm       = "SELECT IS_SRVROLEMEMBER('sysadmin') AS sa, IS_MEMBER('db_owner') AS dbo;"
    RowCounts  = @'
SET NOCOUNT ON;
SELECT s.name AS sch, t.name AS tbl, SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY s.name, t.name;
'@
    PubDb      = @'
SET NOCOUNT ON;
IF OBJECT_ID(N'dbo.syspublications') IS NOT NULL
  SELECT p.name AS publication, CAST(p.replicate_ddl AS int) AS replicate_ddl, a.name AS article,
         CAST(a.filter_clause AS nvarchar(max)) AS filter_clause,
         OBJECT_SCHEMA_NAME(a.objid) AS src_schema, OBJECT_NAME(a.objid) AS src_table,
         (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = a.objid) AS cols,
         (SELECT COUNT(*) FROM dbo.sysarticlecolumns ac WHERE ac.artid = a.artid) AS pub_cols,
         STUFF((SELECT N', ' + c.name FROM sys.columns c
                WHERE c.object_id = a.objid AND NOT EXISTS (SELECT 1 FROM dbo.sysarticlecolumns ac WHERE ac.artid = a.artid AND ac.colid = c.column_id)
                ORDER BY c.column_id FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, '') AS excluded_cols
  FROM dbo.syspublications p LEFT JOIN dbo.sysarticles a ON a.pubid = p.pubid;
ELSE
  SELECT CAST(NULL AS sysname) AS publication, 0 AS replicate_ddl, CAST(NULL AS sysname) AS article,
         CAST(NULL AS nvarchar(max)) AS filter_clause, CAST(NULL AS sysname) AS src_schema, CAST(NULL AS sysname) AS src_table,
         0 AS cols, 0 AS pub_cols, CAST(NULL AS nvarchar(max)) AS excluded_cols WHERE 1 = 0;
'@
}

# --- Monitor (-Monitor) queries ---
# Latest agent state (Distribution and Log Reader), new errors since @last and the agents they belong to.
# MSrepl_errors: one id = one error event, several rows; the details often follow under the next id.
$q.LiveDist = @'
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT GETDATE() AS now, (SELECT MAX(id) FROM dbo.MSrepl_errors) AS max_err;
SELECT N'D' AS kind, a.id AS agent_id, a.publisher_id, a.publisher_db, h.runstatus, h.start_time, h.[time], h.comments,
       h.delivered_transactions, h.delivered_commands, h.delivery_rate, h.delivery_latency,
       h.current_delivery_rate, h.current_delivery_latency, h.total_delivered_commands, h.error_id
FROM dbo.MSdistribution_agents a
OUTER APPLY (SELECT TOP (1) x.runstatus, x.start_time, x.[time], x.comments, x.delivered_transactions, x.delivered_commands,
                    x.delivery_rate, x.delivery_latency, x.current_delivery_rate, x.current_delivery_latency, x.total_delivered_commands, x.error_id
             FROM dbo.MSdistribution_history x WHERE x.agent_id = a.id ORDER BY x.[timestamp] DESC) h
WHERE ISNULL(a.subscriber_db, N'') <> N'virtual'
UNION ALL
SELECT N'L', a.id, a.publisher_id, a.publisher_db, h.runstatus, h.start_time, h.[time], h.comments,
       h.delivered_transactions, h.delivered_commands, h.delivery_rate, h.delivery_latency, NULL, NULL, NULL, h.error_id
FROM dbo.MSlogreader_agents a
OUTER APPLY (SELECT TOP (1) x.runstatus, x.start_time, x.[time], x.comments, x.delivered_transactions, x.delivered_commands,
                    x.delivery_rate, x.delivery_latency, x.error_id
             FROM dbo.MSlogreader_history x WHERE x.agent_id = a.id ORDER BY x.[timestamp] DESC) h;
DECLARE @e TABLE (id int PRIMARY KEY);
IF @last < 0
BEGIN
  INSERT @e SELECT DISTINCT TOP (50) id FROM dbo.MSrepl_errors WHERE [time] >= DATEADD(hour, -@hours, GETDATE()) ORDER BY id DESC;
  -- the oldest id may hold the details of an error just outside the window: take that error too
  INSERT @e SELECT DISTINCT p.id FROM dbo.MSrepl_errors p JOIN dbo.MSrepl_errors c ON c.id = p.id + 1
  WHERE c.id = (SELECT MIN(id) FROM @e) AND c.[time] <= DATEADD(second, 2, p.[time]);
END
ELSE
  INSERT @e SELECT DISTINCT TOP (100) id FROM dbo.MSrepl_errors WHERE id > @last ORDER BY id;
SELECT r.id, r.[time], r.error_code, r.error_text, r.source_name, CONVERT(varchar(42), r.xact_seqno, 1) AS xact_seqno, r.command_id
FROM dbo.MSrepl_errors r JOIN @e e ON e.id = r.id ORDER BY r.id, r.[time];
IF EXISTS (SELECT 1 FROM @e)
  SELECT N'D' AS kind, h.agent_id, h.error_id FROM dbo.MSdistribution_history h WHERE h.error_id IN (SELECT id FROM @e)
  UNION ALL SELECT N'L', h.agent_id, h.error_id FROM dbo.MSlogreader_history h WHERE h.error_id IN (SELECT id FROM @e)
  UNION ALL SELECT N'S', h.agent_id, h.error_id FROM dbo.MSsnapshot_history h WHERE h.error_id IN (SELECT id FROM @e);
ELSE
  SELECT N'' AS kind, 0 AS agent_id, 0 AS error_id WHERE 1 = 0;
'@

# Undistributed commands of all Distribution Agents in one pass - the same rules as
# sp_replmonitorsubscriptionpendingcmds / sp_MSget_repl_commands (READPAST needs READ COMMITTED).
# ponytail: no loopback detection (bidirectional transactional only) and P2P agents are skipped.
$pendingCore = @'
  AND (((rc.type & @snap) <> @snap AND rc.xact_seqno > s.publisher_seqno AND rc.xact_seqno > s.ss_cplt_seqno)
       OR ((rc.type & @snap) = @snap AND rc.xact_seqno >= s.subscription_seqno AND rc.xact_seqno <= s.ss_cplt_seqno
           AND (s.update_mode <> 0 OR rc.type <> (@snap | 9))))
  AND (rc.type & ~@snap & ~@post) <> 105
'@
$q.LivePending = @'
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
DECLARE @snap int = 0x80000000, @post int = 0x40000000;
DECLARE @a TABLE (id int PRIMARY KEY, pdb int, seq varbinary(16), rate float, skip bit);
INSERT @a (id, pdb, seq, rate, skip)
SELECT a.id, a.publisher_database_id, ISNULL(ISNULL(h.xact_seqno, h2.xact_seqno), 0x00), ISNULL(h.delivery_rate, 0),
       CASE WHEN h.xact_seqno IS NULL AND EXISTS (SELECT 1 FROM dbo.MSpublications p WITH (NOLOCK)
                 JOIN dbo.MSsubscriptions s WITH (NOLOCK) ON s.publication_id = p.publication_id
                 WHERE p.publisher_id = a.publisher_id AND p.publisher_db = a.publisher_db AND p.publication = a.publication
                   AND p.immediate_sync = 1 AND s.status = 1 AND s.subscriber_id = -1) THEN 1 ELSE 0 END
FROM dbo.MSdistribution_agents a WITH (NOLOCK)
OUTER APPLY (SELECT TOP (1) x.xact_seqno, x.delivery_rate FROM dbo.MSdistribution_history x WITH (NOLOCK)
             WHERE x.agent_id = a.id AND x.runstatus IN (2, 3, 4) ORDER BY x.[timestamp] DESC) h
OUTER APPLY (SELECT TOP (1) x.xact_seqno FROM dbo.MSdistribution_history x WITH (NOLOCK)
             WHERE x.agent_id = a.id ORDER BY x.[timestamp] DESC) h2
WHERE ISNULL(a.subscriber_db, N'') <> N'virtual'
  AND NOT EXISTS (SELECT 1 FROM dbo.MSpublications p WITH (NOLOCK) WHERE p.publisher_id = a.publisher_id AND p.publisher_db = a.publisher_db
                  AND p.publication = a.publication AND (p.options & 1) = 1);
DECLARE @mx TABLE (pdb int PRIMARY KEY, mx varbinary(16));
INSERT @mx (pdb, mx)
SELECT d.pdb, m.xact_seqno FROM (SELECT DISTINCT pdb FROM @a) d
CROSS APPLY (SELECT TOP (1) c.xact_seqno FROM dbo.MSrepl_commands c WITH (READPAST)
             WHERE c.publisher_database_id = d.pdb AND c.command_id = 1 AND c.type <> -2147483611
             ORDER BY c.xact_seqno DESC) m;
WITH p AS (
  SELECT a.id, a.pdb, COUNT_BIG(rc.xact_seqno) AS pending, MIN(rc.xact_seqno) AS first_seq
  FROM @a a
  LEFT JOIN @mx m ON m.pdb = a.pdb
  LEFT JOIN (dbo.MSsubscriptions s WITH (NOLOCK)
             JOIN dbo.MSrepl_commands rc WITH (NOLOCK)
               ON rc.publisher_database_id = s.publisher_database_id AND rc.article_id = s.article_id)
    ON s.agent_id = a.id AND s.status = 2 AND a.skip = 0 AND rc.xact_seqno > a.seq AND rc.xact_seqno <= m.mx
{CORE}  GROUP BY a.id, a.pdb
)
SELECT p.id AS agent_id, p.pending, a.rate, t.entry_time AS oldest_entry, GETDATE() AS now
FROM p JOIN @a a ON a.id = p.id
LEFT JOIN dbo.MSrepl_transactions t WITH (NOLOCK) ON t.publisher_database_id = p.pdb AND t.xact_seqno = p.first_seq;
'@.Replace('{CORE}', $pendingCore)

# Replication agent sessions (names put in by the monitor), their blockers (up to 10 levels; a sleeping
# session with an open transaction has no request) and sessions blocked by an agent; waits per session
# (SQL 2016+) and per server.
$benignWaits = @'
N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR', N'BROKER_TASK_STOP', N'BROKER_TO_FLUSH', N'BROKER_TRANSMITTER',
N'CHECKPOINT_QUEUE', N'CHKPT', N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE', N'DBMIRROR_EVENTS_QUEUE', N'DBMIRRORING_CMD',
N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE', N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSHC_MUTEX', N'HADR_CLUSAPI_CALL',
N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', N'HADR_LOGCAPTURE_WAIT', N'HADR_NOTIFICATION_DEQUEUE', N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE',
N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP', N'LOGMGR_QUEUE', N'MEMORY_ALLOCATION_EXT', N'RESERVED_MEMORY_ALLOCATION_EXT', N'ONDEMAND_TASK_QUEUE',
N'PARALLEL_REDO_DRAIN_WORKER', N'PARALLEL_REDO_LOG_CACHE', N'PARALLEL_REDO_TRAN_LIST', N'PARALLEL_REDO_WORKER_SYNC',
N'PARALLEL_REDO_WORKER_WAIT_WORK', N'PREEMPTIVE_OS_FLUSHFILEBUFFERS', N'PVS_PREALLOCATE', N'PWAIT_ALL_COMPONENTS_INITIALIZED',
N'PWAIT_DIRECTLOGCONSUMER_GETNEXT', N'PWAIT_EXTENSIBILITY_CLEANUP_TASK', N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP', N'QDS_ASYNC_QUEUE',
N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP', N'QDS_SHUTDOWN_QUEUE', N'REDO_THREAD_PENDING_WORK', N'REQUEST_FOR_DEADLOCK_SEARCH',
N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK', N'SNI_HTTP_ACCEPT', N'SOS_WORK_DISPATCHER', N'SP_SERVER_DIAGNOSTICS_SLEEP',
N'SQLTRACE_BUFFER_FLUSH', N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', N'SQLTRACE_WAIT_ENTRIES', N'VDI_CLIENT_OTHER', N'WAIT_FOR_RESULTS',
N'WAITFOR', N'WAITFOR_TASKSHUTDOWN', N'WAIT_XTP_RECOVERY', N'WAIT_XTP_HOST_WAIT', N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', N'WAIT_XTP_CKPT_CLOSE',
N'XE_DISPATCHER_JOIN', N'XE_DISPATCHER_WAIT', N'XE_TIMER_EVENT', N'XE_LIVE_TARGET_TVF', N'HADR_SYNC_COMMIT_IDLE'
'@
$q.LiveSessions = @'
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
IF OBJECT_ID(N'tempdb..#rs') IS NOT NULL DROP TABLE #rs;
CREATE TABLE #rs (session_id int PRIMARY KEY, lvl int NOT NULL);
INSERT #rs (session_id, lvl)
SELECT s.session_id, 0 FROM sys.dm_exec_sessions s
WHERE s.is_user_process = 1 AND s.session_id <> @@SPID
  AND (s.program_name LIKE N'Repl-LogReader-%' OR s.program_name IN ({NAMES}){LIKES});
DECLARE @i int = 1;
WHILE @i <= 10
BEGIN
  INSERT #rs (session_id, lvl)
  SELECT DISTINCT r.blocking_session_id, @i FROM sys.dm_exec_requests r JOIN #rs t ON t.session_id = r.session_id
  WHERE r.blocking_session_id > 0 AND NOT EXISTS (SELECT 1 FROM #rs x WHERE x.session_id = r.blocking_session_id);
  IF @@ROWCOUNT = 0 BREAK;
  SET @i += 1;
END;
INSERT #rs (session_id, lvl)
SELECT DISTINCT r.session_id, -1 FROM sys.dm_exec_requests r JOIN #rs t ON t.session_id = r.blocking_session_id AND t.lvl = 0
WHERE NOT EXISTS (SELECT 1 FROM #rs x WHERE x.session_id = r.session_id);
SELECT t.session_id, t.lvl, s.program_name, s.host_name, s.login_name, DB_NAME(s.database_id) AS db, s.status,
       s.cpu_time, s.reads, s.writes, s.logical_reads, s.open_transaction_count, s.login_time, s.last_request_start_time,
       r.status AS req_status, r.command, r.wait_type, r.wait_time, r.wait_resource, r.blocking_session_id, r.total_elapsed_time,
       LEFT(CASE WHEN r.sql_handle IS NOT NULL AND r.statement_start_offset >= 0
                 THEN SUBSTRING(st.text, r.statement_start_offset / 2 + 1,
                      (CASE WHEN r.statement_end_offset > 0 THEN r.statement_end_offset ELSE DATALENGTH(st.text) END - r.statement_start_offset) / 2 + 1)
                 ELSE st.text END, 2000) AS sql_text,
       j.name AS job_name,
       CASE WHEN o.objid IS NOT NULL THEN DB_NAME(o.dbid) + N'.' + OBJECT_SCHEMA_NAME(o.objid, o.dbid) + N'.' + OBJECT_NAME(o.objid, o.dbid) END AS wait_object
FROM #rs t
JOIN sys.dm_exec_sessions s ON s.session_id = t.session_id
OUTER APPLY (SELECT TOP (1) rr.* FROM sys.dm_exec_requests rr WHERE rr.session_id = t.session_id ORDER BY rr.request_id) r
OUTER APPLY (SELECT TOP (1) c.most_recent_sql_handle FROM sys.dm_exec_connections c WHERE c.session_id = t.session_id) c
OUTER APPLY sys.dm_exec_sql_text(ISNULL(r.sql_handle, c.most_recent_sql_handle)) st
OUTER APPLY (SELECT TRY_CONVERT(int, PARSENAME(x.v, 3)) AS dbid, TRY_CONVERT(int, PARSENAME(x.v, 2)) AS objid
             FROM (SELECT REPLACE(LTRIM(SUBSTRING(r.wait_resource, 8, 200)), N':', N'.') AS v) x
             WHERE r.wait_resource LIKE N'OBJECT: %') o
OUTER APPLY (SELECT TOP (1) sj.name FROM msdb.dbo.sysjobs sj
             WHERE s.program_name LIKE N'SQLAgent - TSQL JobStep (Job 0x%'
               AND sj.job_id = TRY_CONVERT(uniqueidentifier, TRY_CONVERT(binary(16), SUBSTRING(s.program_name, 30, 34), 1))) j;
IF OBJECT_ID(N'sys.dm_exec_session_wait_stats') IS NOT NULL
  EXEC (N'SELECT ws.session_id, ws.wait_type, ws.waiting_tasks_count, ws.wait_time_ms
         FROM sys.dm_exec_session_wait_stats ws JOIN #rs t ON t.session_id = ws.session_id AND t.lvl = 0
         WHERE ws.wait_time_ms > 0 AND ws.wait_type NOT IN ({BENIGNQ})');
ELSE
  SELECT CAST(NULL AS int) AS session_id, CAST(NULL AS nvarchar(60)) AS wait_type, CAST(NULL AS bigint) AS waiting_tasks_count,
         CAST(NULL AS bigint) AS wait_time_ms WHERE 1 = 0;
SELECT wait_type, waiting_tasks_count, wait_time_ms
FROM sys.dm_os_wait_stats
WHERE wait_time_ms > 0 AND wait_type NOT IN ({BENIGN})
  AND wait_type NOT LIKE N'SLEEP[_]%' AND wait_type NOT LIKE N'PREEMPTIVE[_]XE[_]%' AND wait_type NOT LIKE N'BROKER[_]%';
'@.Replace('{BENIGNQ}', $benignWaits.Replace("'", "''")).Replace('{BENIGN}', $benignWaits)
$q.LiveJobs = @'
SET NOCOUNT ON;
DECLARE @session int = (SELECT MAX(session_id) FROM msdb.dbo.syssessions);
SELECT CONVERT(nvarchar(36), j.job_id) AS job_id, CAST(j.enabled AS int) AS enabled,
       CASE WHEN a.start_execution_date IS NOT NULL AND a.stop_execution_date IS NULL THEN 1 ELSE 0 END AS running
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.syscategories c ON c.category_id = j.category_id
LEFT JOIN msdb.dbo.sysjobactivity a ON a.job_id = j.job_id AND a.session_id = @session
WHERE c.name LIKE N'REPL-%';
'@
$q.LiveAg = @'
SET NOCOUNT ON;
SELECT ag.name AS ag_name, ar.replica_server_name AS replica, ar.availability_mode_desc AS mode, ars.role_desc AS role,
       ars.connected_state_desc AS connected, adc.database_name AS db, drs.synchronization_state_desc AS sync_state,
       drs.synchronization_health_desc AS db_health, CAST(drs.is_suspended AS int) AS suspended, drs.suspend_reason_desc AS suspend_reason,
       drs.log_send_queue_size AS send_queue_kb, drs.log_send_rate AS send_rate_kbs, drs.redo_queue_size AS redo_queue_kb,
       drs.redo_rate AS redo_rate_kbs, drs.last_commit_time,
       (SELECT TOP (1) l.role_desc FROM sys.dm_hadr_availability_replica_states l WHERE l.group_id = ag.group_id AND l.is_local = 1) AS my_role
FROM sys.dm_hadr_database_replica_states drs
JOIN sys.availability_replicas ar ON ar.replica_id = drs.replica_id
JOIN sys.availability_groups ag ON ag.group_id = drs.group_id
LEFT JOIN sys.dm_hadr_availability_replica_states ars ON ars.replica_id = drs.replica_id
LEFT JOIN sys.availability_databases_cluster adc ON adc.group_id = drs.group_id AND adc.group_database_id = drs.group_database_id;
'@

# Detail of one agent: history in the last @hours, its errors (the event plus the details under the next id),
# tracer tokens of the publication
$detailErrors = @'
DECLARE @e TABLE (id int PRIMARY KEY);
INSERT @e SELECT DISTINCT h.error_id FROM dbo.{HIST} h WHERE h.agent_id = @id AND h.error_id <> 0 AND h.[time] >= DATEADD(hour, -@hours, GETDATE());
INSERT @e SELECT DISTINCT r.id FROM dbo.MSrepl_errors r
WHERE r.[time] >= DATEADD(hour, -@hours, GETDATE()) AND @name <> N'' AND r.error_text LIKE N'%agent ' + @name + N' failed%'
  AND NOT EXISTS (SELECT 1 FROM @e x WHERE x.id = r.id);
SELECT TOP (400) g.gid, r.id, r.[time], r.error_code, r.error_text, CONVERT(varchar(42), r.xact_seqno, 1) AS xact_seqno, r.command_id
FROM (SELECT e.id AS gid, MIN(x.[time]) AS t0 FROM @e e JOIN dbo.MSrepl_errors x ON x.id = e.id GROUP BY e.id) g
JOIN dbo.MSrepl_errors r ON r.id = g.gid OR (r.id = g.gid + 1 AND r.[time] <= DATEADD(second, 2, g.t0) AND NOT EXISTS (SELECT 1 FROM @e y WHERE y.id = r.id))
ORDER BY g.gid DESC, r.id, r.[time];
'@
$q.DetailD = @'
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT GETDATE() AS now;
SELECT h.[time], h.start_time, h.runstatus, h.comments, h.current_delivery_latency AS latency_ms, h.total_delivered_commands AS cmds, h.error_id
FROM dbo.MSdistribution_history h WHERE h.agent_id = @id AND h.[time] >= DATEADD(hour, -@hours, GETDATE()) ORDER BY h.[timestamp];
'@ + $detailErrors.Replace('{HIST}', 'MSdistribution_history') + @'
SELECT TOP (15) t.tracer_id, t.publisher_commit, t.distributor_commit, h.subscriber_commit
FROM dbo.MSdistribution_agents a
JOIN dbo.MSpublications p ON p.publisher_id = a.publisher_id AND p.publisher_db = a.publisher_db AND p.publication = @pub
JOIN dbo.MStracer_tokens t ON t.publication_id = p.publication_id
LEFT JOIN dbo.MStracer_history h ON h.parent_tracer_id = t.tracer_id AND h.agent_id = a.id
WHERE a.id = @id ORDER BY t.tracer_id DESC;
'@
$q.DetailL = @'
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT GETDATE() AS now;
SELECT h.[time], h.start_time, h.runstatus, h.comments, h.delivery_latency AS latency_ms, h.delivered_commands AS cmds, h.error_id
FROM dbo.MSlogreader_history h WHERE h.agent_id = @id AND h.[time] >= DATEADD(hour, -@hours, GETDATE()) ORDER BY h.[timestamp];
'@ + $detailErrors.Replace('{HIST}', 'MSlogreader_history')

# Undistributed commands of one agent per article and the largest transactions
$q.DetailPending = @'
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
DECLARE @snap int = 0x80000000, @post int = 0x40000000, @seq varbinary(16), @pdb int, @mx varbinary(16);
SELECT @pdb = a.publisher_database_id FROM dbo.MSdistribution_agents a WITH (NOLOCK) WHERE a.id = @id;
SELECT TOP (1) @seq = x.xact_seqno FROM dbo.MSdistribution_history x WITH (NOLOCK) WHERE x.agent_id = @id AND x.runstatus IN (2, 3, 4) ORDER BY x.[timestamp] DESC;
IF @seq IS NULL SELECT TOP (1) @seq = x.xact_seqno FROM dbo.MSdistribution_history x WITH (NOLOCK) WHERE x.agent_id = @id ORDER BY x.[timestamp] DESC;
SET @seq = ISNULL(@seq, 0x00);
SELECT TOP (1) @mx = c.xact_seqno FROM dbo.MSrepl_commands c WITH (READPAST)
WHERE c.publisher_database_id = @pdb AND c.command_id = 1 AND c.type <> -2147483611 ORDER BY c.xact_seqno DESC;
DECLARE @g TABLE (article_id int NULL, xact_seqno varbinary(16) NULL, cmds bigint, ga int);
INSERT @g (article_id, xact_seqno, cmds, ga)
SELECT s.article_id, rc.xact_seqno, COUNT_BIG(*), GROUPING(s.article_id)
FROM dbo.MSsubscriptions s WITH (NOLOCK)
JOIN dbo.MSrepl_commands rc WITH (NOLOCK) ON rc.publisher_database_id = s.publisher_database_id AND rc.article_id = s.article_id
WHERE s.agent_id = @id AND s.status = 2 AND rc.xact_seqno > @seq AND rc.xact_seqno <= @mx
{CORE}GROUP BY GROUPING SETS ((s.article_id), (rc.xact_seqno));
SELECT g.cmds, ar.article, ISNULL(ar.source_owner + N'.', N'') + ar.source_object AS source_object
FROM @g g
OUTER APPLY (SELECT TOP (1) a.article, a.source_owner, a.source_object FROM dbo.MSarticles a WITH (NOLOCK)
             JOIN dbo.MSsubscriptions s2 WITH (NOLOCK) ON s2.article_id = a.article_id AND s2.publication_id = a.publication_id
                  AND s2.publisher_id = a.publisher_id AND s2.publisher_db = a.publisher_db
             WHERE s2.agent_id = @id AND a.article_id = g.article_id) ar
WHERE g.ga = 0 ORDER BY g.cmds DESC;
SELECT TOP (10) CONVERT(varchar(42), g.xact_seqno, 1) AS xact_seqno, g.cmds, t.entry_time
FROM @g g LEFT JOIN dbo.MSrepl_transactions t WITH (NOLOCK) ON t.publisher_database_id = @pdb AND t.xact_seqno = g.xact_seqno
WHERE g.ga = 1 ORDER BY g.cmds DESC;
SELECT COUNT(*) AS transactions, @pdb AS pdb FROM @g WHERE ga = 1;
'@.Replace('{CORE}', $pendingCore)
$q.Cmd = @'
SET NOCOUNT ON;
DECLARE @x nchar(22) = @s, @pdb int, @bin varbinary(16) = CONVERT(varbinary(16), @s, 1);
SELECT @pdb = publisher_database_id FROM dbo.MSdistribution_agents WHERE id = @aid;
IF @pdb IS NULL
  SELECT TOP (1) @pdb = d.id FROM dbo.MSpublisher_databases d
  WHERE EXISTS (SELECT 1 FROM dbo.MSrepl_transactions t WHERE t.publisher_database_id = d.id AND t.xact_seqno = @bin);
EXEC sys.sp_browsereplcmds @xact_seqno_start = @x, @xact_seqno_end = @x, @publisher_database_id = @pdb, @command_id = @c;
'@
$q.CmdArticle = @'
SET NOCOUNT ON;
DECLARE @pdb int = (SELECT publisher_database_id FROM dbo.MSdistribution_agents WHERE id = @aid);
SELECT TOP (1) a.article, a.source_owner, a.source_object, a.destination_owner, a.destination_object
FROM dbo.MSarticles a JOIN dbo.MSpublisher_databases d ON d.publisher_id = a.publisher_id AND d.publisher_db = a.publisher_db
WHERE d.id = @pdb AND a.article_id = @art;
'@
$q.PostTracer = @'
SET NOCOUNT ON;
DECLARE @tid int;
EXEC sys.sp_posttracertoken @publication = @pub, @tracer_token_id = @tid OUTPUT;
SELECT @tid AS tracer_id;
'@

# ---------------------------------------------------------------------------
# Work done on one server. Self-contained: runs inline or in a parallel runspace.
#   Task.Kind = 'test'   - connection test only
#   Task.Kind = 'server' - everything about the server and its distribution databases
#   Task.Kind = 'dbs'    - row counts (and publication settings) of the given databases
# ---------------------------------------------------------------------------
$collector = {
    param([string]$Name, [hashtable]$Opt, [hashtable]$Task)
    Set-StrictMode -Version 2
    $ErrorActionPreference = 'Stop'
    $Q = $Opt.Q

    function Invoke-Sql([string]$Database, [string]$Query, [hashtable]$Params = @{}, [switch]$Sets) {
        $csb = New-Object "$($Opt.Ns).SqlConnectionStringBuilder"
        $csb['Data Source'] = $Name
        $csb['Initial Catalog'] = $Database
        $csb['Application Name'] = 'Get-ReplTopology'
        $csb['Connect Timeout'] = $Opt.ConnectTimeout
        $csb['TrustServerCertificate'] = -not $Opt.StrictCert
        if ($Opt.Ns -eq 'Microsoft.Data.SqlClient') { $csb['Encrypt'] = $Opt.Encrypt }
        else { $csb['Encrypt'] = ($Opt.Encrypt -ne 'Optional') }
        if ($Opt.Authentication) { $csb['Authentication'] = $Opt.Authentication }
        if ($Opt.User) {
            $csb['User ID'] = $Opt.User
            $csb['Password'] = $Opt.Password
        } elseif (-not $Opt.Authentication) {
            $csb['Integrated Security'] = $true
        }
        $conn = New-Object "$($Opt.Ns).SqlConnection" $csb.ConnectionString
        try {
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = $Query
            $cmd.CommandTimeout = $Opt.QueryTimeout
            foreach ($k in $Params.Keys) { [void]$cmd.Parameters.AddWithValue($k, $Params[$k]) }
            $rdr = $cmd.ExecuteReader()
            if ($Sets) {
                # Every result set of the batch (DataTable.Load moves to the next one and closes the reader after the last)
                $list = New-Object System.Collections.Generic.List[object]
                while (-not $rdr.IsClosed) { $t = New-Object System.Data.DataTable; $t.Load($rdr); $list.Add($t) }
                return , $list
            }
            $dt = New-Object System.Data.DataTable
            $dt.Load($rdr)
            $rdr.Close()
            return , $dt
        } finally {
            $conn.Dispose()
        }
    }
    function V($Row, [string]$Col) {
        if (-not $Row.Table.Columns.Contains($Col)) { return $null }
        $v = $Row[$Col]
        if ($v -is [DBNull]) { return $null }
        return $v
    }
    function S($v) { if ($null -eq $v) { return '' } return [string]$v }
    function Short([string]$s, [int]$Max = 300) {
        $s = ($s -replace '\s+', ' ').Trim()
        if ($s.Length -gt $Max) { $s = $s.Substring(0, $Max) + '...' }
        return $s
    }
    function Up([string]$Cur, [string]$New) {
        $rank = @{ '' = -1; 'ok' = 0; 'unknown' = 1; 'warn' = 2; 'error' = 3 }
        if ($rank[$New] -gt $rank[$Cur]) { return $New } else { return $Cur }
    }
    function ConvertTo-Obj($Row) {
        $h = [ordered]@{}
        foreach ($c in $Row.Table.Columns) {
            $v = $Row[$c.ColumnName]
            if ($v -is [DBNull]) { $v = $null }
            $h[$c.ColumnName] = $v
        }
        return [pscustomobject]$h
    }
    function Get-Objs([string]$Database, [string]$Query, [hashtable]$Params = @{}) {
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($r in (Invoke-Sql $Database $Query $Params).Rows) { $list.Add((ConvertTo-Obj $r)) }
        return , $list
    }
    function Get-SqlError($Err) {
        $e = $Err.Exception
        while ($e) {
            if ($e.GetType().Name -eq 'SqlException') { return @($e.Message, [int]$e.Number) }
            $e = $e.InnerException
        }
        return @($Err.Exception.GetBaseException().Message, 0)
    }
    # Why a connection failed: name resolution, TCP port, or a named instance without a port
    function Get-Probe([string]$Target) {
        $t = $Target.Trim() -replace '^(?i)tcp:', ''
        $port = 1433; $hasPort = $false
        if ($t -match '^(.*?)\s*,\s*(\d+)$') { $t = $Matches[1]; $port = [int]$Matches[2]; $hasPort = $true }
        $isNamed = $t.Contains('\')
        $h = $t.Split([char]'\')[0]
        if ($h -in '.', '(local)', 'localhost') { $h = 'localhost' }
        try { [void][System.Net.Dns]::GetHostAddresses($h) } catch { return "dns-fail|$h" }
        if ($isNamed -and -not $hasPort) { return "named|$h" }
        $c = New-Object System.Net.Sockets.TcpClient
        try {
            $ar = $c.BeginConnect($h, $port, $null, $null)
            if ($ar.AsyncWaitHandle.WaitOne(3000) -and $c.Connected) { return "tcp-open|$h|$port" }
            return "tcp-closed|$h|$port"
        } catch { return "tcp-closed|$h|$port" } finally { $c.Close() }
    }

    $log = New-Object System.Collections.Generic.List[string]
    $cover = New-Object System.Collections.Generic.List[string]
    function Log([string]$Kind, [string]$Text) {
        if ($Opt.Live) {
            switch ($Kind) {
                'H' { Write-Host $Text -ForegroundColor DarkCyan }
                'G' { Write-Host $Text -ForegroundColor DarkGray }
                'W' { Write-Warning $Text }
                default { Write-Verbose $Text }
            }
        } else { $log.Add("$Kind|$Text") }
    }
    function Cover([string]$Text) {
        if (-not $cover.Contains($Text)) { $cover.Add($Text) }
        Log 'V' "  not checked: $Text"
    }
    function New-List { return , (New-Object System.Collections.Generic.List[object]) }
    $statusText = @{ 1 = 'Started'; 2 = 'Stopped'; 3 = 'In progress'; 4 = 'Idle'; 5 = 'Retrying'; 6 = 'Failed' }
    $subText = @{ 0 = 'Inactive'; 1 = 'Subscribed'; 2 = 'Active' }
    # Status and warnings from one row of sp_replmonitorhelpsubscription (what Replication Monitor shows)
    function Get-MonitorHealth($H, [string]$PubType) {
        $o = @{ Level = 'ok'; Problems = (New-Object System.Collections.Generic.List[string]); AgentStatus = ''; Latency = $null; LastSync = ''; AgentId = '' }
        $p = $o.Problems
        $st = V $H 'status'; $rank = V $H 'monitorranking'; $warn = V $H 'warning'; $lat = V $H 'latency'; $last = V $H 'last_distsync'
        if ($null -ne $st -and $statusText.ContainsKey([int]$st)) { $o.AgentStatus = $statusText[[int]$st] }
        if ($null -ne $lat) { $o.Latency = [int]$lat }
        if ($last -is [datetime]) { $o.LastSync = $last.ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) }
        if ($PubType -eq 'Merge') { $o.AgentId = S (V $H 'mergeagentid') } else { $o.AgentId = S (V $H 'distributionagentid') }
        if ($st -eq 6) { $o.Level = 'error'; $p.Add('FAILED') }
        elseif ($st -eq 5) { $o.Level = 'warn'; $p.Add('RETRYING') }
        if ($null -ne $rank) {
            $rank = [int]$rank
            if ($rank -ge 60 -and $o.Level -ne 'error') { $o.Level = 'error'; $p.Add('ERROR') }
            elseif ($rank -eq 56) { $o.Level = Up $o.Level 'warn'; $p.Add('PERFORMANCE CRITICAL') }
            elseif ($rank -eq 54 -and $PubType -eq 'Merge') { $o.Level = Up $o.Level 'warn'; $p.Add('LONG-RUNNING MERGE') }
            elseif ($rank -eq 52) { $o.Level = Up $o.Level 'warn'; $p.Add('EXPIRING') }
            elseif ($rank -eq 50) { $o.Level = Up $o.Level 'warn'; $p.Add('UNINITIALIZED') }
        }
        if ($null -ne $warn) {
            $warn = [int]$warn
            if ($warn -band 2) { $o.Level = Up $o.Level 'warn'; $p.Add("LATENCY $($o.Latency) s") }
            if (($warn -band 5) -and -not $p.Contains('EXPIRING')) { $o.Level = Up $o.Level 'warn'; $p.Add('EXPIRING') }
            if ($warn -band 24) { $o.Level = Up $o.Level 'warn'; $p.Add('SLOW MERGE') }
            if ($warn -band 96) { $o.Level = Up $o.Level 'warn'; $p.Add('LOW MERGE SPEED') }
        }
        return $o
    }
    # Agent history rows -> fixed time buckets: highest latency (s), commands delivered, worst status
    function Get-Buckets($Rows, [datetime]$Now, [int]$Hours, [int]$Count, [bool]$PerSession) {
        $start = $Now.AddHours(-$Hours)
        $size = $Hours * 3600.0 / $Count
        $lat = New-Object 'object[]' $Count; $cmds = New-Object 'double[]' $Count; $st = New-Object 'int[]' $Count
        $sev = @{ 0 = 0; 1 = 1; 4 = 2; 3 = 3; 2 = 4; 5 = 5; 6 = 6 }   # idle < running < stopped < retrying < failed
        $prevCmds = $null; $prevStart = $null
        foreach ($r in $Rows) {
            $t = V $r 'time'
            if (-not ($t -is [datetime])) { continue }
            $i = [int][math]::Floor(($t - $start).TotalSeconds / $size)
            if ($i -lt 0) { $i = 0 } elseif ($i -ge $Count) { $i = $Count - 1 }
            $l = V $r 'latency_ms'
            if ($null -ne $l) { $s = [math]::Round([double]$l / 1000, 1); if ($null -eq $lat[$i] -or $s -gt $lat[$i]) { $lat[$i] = $s } }
            $c = V $r 'cmds'; $ss = V $r 'start_time'
            if ($null -ne $c) {
                $c = [double]$c
                if ($null -ne $prevCmds) {
                    $dlt = $c - $prevCmds
                    if ($PerSession -and "$ss" -ne "$prevStart") { $dlt = $c }   # a new Log Reader session restarts its counter
                    if ($dlt -gt 0) { $cmds[$i] += $dlt }
                }
                $prevCmds = $c; $prevStart = $ss
            }
            $rs = V $r 'runstatus'
            if ($null -ne $rs -and $sev.ContainsKey([int]$rs) -and $sev[[int]$rs] -gt $sev[$st[$i]]) { $st[$i] = [int]$rs }
        }
        return @{ Start = $start.ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture); Size = $size; Lat = $lat; Cmds = $cmds; St = $st }
    }

    $res = [ordered]@{
        Name = $Name; Kind = $Task.Kind; Error = ''; ErrorNumber = 0; Probe = ''
        SrvName = ''; Version = ''; Edition = ''; Login = ''; Sysadmin = $false; ViewServerState = $false; Hadr = $false
        Transport = ''; Port = $null; Listeners = (New-List); AgRows = (New-List); AgDbs = (New-List); Dbs = (New-List)
        AgentService = ''; Jobs = (New-List); Profiles = (New-List); Retention = (New-List)
        DistDbs = @(); DistOk = (New-List); RemoteDistributor = ''; DbErrors = (New-List)
        Edges = (New-List); Articles = (New-List); Redirected = (New-List); Agents = (New-List); Pubs = (New-List); DistPubs = (New-List); DistPubsOk = $false
        DistHealth = (New-List); DbResults = (New-List); Log = $log; Coverage = $cover
        Live = $null; Detail = $null; Repair = $null
    }

    try {
        $b = (Get-Objs 'master' $Q.Basic)[0]
    } catch {
        $se = Get-SqlError $_
        $res.Error = $se[0]; $res.ErrorNumber = $se[1]
        try { $res.Probe = Get-Probe $Name } catch { }
        return [pscustomobject]$res
    }
    $res.SrvName = S $b.srv; $res.Version = S $b.ver; $res.Edition = S $b.ed; $res.Login = S $b.login_name
    $res.Sysadmin = ($b.is_sysadmin -eq 1); $res.ViewServerState = ($b.view_server_state -eq 1); $res.Hadr = ($b.hadr -eq 1)
    $res.Transport = S $b.net_transport; $res.Port = $b.local_tcp_port
    $who = $Name
    if ($res.SrvName) { $who = $res.SrvName }

    if ($Task.Kind -eq 'test') {
        if ($res.Hadr) { try { $res.Listeners = Get-Objs 'master' $Q.Listeners } catch { } }
        try { $res.DistDbs = @((Invoke-Sql 'master' 'SELECT name FROM sys.databases WHERE is_distributor = 1').Rows | ForEach-Object { [string]$_.name }) } catch { }
        return [pscustomobject]$res
    }

    if ($Task.Kind -eq 'dbs') {
        foreach ($d in $Task.Dbs) {
            $counts = @{}; $pub = New-List; $err = ''; $fc = @{}
            if (-not $Task['NoCounts']) {
                try {
                    foreach ($x in (Invoke-Sql $d.Db $Q.RowCounts).Rows) { $counts[("$($x.sch).$($x.tbl)").ToUpperInvariant()] = [long]$x.row_count }
                } catch { $err = (Get-SqlError $_)[0] }
            }
            if ($d.Publisher -and -not $err) {
                try { $pub = Get-Objs $d.Db $Q.PubDb } catch { Cover "Publication settings in $who/$($d.Db): $((Get-SqlError $_)[0])" }
                # -FilteredRowCounts: the publisher rows the row filter lets through (COUNT with the article's own WHERE)
                if ($Opt.FilteredCounts -and -not $Task['NoCounts']) {
                    foreach ($a in $pub) {
                        if (-not $a.filter_clause -or -not $a.src_table) { continue }
                        try {
                            $sql = "SELECT COUNT_BIG(*) AS n FROM [$(([string]$a.src_schema) -replace '\]', ']]')].[$(([string]$a.src_table) -replace '\]', ']]')] WHERE $($a.filter_clause)"
                            $fc[("$($a.publication)|$($a.article)").ToUpperInvariant()] = [long](Invoke-Sql $d.Db $sql).Rows[0].n
                        } catch { Cover "Filtered row count of $($a.publication)/$($a.article) in $who/$($d.Db): $((Get-SqlError $_)[0])" }
                    }
                }
            }
            $res.DbResults.Add([pscustomobject]@{ Db = $d.Db; Error = $err; Counts = $counts; Pub = $pub; FilteredCounts = $fc })
        }
        return [pscustomobject]$res
    }

    # --- live: current state for the monitor (-Monitor) ---
    # --- a repair step from the monitor (the main script decided that it may run): one batch in one database ---
    if ($Task.Kind -eq 'repair') {
        $res.Repair = [ordered]@{ Error = '' }
        try { [void](Invoke-Sql $Task.Db $Task.Sql) } catch { $res.Repair.Error = (Get-SqlError $_)[0] }
        return [pscustomobject]$res
    }
    if ($Task.Kind -eq 'live') {
        $L = [ordered]@{ Now = $null; Subs = (New-List); Agents = (New-List); Pending = (New-List); PendingDbs = (New-List); Errors = (New-List)
                         ErrMap = (New-List); ErrMax = @{}; Sessions = (New-List); SessWaits = (New-List); Waits = (New-List); WaitsOk = $false
                         Ag = (New-List); Jobs = (New-List); JobsOk = $false; Notes = (New-List) }
        $res.Live = $L
        $typeName = @{ 0 = 'Transactional'; 1 = 'Snapshot'; 2 = 'Merge' }
        foreach ($d in $Task.Dist) {
            $db = $d.Db
            foreach ($k in $d.Pairs) {
                $p, $t = $k.Split('|')
                try {
                    $h = Invoke-Sql $db 'SET TRANSACTION ISOLATION LEVEL READ COMMITTED; EXEC sp_replmonitorhelpsubscription @publisher = @p, @publication_type = @t, @mode = 0' @{ '@p' = $p; '@t' = [int]$t }
                    foreach ($x in $h.Rows) {
                        $mh = Get-MonitorHealth $x $typeName[[int]$t]
                        $L.Subs.Add([pscustomobject]@{
                            Db = $db; Key = ("$p|$(S (V $x 'publisher_db'))|$(S (V $x 'publication'))|$(S (V $x 'subscriber'))|$(S (V $x 'subscriber_db'))").ToUpperInvariant()
                            Level = $mh.Level; Problems = $mh.Problems.ToArray(); AgentStatus = $mh.AgentStatus; Latency = $mh.Latency; LastSync = $mh.LastSync; AgentId = $mh.AgentId
                        })
                    }
                } catch { $L.Notes.Add("Agent status ($p) in $who/$db : $((Get-SqlError $_)[0])") }
            }
            try {
                $sets = Invoke-Sql $db $Q.LiveDist @{ '@last' = [int]$d.LastErr; '@hours' = [int]$Opt.HistoryHours } -Sets
                $L.Now = V $sets[0].Rows[0] 'now'
                $L.ErrMax[$db] = V $sets[0].Rows[0] 'max_err'
                foreach ($i in 1, 2, 3) {
                    $target = @($L.Agents, $L.Errors, $L.ErrMap)[$i - 1]
                    foreach ($r in $sets[$i].Rows) { $o = ConvertTo-Obj $r; $o | Add-Member -NotePropertyName Db -NotePropertyValue $db; $target.Add($o) }
                }
            } catch { $L.Notes.Add("Agents in $who/$db : $((Get-SqlError $_)[0])") }
            if ($d.Pending) {
                try {
                    foreach ($r in (Invoke-Sql $db $Q.LivePending).Rows) { $o = ConvertTo-Obj $r; $o | Add-Member -NotePropertyName Db -NotePropertyValue $db; $L.Pending.Add($o) }
                    $L.PendingDbs.Add($db)
                } catch { $L.Notes.Add("Pending commands in $who/$db : $((Get-SqlError $_)[0])") }
            }
        }
        if ($Task.SessionSql) {
            try {
                $sets = Invoke-Sql 'master' $Task.SessionSql -Sets
                foreach ($r in $sets[0].Rows) { $L.Sessions.Add((ConvertTo-Obj $r)) }
                foreach ($r in $sets[1].Rows) { $L.SessWaits.Add((ConvertTo-Obj $r)) }
                foreach ($r in $sets[2].Rows) { $L.Waits.Add((ConvertTo-Obj $r)) }
                $L.WaitsOk = $true
            } catch { $L.Notes.Add("Sessions and waits on $who : $((Get-SqlError $_)[0])") }
        }
        if ($Task.Ag) { try { $L.Ag = Get-Objs 'master' $Q.LiveAg } catch { $L.Notes.Add("Availability groups on $who : $((Get-SqlError $_)[0])") } }
        if ($Task.Jobs) { try { $L.Jobs = Get-Objs 'msdb' $Q.LiveJobs; $L.JobsOk = $true } catch { $L.Notes.Add("Agent jobs on $who : $((Get-SqlError $_)[0])") } }
        return [pscustomobject]$res
    }

    # --- detail of one agent for the monitor: history, errors, pending per article, tracer tokens ---
    if ($Task.Kind -eq 'detail') {
        $D = [ordered]@{ Now = ''; Chart = $null; Msgs = (New-List); Errors = (New-List); Tracer = (New-List); Articles = (New-List)
                         TopTx = (New-List); Transactions = $null; Cmd = ''; TracerId = $null; Notes = (New-List); Fail = $null }
        $res.Detail = $D
        try {
            if ($Task.Mode -eq 'cmd') {
                $c = Invoke-Sql $Task.Db $Q.Cmd @{ '@s' = [string]$Task.Seq; '@aid' = [int]$Task.AgentId; '@c' = [int]$Task.Cmd }
                $D.Cmd = (@($c.Rows | ForEach-Object { S (V $_ 'command') }) -join "`n")
                return [pscustomobject]$res
            }
            if ($Task.Mode -eq 'post') {
                $D.TracerId = V (Invoke-Sql $Task.Db $Q.PostTracer @{ '@pub' = [string]$Task.Publication }).Rows[0] 'tracer_id'
                return [pscustomobject]$res
            }
            $query = $Q.DetailL
            $prm = @{ '@id' = [int]$Task.AgentId; '@hours' = [int]$Task.Hours; '@name' = [string]$Task.AgentName }
            if ($Task.Mode -eq 'sub') { $query = $Q.DetailD; $prm['@pub'] = [string]$Task.Publication }
            $sets = Invoke-Sql $Task.Db $query $prm -Sets
            $now = [datetime](V $sets[0].Rows[0] 'now')
            $D.Now = $now.ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
            $rows = @($sets[1].Rows)
            $D.Chart = Get-Buckets $rows $now ([int]$Task.Hours) 120 ($Task.Mode -eq 'lr')
            # Messages: failures, retries and every change of the text (an idle agent repeats the same line)
            $prev = $null
            foreach ($r in $rows) {
                $m = S (V $r 'comments'); $rs = V $r 'runstatus'
                if ($m -ne $prev -or $rs -eq 5 -or $rs -eq 6) {
                    $tm = V $r 'time'
                    $D.Msgs.Add([ordered]@{ t = $tm.ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture); st = $rs; m = (Short $m 600) })
                }
                $prev = $m
            }
            if ($D.Msgs.Count -gt 200) { $D.Msgs.RemoveRange(0, $D.Msgs.Count - 200) }
            $D.Msgs.Reverse()
            # Errors: one entry per error event (first row = main message, the rest = details)
            $cur = $null
            foreach ($r in $sets[2].Rows) {
                $gid = [int](V $r 'gid')
                if (-not $cur -or $cur.gid -ne $gid) {
                    $cur = [ordered]@{ gid = $gid; t = (V $r 'time').ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture); code = V $r 'error_code'; m = (Short (S (V $r 'error_text')) 1500)
                                       more = (New-List); seq = ''; cmd = $null }
                    $D.Errors.Add($cur)
                } else { $cur.more.Add("$(V $r 'error_code'): $(Short (S (V $r 'error_text')) 800)") }
                $sq = S (V $r 'xact_seqno'); $ci = V $r 'command_id'
                if ($sq -and $sq -notmatch '^0x0+$' -and -not $cur.seq) { $cur.seq = $sq; if ($null -ne $ci -and [int]$ci -gt 0) { $cur.cmd = [int]$ci } }
            }
            # the newest error that points to a command: its text and table (for the repairs and the AI report)
            $fe = $null
            foreach ($er in $D.Errors) { if ($er.seq -and $null -ne $er.cmd) { $fe = $er; break } }
            if ($Task.Mode -eq 'sub' -and $fe) {
                try {
                    $seq10 = $fe.seq.Substring(0, [Math]::Min(22, $fe.seq.Length))
                    $c = Invoke-Sql $Task.Db $Q.Cmd @{ '@s' = $seq10; '@aid' = [int]$Task.AgentId; '@c' = [int]$fe.cmd }
                    if ($c.Rows.Count) {
                        $D.Fail = [ordered]@{ seq = $seq10; cmd = [int]$fe.cmd; command = (Short (S (V $c.Rows[0] 'command')) 4000); article = ''; srcOwner = ''; src = ''; dstOwner = ''; dst = '' }
                        $art = V $c.Rows[0] 'article_id'
                        if ($null -ne $art) {
                            $a = Invoke-Sql $Task.Db $Q.CmdArticle @{ '@aid' = [int]$Task.AgentId; '@art' = [int]$art }
                            if ($a.Rows.Count) {
                                $r0 = $a.Rows[0]
                                $D.Fail.article = S (V $r0 'article'); $D.Fail.srcOwner = S (V $r0 'source_owner'); $D.Fail.src = S (V $r0 'source_object')
                                $D.Fail.dstOwner = S (V $r0 'destination_owner'); $D.Fail.dst = S (V $r0 'destination_object')
                            }
                        }
                    }
                } catch { $D.Notes.Add("Failing command: $((Get-SqlError $_)[0])") }
            }
            if ($Task.Mode -eq 'sub') {
                foreach ($r in $sets[3].Rows) {
                    $pc = V $r 'publisher_commit'; $dc = V $r 'distributor_commit'; $sc = V $r 'subscriber_commit'
                    $toDist = $null; $toSub = $null; $total = $null
                    if ($pc -is [datetime] -and $dc -is [datetime]) { $toDist = [math]::Round(($dc - $pc).TotalSeconds, 1) }
                    if ($dc -is [datetime] -and $sc -is [datetime]) { $toSub = [math]::Round(($sc - $dc).TotalSeconds, 1) }
                    if ($pc -is [datetime] -and $sc -is [datetime]) { $total = [math]::Round(($sc - $pc).TotalSeconds, 1) }
                    $posted = ''
                    if ($pc -is [datetime]) { $posted = $pc.ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) }
                    $D.Tracer.Add([ordered]@{ id = V $r 'tracer_id'; t = $posted; toDist = $toDist; toSub = $toSub; total = $total })
                }
            }
        } catch { $D.Notes.Add("History of the agent: $((Get-SqlError $_)[0])") }
        if ($Task.Mode -eq 'sub' -and $Task.Pending) {
            try {
                $ps = Invoke-Sql $Task.Db $Q.DetailPending @{ '@id' = [int]$Task.AgentId } -Sets
                foreach ($r in $ps[0].Rows) { $D.Articles.Add([ordered]@{ a = S (V $r 'article'); src = S (V $r 'source_object'); n = [long](V $r 'cmds') }) }
                foreach ($r in $ps[1].Rows) {
                    $et = V $r 'entry_time'; $ets = ''
                    if ($et -is [datetime]) { $ets = $et.ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) }
                    $D.TopTx.Add([ordered]@{ seq = S (V $r 'xact_seqno'); n = [long](V $r 'cmds'); t = $ets })
                }
                $D.Transactions = V $ps[2].Rows[0] 'transactions'
            } catch { $D.Notes.Add("Pending commands per article: $((Get-SqlError $_)[0])") }
        }
        return [pscustomobject]$res
    }

    # --- server: databases, log usage, availability groups, SQL Server Agent, jobs ---
    try { $res.Dbs = Get-Objs 'master' $Q.Dbs } catch { Cover "Databases on $who : $((Get-SqlError $_)[0])" }
    foreach ($d in $res.Dbs) {
        $d | Add-Member -NotePropertyName LogUsedPct -NotePropertyValue $null
        $d | Add-Member -NotePropertyName LogSizeMb -NotePropertyValue $null
    }
    if ($res.ViewServerState) {
        try {
            $perf = @{}
            foreach ($x in (Invoke-Sql 'master' $Q.Perf).Rows) { $perf[("$($x.db)|$($x.counter_name)").ToUpperInvariant()] = [long]$x.cntr_value }
            foreach ($d in $res.Dbs) {
                $k = ([string]$d.name).ToUpperInvariant()
                if ($perf.ContainsKey("$k|PERCENT LOG USED")) { $d.LogUsedPct = $perf["$k|PERCENT LOG USED"] }
                if ($perf.ContainsKey("$k|LOG FILE(S) SIZE (KB)")) { $d.LogSizeMb = [math]::Round($perf["$k|LOG FILE(S) SIZE (KB)"] / 1024) }
            }
        } catch { Cover "Log usage on $who : $((Get-SqlError $_)[0])" }
        try { $res.AgentService = S (Invoke-Sql 'master' $Q.AgentSvc).Rows[0].agent_status } catch { Cover "SQL Server Agent state on $who : $((Get-SqlError $_)[0])" }
    } else {
        Cover "Log usage, AG roles and SQL Server Agent state on $who : the login needs VIEW SERVER STATE"
    }
    if ($res.Hadr) {
        try {
            $agQ = $Q.AgNoDmv
            if ($res.ViewServerState) { $agQ = $Q.Ag }
            $res.AgRows = Get-Objs 'master' $agQ
            $res.AgDbs = Get-Objs 'master' $Q.AgDbs
            if ($res.AgRows.Count -eq 0) { Cover "Availability groups on $who : HADR is enabled but no AG is visible to the login (needs VIEW ANY DEFINITION)" }
        } catch { Cover "Availability groups on $who : $((Get-SqlError $_)[0])" }
    }
    try { $res.Jobs = Get-Objs 'msdb' $Q.Jobs } catch { Cover "Replication agent jobs on $who (msdb): $((Get-SqlError $_)[0])" }
    try { $res.Profiles = Get-Objs 'msdb' $Q.Profiles } catch { Cover "Agent profiles on $who (msdb): $((Get-SqlError $_)[0])" }
    try { $res.Retention = Get-Objs 'msdb' $Q.Retention } catch { }

    try {
        $res.DistDbs = @((Invoke-Sql 'master' 'SELECT name FROM sys.databases WHERE is_distributor = 1 AND state = 0').Rows | ForEach-Object { [string]$_.name })
    } catch { Log 'V' "  sys.databases: $($_.Exception.Message)" }
    try {
        $gd = Invoke-Sql 'master' 'EXEC sp_get_distributor'
        if ($gd.Rows.Count -gt 0 -and $gd.Rows[0][0] -eq 1) { $res.RemoteDistributor = S $gd.Rows[0][1] }
    } catch { Log 'V' "  sp_get_distributor: $($_.Exception.Message)" }
    if ($res.DistDbs.Count -gt 0) {
        # publishers registered at this distributor (every replica of a published AG database has to be one)
        try { $res.DistPubs = Get-Objs 'msdb' $Q.DistPubs; $res.DistPubsOk = $true }
        catch { Cover "Publishers registered at the distributor $who (msdb.dbo.MSdistpublishers): $((Get-SqlError $_)[0])" }
    }

    foreach ($db in $res.DistDbs) {
        Log 'H' "    distribution: $db"
        try {
            $dt = Invoke-Sql $db $Q.Edges
        } catch {
            $msg = (Get-SqlError $_)[0]
            $res.DbErrors.Add("Database $db : $msg")
            Log 'W' "  Database $db : $msg"
            continue
        }
        $res.DistOk.Add($db)
        $rows = @($dt.Rows)

        # Health: one call per publisher and publication type (the procedure returns no publisher column)
        $health = @{}; $agentMsg = @{}
        if (-not $Opt.NoHealth) {
            $pairs = @{}
            foreach ($r in $rows) {
                $p = S (V $r 'pub_server')
                if ($p -and $p -notlike 'publisher_id=*' -and $null -ne (V $r 'sub_server')) { $pairs["$p|$([int](V $r 'publication_type'))"] = $true }
            }
            foreach ($k in $pairs.Keys) {
                $p, $t = $k.Split('|')
                try {
                    $h = Invoke-Sql $db 'SET TRANSACTION ISOLATION LEVEL READ COMMITTED; EXEC sp_replmonitorhelpsubscription @publisher = @p, @publication_type = @t, @mode = 0' @{ '@p' = $p; '@t' = [int]$t }
                    foreach ($x in $h.Rows) {
                        $hk = ("$p|$(S (V $x 'publisher_db'))|$(S (V $x 'publication'))|$(S (V $x 'subscriber'))|$(S (V $x 'subscriber_db'))").ToUpperInvariant()
                        $health[$hk] = $x
                    }
                } catch { Log 'W' "  Health ($p, type $t) in $db : $((Get-SqlError $_)[0])" }
            }
        }
        try {
            foreach ($a in (Get-Objs $db $Q.Agents @{ '@h' = [int]$Opt.HistoryHours })) {
                $a | Add-Member -NotePropertyName DistDb -NotePropertyValue $db
                $res.Agents.Add($a)
                $agentMsg["$($a.kind)|$($a.agent_id)"] = $a
            }
        } catch { Log 'W' "  Agents in $db : $((Get-SqlError $_)[0])" }

        # Pending commands need sysadmin or db_owner in the distribution database
        $canPending = $false
        if (-not $Opt.NoHealth -and -not $Opt.NoPending) {
            try {
                $pp = (Invoke-Sql $db $Q.Perm).Rows[0]
                $canPending = ((V $pp 'sa') -eq 1 -or (V $pp 'dbo') -eq 1)
            } catch { }
            if (-not $canPending) {
                Cover "Pending commands in $who/$db : the login $($res.Login) needs sysadmin or db_owner in the distribution database"
                Log 'W' "  Pending commands skipped in $db : the login needs sysadmin or db_owner"
            }
        }
        $subCount = @($rows | Where-Object { $null -ne (V $_ 'sub_server') }).Count
        $done = 0

        foreach ($r in $rows) {
            $status = V $r 'status'
            if ($null -ne $status) { $status = [int]$status }
            $e = [pscustomobject]@{
                Distributor = ''; DistributionDb = S (V $r 'distribution_db')
                PubServerRaw = S (V $r 'pub_server'); PubDb = S (V $r 'pub_db'); Publication = S (V $r 'publication')
                PubType = S (V $r 'pub_type'); SubServerRaw = S (V $r 'sub_server'); SubDb = S (V $r 'sub_db'); SubType = S (V $r 'sub_type')
                Status = $status; StatusText = ''; Inactive = ($status -eq 0); AgentId = ''
                Health = ''; AgentStatus = ''; Latency = $null; LastSync = ''; Pending = $null; Problem = ''; Message = ''
            }
            if ($null -ne $status -and $subText.ContainsKey($status)) { $e.StatusText = $subText[$status] }
            if ($e.SubServerRaw) {
                $done++
                if ($Opt.Live -and $subCount -gt 3) { Write-Progress -Activity "Health of subscriptions in $db" -Status "$done of $subCount" -PercentComplete (100 * $done / $subCount) }
                $level = ''
                $problems = New-Object System.Collections.Generic.List[string]
                $hk = ("$($e.PubServerRaw)|$($e.PubDb)|$($e.Publication)|$($e.SubServerRaw)|$($e.SubDb)").ToUpperInvariant()
                if ($health.ContainsKey($hk)) {
                    $mh = Get-MonitorHealth $health[$hk] $e.PubType
                    $level = $mh.Level
                    foreach ($pr in $mh.Problems) { $problems.Add($pr) }
                    $e.AgentStatus = $mh.AgentStatus; $e.Latency = $mh.Latency; $e.LastSync = $mh.LastSync; $e.AgentId = $mh.AgentId
                    if ($e.PubType -eq 'Merge') { $agentKey = "M|$($e.AgentId)" }
                    else {
                        $agentKey = "D|$($e.AgentId)"
                        if ($canPending -and ($e.PubType -eq 'Transactional' -or $e.PubType -eq 'P2P') -and ($e.SubType -eq 'Push' -or $e.SubType -eq 'Pull')) {
                            try {
                                $pc = Invoke-Sql $db $Q.Pending @{ '@p' = $e.PubServerRaw; '@pd' = $e.PubDb; '@pub' = $e.Publication
                                                                   '@s' = $e.SubServerRaw; '@sd' = $e.SubDb; '@t' = [int]($e.SubType -eq 'Pull') }
                                if ($pc.Rows.Count -gt 0 -and $null -ne (V $pc.Rows[0] 'pendingcmdcount')) { $e.Pending = [long](V $pc.Rows[0] 'pendingcmdcount') }
                            } catch {
                                $se = Get-SqlError $_
                                if ($se[1] -in 229, 297, 300, 15247, 21050) {
                                    $canPending = $false
                                    Cover "Pending commands in $who/$db : $($se[0])"
                                } else { Log 'W' "  Pending commands ($($e.Publication) -> $($e.SubServerRaw)/$($e.SubDb)): $($se[0])" }
                            }
                        }
                    }
                    if ($agentMsg.ContainsKey($agentKey)) {
                        # Agent comment is the most specific; error rows of the same run are added after it
                        $m = $agentMsg[$agentKey]
                        $txt = S $m.comments
                        $err = S $m.error_text
                        if ($err -and -not $txt.Contains($err)) { $txt = (@($txt, $err) | Where-Object { $_ }) -join ' | ' }
                        $e.Message = Short $txt 400
                    }
                    if ($null -ne $e.Pending -and $e.Pending -ge $Opt.PendingWarn) { $level = Up $level 'warn'; $problems.Add("PENDING $($e.Pending)") }
                } elseif (-not $Opt.NoHealth) {
                    $level = 'unknown'
                }
                if ($e.Inactive) { $level = 'error'; $problems.Insert(0, 'INACTIVE') }
                $e.Health = $level
                $e.Problem = (@($problems | Select-Object -Unique) -join ', ')
            }
            $res.Edges.Add($e)
        }
        if ($Opt.Live -and $subCount -gt 3) { Write-Progress -Activity "Health of subscriptions in $db" -Completed }
        Log 'G' "      relations: $($rows.Count)"

        try {
            foreach ($a in (Invoke-Sql $db $Q.Articles).Rows) {
                $res.Articles.Add([pscustomobject]@{
                    PubServerRaw = S (V $a 'pub_server'); PubDb = S (V $a 'pub_db'); Publication = S (V $a 'publication')
                    Article = S (V $a 'article'); Source = S (V $a 'source_object'); Destination = S (V $a 'destination_object')
                })
            }
        } catch { Log 'W' "  Articles in $db : $((Get-SqlError $_)[0])" }
        try {
            foreach ($x in (Invoke-Sql $db $Q.Redirect).Rows) {
                $res.Redirected.Add([pscustomobject]@{ Original = S (V $x 'original_publisher'); Db = S (V $x 'publisher_db'); Listener = S (V $x 'redirected_publisher') })
            }
        } catch { Log 'V' "  MSredirected_publishers in $db : $($_.Exception.Message)" }
        try {
            foreach ($p in (Get-Objs $db $Q.Pubs)) { $p | Add-Member -NotePropertyName DistDb -NotePropertyValue $db; $res.Pubs.Add($p) }
        } catch { Cover "Publication settings in $who/$db : $((Get-SqlError $_)[0])" }
        try {
            $dh = (Get-Objs $db $Q.DistHealth)[0]
            $dh | Add-Member -NotePropertyName Db -NotePropertyValue $db
            $res.DistHealth.Add($dh)
        } catch { Cover "Size of $who/$db : $((Get-SqlError $_)[0])" }
    }
    return [pscustomobject]$res
}

# ---------------------------------------------------------------------------
# Helpers (main runspace)
# ---------------------------------------------------------------------------
function Get-NormName([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    $n = $Name.Trim().ToUpperInvariant() -replace '^TCP:', ''
    $port = ''
    if ($n -match '^(.*?)\s*,\s*(\d+)$') { $n = $Matches[1]; $port = ',' + $Matches[2] }
    $inst = ''
    if ($n.Contains('\')) {
        $p = $n.Split([char]'\', 2); $hostPart = $p[0]; $inst = '\' + $p[1]
    } else { $hostPart = $n }
    # The port stays in the name until the server tells its real name (two instances can share a host)
    if ($hostPart -in '.', '(LOCAL)', 'LOCALHOST', '127.0.0.1', '::1') { $hostPart = '.' }
    elseif (-not $KeepDomain -and $hostPart -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
        $hostPart = $hostPart.Split([char]'.')[0]
    }
    return $hostPart + $inst + $port
}
function Remove-Port([string]$Name) { if (-not $Name) { return $Name } return ($Name -replace ',\d+$', '') }

function Resolve-Name([string]$n) {
    $i = 0
    while ($n -and $aliasMap.ContainsKey($n) -and $i -lt 10) { $n = $aliasMap[$n]; $i++ }
    return $n
}

function Get-Major([string]$Version) { if ($Version -match '^(\d+)\.') { return [int]$Matches[1] } return 0 }
$verName = @{ 9 = '2005'; 10 = '2008/R2'; 11 = '2012'; 12 = '2014'; 13 = '2016'; 14 = '2017'; 15 = '2019'; 16 = '2022'; 17 = '2025' }
# End of extended support (Microsoft lifecycle)
$supportEnd = @{ 9 = [datetime]'2016-04-12'; 10 = [datetime]'2019-07-09'; 11 = [datetime]'2022-07-12'; 12 = [datetime]'2024-07-09'
                 13 = [datetime]'2026-07-14'; 14 = [datetime]'2027-10-12'; 15 = [datetime]'2030-01-08'; 16 = [datetime]'2033-01-11' }
function Get-SqlYear([string]$Version) {
    if (-not $Version) { return '' }
    $major = Get-Major $Version
    if ($verName.ContainsKey($major)) { return "SQL $($verName[$major])" }
    return "v$Version"
}

function Get-Prop($Obj, [string]$Name) {
    $p = $Obj.PSObject.Properties[$Name]
    if ($p) { return $p.Value } else { return $null }
}

# JSON writer (same output in PowerShell 5.1 and 7; '<' escaped so it is safe inside <script>)
function ConvertTo-JsonText($o) {
    if ($null -eq $o -or $o -is [DBNull]) { return 'null' }
    if ($o -is [string] -or $o -is [char] -or $o -is [datetime]) {
        if ($o -is [datetime]) { $o = $o.ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) }
        $s = [regex]::Replace([string]$o, '[\\"\u0000-\u001f<>&\u2028\u2029]', [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            if ($m.Value -eq '\') { '\\' } elseif ($m.Value -eq '"') { '\"' } else { '\u{0:x4}' -f [int][char]$m.Value }
        })
        return '"' + $s + '"'
    }
    if ($o -is [bool]) { if ($o) { return 'true' } else { return 'false' } }
    if ($o -is [ValueType]) { return ([IFormattable]$o).ToString($null, [Globalization.CultureInfo]::InvariantCulture) }
    if ($o -is [System.Collections.IDictionary]) {
        $parts = foreach ($k in $o.Keys) { (ConvertTo-JsonText ([string]$k)) + ':' + (ConvertTo-JsonText $o[$k]) }
        return '{' + (@($parts) -join ',') + '}'
    }
    if ($o -is [System.Collections.IEnumerable]) {
        $parts = foreach ($x in $o) { ConvertTo-JsonText $x }
        return '[' + (@($parts) -join ',') + ']'
    }
    $parts = foreach ($p in $o.PSObject.Properties) { (ConvertTo-JsonText $p.Name) + ':' + (ConvertTo-JsonText $p.Value) }
    return '{' + (@($parts) -join ',') + '}'
}

function Esc-Mmd([string]$s) { return ($s -replace '"', '#34;' -replace '<', '#60;' -replace '>', '#62;') }
function Esc-Dot([string]$s) { return ($s -replace '\\', '\\' -replace '"', '\"') }
function Enc-Html([string]$s) { return [System.Net.WebUtility]::HtmlEncode($s) }

# CSV for Excel: list separator of the regional settings, UTF-8 with BOM
function Export-ReportCsv($Rows, [string]$File) {
    if ($Monitor) { return }
    $enc = 'UTF8'
    if ($PSVersionTable.PSVersion.Major -ge 6) { $enc = 'utf8BOM' }
    $list = @($Rows | Where-Object { $null -ne $_ })
    if ($list.Count -eq 0) { return }
    $list | Export-Csv -LiteralPath (Join-Path $OutputDir $File) -NoTypeInformation -Encoding $enc -UseCulture
}

# Replication agent command line: -Name [value] / "value" / value / switch
function Get-AgentArgs([string]$Command) {
    $h = @{}
    if (-not $Command) { return $h }
    foreach ($m in [regex]::Matches($Command, '(?:^|\s)-(\w+)(?:\s+(\[[^\]]*\]|"[^"]*"|[^\s\-][^\s]*))?')) {
        $h[$m.Groups[1].Value.ToUpperInvariant()] = $m.Groups[2].Value.Trim('[', ']', '"')
    }
    return $h
}

$findings = New-Object System.Collections.Generic.List[object]
function Add-Finding([string]$Severity, [string]$Category, [string]$Server, [string]$Object, [string]$Text, [string]$Fix = '', $Data = $null) {
    # Data: what a repair needs (job id, replicas...); the repair catalog turns it into actions
    $findings.Add([pscustomobject]@{ Severity = $Severity; Category = $Category; Server = $Server; Object = $Object; Finding = $Text; Recommendation = $Fix; Data = $Data })
}

function Get-ConnHint($r, [string]$Target) {
    $msg = [string]$r.Error
    $num = 0
    if ($r.PSObject.Properties['ErrorNumber']) { $num = [int]$r.ErrorNumber }
    $probe = ''
    if ($r.PSObject.Properties['Probe']) { $probe = [string]$r.Probe }
    $p = $probe.Split('|')
    $first = (($msg -replace '\s+', ' ') -split '(?<=\.)\s')[0]
    if ($p[0] -eq 'dns-fail') { return "DNS: host '$($p[1])' not found" }
    if ($num -eq 18456) { return "Login failed for $authText (error 18456)" }
    if ($num -eq 18452) { return 'Windows login not accepted (untrusted domain) - try -SqlUser' }
    if ($num -eq 4060) { return 'Login works but the default database is not available (error 4060)' }
    if ($msg -match '(?i)certificate|SSL Provider|TLS') { return "TLS/certificate problem - check -Encrypt / -StrictCert ($first)" }
    if ($p[0] -eq 'tcp-closed') { return "Port $($p[2]) on $($p[1]) is closed or filtered (server down, firewall, or SQL Server listens on another port)" }
    if ($p[0] -eq 'named') { return "Instance not found through SQL Browser (UDP 1434 blocked or wrong instance name) - add the port: $Target,<port>" }
    if ($num -eq -2 -or $msg -match '(?i)timeout') { return "Timeout ($first)" }
    return $first
}

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
$queue        = New-Object System.Collections.Queue
$queued       = @{}   # name -> $true
$visited      = @{}   # name -> $true
$connectName  = @{}   # name -> connection string used
$connectFor   = @{}   # server/listener -> connection string that works (ports from the list, AG listeners, routing URLs)
$tried        = @{}   # failed name -> connection string tried
$retried      = @{}
$serverInfo   = @{}   # instance (@@SERVERNAME) -> object
$failed       = @{}   # name -> error / hint
$aliasMap     = @{}   # name -> canonical name (from -Alias, connections, AG listeners)
$redirect     = @{}   # "ORIGINALPUBLISHER|DB" -> listener (MSredirected_publishers)
$ags          = @{}   # AG name -> object
$agByListener = @{}   # listener -> AG name
$agByInstDb   = @{}   # "REPLICA|DB" -> AG name
$listenerInst = @{}   # listener -> instance reached through it (the primary at that time)
$readOk       = @{}   # "DISTRIBUTOR|DISTRIBUTIONDB" read without error
$coverage     = New-Object 'System.Collections.Generic.HashSet[string]'
$edges        = New-Object System.Collections.Generic.List[object]
$articles     = New-Object System.Collections.Generic.List[object]
$agents       = New-Object System.Collections.Generic.List[object]
$pubs         = New-Object System.Collections.Generic.List[object]
$tests        = New-Object System.Collections.Generic.List[object]

foreach ($k in $Alias.Keys) {
    $from = Get-NormName ([string]$k); $to = Get-NormName ([string]$Alias[$k])
    if ($from -and $to -and $from -ne $to) { $aliasMap[$from] = $to }
}

$opt = @{
    Ns = $sqlNs; ConnectTimeout = $ConnectTimeout; QueryTimeout = $QueryTimeout; StrictCert = [bool]$StrictCert
    Encrypt = $Encrypt; Authentication = ''; User = ''; Password = ''
    NoHealth = [bool]$NoHealth; NoPending = [bool]$NoPendingCommands; PendingWarn = $PendingWarn; HistoryHours = $HistoryHours
    Q = $q; Live = $false; FilteredCounts = [bool]$FilteredRowCounts
}
if ($Authentication -ne 'Default') { $opt.Authentication = $Authentication -creplace '(?<=[a-z])(?=[A-Z])', ' ' }
if ($SqlCredential) {
    $opt.User = $SqlCredential.UserName
    $opt.Password = $SqlCredential.GetNetworkCredential().Password
}

# Availability groups: listeners, replicas, databases; listener ports and routing URLs become connection strings
function Add-AgInfo($r) {
    foreach ($x in $r.AgRows) {
        $agKey = ([string]$x.ag_name).ToUpperInvariant()
        if (-not $ags.ContainsKey($agKey)) {
            $ags[$agKey] = [pscustomobject]@{ Name = [string]$x.ag_name; Listeners = (New-Object System.Collections.Generic.List[string]); ListenerPorts = @{}
                                              Replicas = [ordered]@{}; Dbs = (New-Object 'System.Collections.Generic.HashSet[string]')
                                              DbNames = (New-Object System.Collections.Generic.List[string]); Primary = '' }
        }
        $ag = $ags[$agKey]
        $rep = Get-NormName ([string]$x.replica_server_name)
        if ($rep) {
            if (-not $ag.Replicas.Contains($rep)) { $ag.Replicas[$rep] = '' }
            if ($x.role_desc) {
                $ag.Replicas[$rep] = [string]$x.role_desc
                if ($x.role_desc -eq 'PRIMARY') { $ag.Primary = $rep }
            }
            if ([string]$x.read_only_routing_url -match '^(?i)tcp://([^:/]+):(\d+)' -and -not $connectFor.ContainsKey($rep)) {
                $connectFor[$rep] = "$($Matches[1]),$($Matches[2])"
            }
        }
        if ($x.dns_name) {
            $l = Remove-Port (Get-NormName ([string]$x.dns_name))
            if (-not $ag.Listeners.Contains($l)) { $ag.Listeners.Add($l) }
            $agByListener[$l] = $agKey
            if ($x.port) {
                $ag.ListenerPorts[$l] = [int]$x.port
                $aliasMap["$l,$($x.port)"] = $l
                if ([int]$x.port -ne 1433 -and -not $connectFor.ContainsKey($l)) { $connectFor[$l] = "$($x.dns_name),$($x.port)" }
            }
        }
    }
    foreach ($x in $r.AgDbs) {
        $agKey = ([string]$x.ag_name).ToUpperInvariant()
        if ($ags.ContainsKey($agKey) -and $ags[$agKey].Dbs.Add(([string]$x.database_name).ToUpperInvariant())) { $ags[$agKey].DbNames.Add([string]$x.database_name) }
    }
    foreach ($agKey in @($ags.Keys)) {
        $ag = $ags[$agKey]
        foreach ($rep in @($ag.Replicas.Keys)) { foreach ($db in $ag.Dbs) { $agByInstDb["$rep|$db"] = $agKey } }
    }
}

# AG metadata not visible to the login: a name that leads to another server is most likely a listener
function Add-GuessedListener([string]$Listener, [string]$Instance) {
    $agKey = "?$Listener"
    if (-not $ags.ContainsKey($agKey)) {
        $ags[$agKey] = [pscustomobject]@{ Name = "(not visible, listener $Listener)"; Listeners = (New-Object System.Collections.Generic.List[string]); ListenerPorts = @{}
                                          Replicas = [ordered]@{}; Dbs = (New-Object 'System.Collections.Generic.HashSet[string]')
                                          DbNames = (New-Object System.Collections.Generic.List[string]); Primary = '' }
        $ags[$agKey].Listeners.Add($Listener)
    }
    $ags[$agKey].Replicas[$Instance] = 'PRIMARY'
    $ags[$agKey].Primary = $Instance
    $agByListener[$Listener] = $agKey
    return $Listener
}

# Logical server of a database: the AG listener for AG databases, otherwise the instance
function Get-Canon([string]$Inst, [string]$Db) {
    if (-not $Inst -or -not $Db) { return $Inst }
    if ($agByListener.ContainsKey($Inst)) { return $Inst }
    $k = "$Inst|$($Db.ToUpperInvariant())"
    if ($agByInstDb.ContainsKey($k)) {
        $ag = $ags[$agByInstDb[$k]]
        if ($ag.Listeners.Count -gt 0) { return $ag.Listeners[0] }
    }
    if ($redirect.ContainsKey($k)) { return $redirect[$k] }
    return $Inst
}
function Get-Instances([string]$Canon) {
    if ($Canon -and $agByListener.ContainsKey($Canon)) {
        $list = @($ags[$agByListener[$Canon]].Replicas.Keys)
        if ($listenerInst.ContainsKey($Canon) -and $list -notcontains $listenerInst[$Canon]) { $list += $listenerInst[$Canon] }
        return $list
    }
    return @($Canon)
}
function Get-PrimaryInstance([string]$Canon) {
    if ($Canon -and $agByListener.ContainsKey($Canon)) {
        if ($listenerInst.ContainsKey($Canon)) { return $listenerInst[$Canon] }
        $p = $ags[$agByListener[$Canon]].Primary
        if ($p) { return $p }
        return $null
    }
    return $Canon
}
function Get-Target([string]$Canon) {
    if ($connectFor.ContainsKey($Canon)) { return $connectFor[$Canon] }
    if ($connectName.ContainsKey($Canon)) { return $connectName[$Canon] }
    return $Canon
}

# Runs the collector for several servers (in parallel when possible); calls $OnResult as each one finishes
$collectText = $collector.ToString()
function Invoke-Collect([object[]]$Items, [string]$OnResult, [string]$Activity) {
    if ($Items.Count -eq 0) { return }
    if ($ThrottleLimit -le 1 -or $Items.Count -eq 1) {
        foreach ($it in $Items) {
            $o = $opt.Clone()
            $o.Live = ($it.Task.Kind -eq 'server')
            if ($o.Live) { Write-Host "[*] $($it.Target)" -ForegroundColor Cyan }
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $r = & $collector $it.Target $o $it.Task
            & $OnResult $it $r $sw.Elapsed.TotalSeconds $o.Live
        }
        return
    }
    $pool = [runspacefactory]::CreateRunspacePool(1, [Math]::Min($ThrottleLimit, $Items.Count))
    $pool.Open()
    try {
        $jobs = @(foreach ($it in $Items) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $pool
            [void]$ps.AddScript($collectText).AddArgument($it.Target).AddArgument($opt).AddArgument($it.Task)
            [pscustomobject]@{ Item = $it; PS = $ps; Handle = $ps.BeginInvoke(); Done = $false; Watch = [Diagnostics.Stopwatch]::StartNew() }
        })
        $total = $jobs.Count
        while ($true) {
            $left = @($jobs | Where-Object { -not $_.Done })
            if ($left.Count -eq 0) { break }
            $names = (@($left | Select-Object -First 4 | ForEach-Object { $_.Item.Target }) -join ', ')
            Write-Progress -Activity $Activity -Status ("{0} of {1} done, waiting for: {2}" -f ($total - $left.Count), $total, $names) -PercentComplete (100 * ($total - $left.Count) / $total)
            foreach ($j in $left) {
                if (-not $j.Handle.IsCompleted) { continue }
                $j.Done = $true
                $r = $null
                try {
                    $out = $j.PS.EndInvoke($j.Handle)
                    if ($out.Count -gt 0) { $r = $out[0] }
                } catch { $r = [pscustomobject]@{ Error = $_.Exception.Message; ErrorNumber = 0; Probe = ''; Log = @(); Coverage = @() } }
                if (-not $r) {
                    $msg = @($j.PS.Streams.Error | ForEach-Object { $_.ToString() }) -join ' '
                    $r = [pscustomobject]@{ Error = "No result. $msg"; ErrorNumber = 0; Probe = ''; Log = @(); Coverage = @() }
                }
                $j.PS.Dispose()
                & $OnResult $j.Item $r $j.Watch.Elapsed.TotalSeconds $false
            }
            Start-Sleep -Milliseconds 150
        }
        Write-Progress -Activity $Activity -Completed
    } finally {
        $pool.Close(); $pool.Dispose()
    }
}

function Write-ServerLog($Lines) {
    foreach ($l in $Lines) {
        $kind = $l.Substring(0, 1); $text = $l.Substring(2)
        switch ($kind) {
            'H' { Write-Host $text -ForegroundColor DarkCyan }
            'G' { Write-Host $text -ForegroundColor DarkGray }
            'W' { Write-Warning $text }
            default { Write-Verbose $text }
        }
    }
}

# ---------------------------------------------------------------------------
# 0. -Scan / -ScanHost: SQL Server instances on this computer and from SQL Browser (UDP 1434)
# ---------------------------------------------------------------------------
function Get-LocalInstances {
    $out = New-Object System.Collections.Generic.List[object]
    if ($env:OS -ne 'Windows_NT') { return , $out }
    $root = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server'
    $names = Get-ItemProperty -Path "$root\Instance Names\SQL" -ErrorAction SilentlyContinue
    if (-not $names) { return , $out }
    foreach ($p in $names.PSObject.Properties) {
        if ($p.Name -in 'PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider') { continue }
        $inst = $p.Name; $id = [string]$p.Value; $port = ''; $ver = ''; $state = ''
        $tcp = Get-ItemProperty -Path "$root\$id\MSSQLServer\SuperSocketNetLib\Tcp\IPAll" -ErrorAction SilentlyContinue
        if ($tcp) {
            foreach ($n in 'TcpPort', 'TcpDynamicPorts') {
                $v = $tcp.PSObject.Properties[$n]
                if ($v -and [string]$v.Value -and -not $port) { $port = ([string]$v.Value -split ',')[0].Trim() }
            }
        }
        $setup = Get-ItemProperty -Path "$root\$id\Setup" -ErrorAction SilentlyContinue
        if ($setup -and $setup.PSObject.Properties['Version']) { $ver = [string]$setup.Version }
        $svc = 'MSSQLSERVER'; $name = $env:COMPUTERNAME
        if ($inst -ne 'MSSQLSERVER') { $svc = "MSSQL`$$inst"; $name = "$env:COMPUTERNAME\$inst" }
        $sv = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($sv) { $state = [string]$sv.Status }
        $out.Add([pscustomobject]@{ Server = $name; Port = $port; Version = $ver; Note = "this computer, service $state".TrimEnd() })
    }
    return , $out
}
# SQL Server Resolution Protocol: 0x02 asks every SQL Browser in the subnet, 0x03 one host; the answer is
# 0x05, a 2-byte length and "ServerName;X;InstanceName;Y;IsClustered;No;Version;15.0...;tcp;1433;;" per instance
function Get-BrowserInstances([string[]]$Hosts, [int]$WaitMs = 2500) {
    $out = New-Object System.Collections.Generic.List[object]
    $udp = New-Object System.Net.Sockets.UdpClient
    try {
        $udp.EnableBroadcast = $true
        if ($Hosts) {
            foreach ($h in $Hosts) {
                try { [void]$udp.Send([byte[]](3), 1, $h, 1434) } catch { Write-Host "  $h : $($_.Exception.Message)" -ForegroundColor Yellow }
            }
        } else {
            [void]$udp.Send([byte[]](2), 1, (New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Broadcast), 1434))
        }
        $end = (Get-Date).AddMilliseconds($WaitMs)
        while ((Get-Date) -lt $end) {
            if ($udp.Available -le 0) { Start-Sleep -Milliseconds 50; continue }
            $from = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any), 0
            try { $data = $udp.Receive([ref]$from) } catch { continue }   # e.g. ICMP "port unreachable" from a host without Browser
            if ($data.Length -lt 4 -or $data[0] -ne 5) { continue }
            foreach ($rec in ([System.Text.Encoding]::ASCII.GetString($data, 3, $data.Length - 3) -split ';;')) {
                $kv = @{}; $parts = $rec -split ';'
                for ($i = 0; $i + 1 -lt $parts.Count; $i += 2) { $kv[$parts[$i]] = $parts[$i + 1] }
                if (-not $kv['ServerName']) { continue }
                $name = [string]$kv['ServerName']
                if ($kv['InstanceName'] -and $kv['InstanceName'] -ne 'MSSQLSERVER') { $name += '\' + $kv['InstanceName'] }
                $note = "SQL Browser at $($from.Address)"
                if ($kv['IsClustered'] -eq 'Yes') { $note += ', clustered' }
                $out.Add([pscustomobject]@{ Server = $name; Port = [string]$kv['tcp']; Version = [string]$kv['Version']; Note = $note })
            }
        }
    } finally { $udp.Close() }
    return , $out
}
if ($Scan -or $ScanHost) {
    $found = New-Object System.Collections.Generic.List[object]
    if ($ScanHost) {
        Write-Host "Asking SQL Browser on $($ScanHost -join ', ') ..." -ForegroundColor Cyan
        foreach ($x in (Get-BrowserInstances $ScanHost)) { $found.Add($x) }
    } else {
        Write-Host 'Looking for SQL Server instances on this computer and in the local network (SQL Browser, UDP 1434) ...' -ForegroundColor Cyan
        foreach ($x in (Get-LocalInstances)) { $found.Add($x) }
        foreach ($x in (Get-BrowserInstances $null)) { $found.Add($x) }
    }
    $seenScan = @{}
    $found = @($found | Where-Object { $k = $_.Server.ToUpperInvariant(); if ($seenScan.ContainsKey($k)) { $false } else { $seenScan[$k] = $true; $true } } | Sort-Object Server)
    if ($found.Count -eq 0) {
        Write-Host 'No instances found: SQL Browser not running, UDP 1434 blocked, or the servers are in another subnet (try -ScanHost <names>).' -ForegroundColor Yellow
        if ($Servers.Count -eq 0) { return }
    } else {
        Write-Host ''
        Write-Host ('  {0,3}  {1,-40} {2,6}  {3,-9} {4}' -f 'Nr', 'Instance', 'Port', 'Version', 'Found by')
        for ($i = 0; $i -lt $found.Count; $i++) {
            $x = $found[$i]; $year = ''
            if ($x.Version) { $year = Get-SqlYear $x.Version }
            Write-Host ('  {0,3}  {1,-40} {2,6}  {3,-9} {4}' -f ($i + 1), $x.Server, $x.Port, $year, $x.Note)
        }
        $redirected = $false
        try { $redirected = [Console]::IsInputRedirected } catch { }
        if ($redirected -or -not [Environment]::UserInteractive) { Write-Host 'No interactive console - give the chosen ones with -Servers.'; return }
        $answer = (Read-Host 'Instances to use (e.g. 1,3 or all; Enter = stop)').Trim()
        if (-not $answer) { return }
        $pick = @(if ($answer -match '^(?i)all$') { 0..($found.Count - 1) } else { $answer -split '[,; ]+' | Where-Object { $_ -match '^\d+$' -and [int]$_ -ge 1 -and [int]$_ -le $found.Count } | ForEach-Object { [int]$_ - 1 } })
        if ($pick.Count -eq 0) { Write-Host 'Nothing chosen.'; return }
        # with the port the connection does not need SQL Browser later
        $chosen = @(foreach ($i in $pick) { $x = $found[$i]; if ($x.Port -and $x.Port -ne '1433') { "$($x.Server),$($x.Port)" } else { $x.Server } })
        if ((Read-Host 'Save them to a server list file in this folder for the next time? [y/N]') -match '^(?i)y') {
            $file = Join-Path (Get-Location).Path 'servers.txt'
            if (Test-Path -LiteralPath $file) { $file = Join-Path (Get-Location).Path "servers-$((Get-Date).ToString('yyyyMMdd-HHmm')).txt" }
            Set-Content -LiteralPath $file -Value (@("# found by -Scan $((Get-Date).ToString('yyyy-MM-dd HH:mm'))") + $chosen) -Encoding UTF8
            Write-Host "Saved: $file  (next time: -Servers $(Split-Path $file -Leaf))" -ForegroundColor Green
        }
        $Servers = @($Servers) + $chosen
    }
}

# ---------------------------------------------------------------------------
# 1. Connection test of the start servers
# ---------------------------------------------------------------------------
if ($Servers.Count -eq 1 -and (Test-Path -LiteralPath $Servers[0] -PathType Leaf)) {
    $Servers = @(Get-Content -LiteralPath $Servers[0] |
        ForEach-Object { ($_ -replace '\s+#.*$', '').Trim() } |
        Where-Object { $_ -and $_ -notmatch '^#' })
}
$seen = @{}
$Servers = @(foreach ($s in $Servers) { if (-not $seen.ContainsKey($s.ToUpperInvariant())) { $seen[$s.ToUpperInvariant()] = $true; $s } })
if ($Servers.Count -eq 0) { throw 'No servers given: use -Servers <names or a list file>, -Scan or -ScanHost <hosts>.' }
if (-not $Monitor) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

function Add-TestResult($it, $r, $secs, $live) {
    $tests.Add([pscustomobject]@{ Entry = $it.Target; R = $r; Ms = [int]($secs * 1000) })
}
Write-Host "Testing connections to $($Servers.Count) server(s) as $authText ..." -ForegroundColor Cyan
Invoke-Collect @($Servers | ForEach-Object { @{ Key = $_; Target = $_; Task = @{ Kind = 'test' } } }) 'Add-TestResult' 'Testing connections'

$connRows = New-Object System.Collections.Generic.List[object]
$okStarts = New-Object System.Collections.Generic.List[string]
foreach ($s in $Servers) {
    $t = $tests | Where-Object { $_.Entry -eq $s } | Select-Object -First 1
    if (-not $t) { continue }
    $r = $t.R
    $key = Get-NormName $s
    if ($r.Error) {
        $hint = Get-ConnHint $r $s
        $failed[$key] = $hint; $tried[$key] = $s; $connectName[$key] = $s; $queued[$key] = $true; $visited[$key] = $true
        Write-Host ("  FAIL  {0,-32} {1}" -f $s, $hint) -ForegroundColor Red
        $connRows.Add([pscustomobject]@{ Entry = $s; Status = 'FAIL'; Server = ''; Version = ''; Port = ''; Login = ''; Sysadmin = ''; Note = ''; Ms = $t.Ms; Error = $hint })
        continue
    }
    $real = Get-NormName $r.SrvName
    $lsn = ''; $lsnAg = ''
    foreach ($l in $r.Listeners) {
        $ln = Remove-Port (Get-NormName ([string]$l.dns_name))
        if ($ln -eq (Remove-Port $key)) { $lsn = $ln; $lsnAg = [string]$l.ag_name }
    }
    $note = ''
    if (-not $lsn -and $r.Hadr -and $r.Listeners.Count -eq 0 -and (Remove-Port $key) -ne $real -and (Remove-Port $key) -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -and (Remove-Port $key) -ne '.') {
        $lsn = Remove-Port $key; $lsnAg = '?'
    }
    if ($lsn) {
        if (-not $connectFor.ContainsKey($lsn)) { $connectFor[$lsn] = $s }
        if ($key -ne $lsn) { $aliasMap[$key] = $lsn }
        $note = "AG listener of $lsnAg, primary now $real"
        if ($lsnAg -eq '?') { $note = "probably an AG listener (AG details not visible to this login), primary now $real" }
    } else {
        if (-not $connectFor.ContainsKey($real)) { $connectFor[$real] = $s }
        if ($key -ne $real -and -not $aliasMap.ContainsKey($key)) { $aliasMap[$key] = $real }
        if ($r.DistDbs.Count -gt 0) { $note = "distributor ($($r.DistDbs -join ', '))" }
    }
    $okStarts.Add($s)
    $sa = 'no sysadmin'
    if ($r.Sysadmin) { $sa = 'sysadmin' }
    $portText = ''
    if ($r.Port) { $portText = "port $($r.Port)" } elseif ($r.Transport) { $portText = $r.Transport }
    Write-Host ("  OK    {0,-32} -> {1,-22} {2,-9} {3,-11} {4,-11} {5,5} ms  {6}" -f $s, $real, (Get-SqlYear $r.Version), $portText, $sa, $t.Ms, $note) -ForegroundColor Green
    $connRows.Add([pscustomobject]@{ Entry = $s; Status = 'OK'; Server = $real; Version = $r.Version; Port = $r.Port; Login = $r.Login; Sysadmin = $r.Sysadmin; Note = $note; Ms = $t.Ms; Error = '' })
}
Export-ReportCsv $connRows 'connections.csv'
Write-Host ("Connection test: {0} OK, {1} failed (connections.csv)" -f $okStarts.Count, ($Servers.Count - $okStarts.Count)) -ForegroundColor Cyan
if ($TestOnly) { return }
if ($okStarts.Count -eq 0) { throw 'None of the servers is reachable - see the connection test above.' }

# ---------------------------------------------------------------------------
# 2. Crawl: each round of servers is queried in parallel
# ---------------------------------------------------------------------------
function Add-Server([string]$Name) {
    $raw = Get-NormName $Name
    if (-not $raw -or $raw -like '*_ID=*') { return }
    $n = Resolve-Name $raw
    if ($queued.ContainsKey($n)) { return }
    $queued[$n] = $true
    if ($connectFor.ContainsKey($n)) { $connectName[$n] = $connectFor[$n] } else { $connectName[$n] = $Name.Trim() }
    $queue.Enqueue($n)
}
function Get-CrawlName([string]$Raw, [string]$Db) {
    $i = Resolve-Name (Get-NormName $Raw)
    if (-not $i -or $i -like '*_ID=*') { return $Raw }
    return (Get-Canon $i $Db)
}

function Merge-Result($it, $r, $secs, $live) {
    $n = $it.Key
    if ($live) { Write-Host ("    done in {0:N1} s" -f $secs) -ForegroundColor DarkGray }
    else { Write-Host ("[*] {0} ({1:N1} s)" -f $it.Target, $secs) -ForegroundColor Cyan }
    Write-ServerLog $r.Log
    foreach ($c in $r.Coverage) { [void]$coverage.Add($c) }
    if ($r.Error) {
        $failed[$n] = Get-ConnHint $r $it.Target
        $tried[$n] = $it.Target
        Write-Warning "  Cannot connect to $($it.Target): $($failed[$n])"
        return
    }
    $real = Resolve-Name (Get-NormName $r.SrvName)
    if (-not $real) { $real = $n }
    Add-AgInfo $r
    $tk = Remove-Port (Get-NormName $it.Target)
    $lsn = ''
    if ($agByListener.ContainsKey($tk)) { $lsn = $tk } elseif ($agByListener.ContainsKey((Remove-Port $n))) { $lsn = Remove-Port $n }
    elseif ($r.Hadr -and $r.AgRows.Count -eq 0 -and $tk -ne $real -and $tk -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -and $tk -ne '.') {
        $lsn = Add-GuessedListener $tk $real
    }
    if ($lsn) {
        # Reached through an AG listener: the listener stays the name of the AG databases
        $listenerInst[$lsn] = $real
        if ($n -ne $lsn -and -not $aliasMap.ContainsKey($n)) { $aliasMap[$n] = $lsn }
        $visited[$lsn] = $true; $queued[$lsn] = $true
        if (-not $connectFor.ContainsKey($lsn)) { $connectFor[$lsn] = $it.Target }
    } else {
        # A different name for the same server (IP, DNS alias, port)
        if ($real -ne $n -and (Get-NormName $it.Target) -eq $n -and -not $aliasMap.ContainsKey($n)) { $aliasMap[$n] = $real }
        if (-not $connectFor.ContainsKey($real)) { $connectFor[$real] = $it.Target }
    }
    $visited[$real] = $true; $queued[$real] = $true
    if ($serverInfo.ContainsKey($real)) {
        Write-Host "    same server as $real - skipped" -ForegroundColor DarkGray
        return
    }
    $dbIdx = @{}
    foreach ($d in $r.Dbs) { $dbIdx[([string]$d.name).ToUpperInvariant()] = $d }
    $info = [pscustomobject]@{
        Server = $real; ConnectedAs = $it.Target; Version = $r.Version; Edition = $r.Edition; Login = $r.Login; Sysadmin = $r.Sysadmin
        Port = $r.Port; Transport = $r.Transport; AgentService = $r.AgentService; ViewServerState = $r.ViewServerState; Hadr = $r.Hadr
        DistributionDbs = ($r.DistDbs -join ', '); RemoteDistributor = ''; AgRole = ''; Aliases = ''
        Publications = 0; Error = ($r.DbErrors -join ' '); Support = ''; UpgradeLimit = ''
        Dbs = $dbIdx; Jobs = $r.Jobs; Profiles = $r.Profiles; Retention = $r.Retention; DistHealth = $r.DistHealth
        DistPubs = $r.DistPubs; DistPubsOk = $r.DistPubsOk
    }
    $serverInfo[$real] = $info
    if ($r.RemoteDistributor -and (Resolve-Name (Get-NormName $r.RemoteDistributor)) -ne $real) {
        $info.RemoteDistributor = $r.RemoteDistributor
        Add-Server $r.RemoteDistributor
    }
    foreach ($x in $r.Redirected) {
        $orig = Get-NormName $x.Original; $ln = Get-NormName $x.Listener
        if (-not $orig -or -not $ln) { continue }
        $l = Remove-Port $ln
        $redirect["$orig|$($x.Db.ToUpperInvariant())"] = $l
        if ($ln -ne $l) { $aliasMap[$ln] = $l }
        if (-not $NoCrawl) { Add-Server $l }
    }
    foreach ($d in $r.DistOk) { $readOk["$real|$d".ToUpperInvariant()] = $true }
    foreach ($a in $r.Agents) { $a | Add-Member -NotePropertyName DistInst -NotePropertyValue $real; $agents.Add($a) }
    foreach ($p in $r.Pubs) { $p | Add-Member -NotePropertyName DistInst -NotePropertyValue $real; $pubs.Add($p) }
    foreach ($e in $r.Edges) {
        $e.Distributor = $real
        $edges.Add($e)
        if (-not $NoCrawl) {
            Add-Server (Get-CrawlName $e.PubServerRaw $e.PubDb)
            if ($e.SubServerRaw) { Add-Server (Get-CrawlName $e.SubServerRaw $e.SubDb) }
        }
    }
    foreach ($a in $r.Articles) { $articles.Add($a) }
}

foreach ($s in $okStarts) { Add-Server $s }

while ($true) {
    # A failed server is tried once more when a working connection string was learned meanwhile
    foreach ($f in @($failed.Keys)) {
        if ($connectFor.ContainsKey($f) -and $tried.ContainsKey($f) -and $connectFor[$f] -ne $tried[$f] -and -not $retried.ContainsKey($f)) {
            $retried[$f] = $true
            $failed.Remove($f); $visited.Remove($f); $queued.Remove($f)
            Add-Server $f
        }
    }
    if ($queue.Count -eq 0) { break }
    $wave = New-Object System.Collections.Generic.List[string]
    while ($queue.Count -gt 0) {
        $n = $queue.Dequeue()
        if ($visited.ContainsKey($n) -or $visited.ContainsKey((Resolve-Name $n))) { continue }
        if ($serverInfo.Count + $failed.Count + $wave.Count -ge $MaxServers) {
            Write-Warning "Reached -MaxServers limit ($MaxServers). Remaining servers skipped."
            $queue.Clear(); break
        }
        $visited[$n] = $true
        if ($connectFor.ContainsKey($n)) { $connectName[$n] = $connectFor[$n] }
        $wave.Add($n)
    }
    if ($wave.Count -eq 0) { continue }
    if ($wave.Count -gt 1 -and $ThrottleLimit -gt 1) {
        Write-Host "Querying $($wave.Count) servers in parallel (up to $ThrottleLimit at a time)..." -ForegroundColor DarkGray
    }
    Invoke-Collect @($wave | ForEach-Object { @{ Key = $_; Target = $connectName[$_]; Task = @{ Kind = 'server' } } }) 'Merge-Result' 'Querying servers'
}

# ---------------------------------------------------------------------------
# 3. Names (AG listeners), articles, agents and jobs
# ---------------------------------------------------------------------------
foreach ($e in $edges) {
    $pi = Resolve-Name (Get-NormName $e.PubServerRaw)
    $si = $null
    if ($e.SubServerRaw) { $si = Resolve-Name (Get-NormName $e.SubServerRaw) }
    $di = Resolve-Name $e.Distributor
    $sub = $null
    if ($si) { $sub = Get-Canon $si $e.SubDb }
    $e | Add-Member -NotePropertyName PubInstance -NotePropertyValue $pi
    $e | Add-Member -NotePropertyName SubInstance -NotePropertyValue $si
    $e | Add-Member -NotePropertyName DistributorInstance -NotePropertyValue $di
    $e | Add-Member -NotePropertyName PubServer -NotePropertyValue (Get-Canon $pi $e.PubDb)
    $e | Add-Member -NotePropertyName SubServer -NotePropertyValue $sub
    $e.Distributor = Get-Canon $di $e.DistributionDb
    $e | Add-Member -NotePropertyName Key -NotePropertyValue ("$($e.PubServer)|$($e.PubDb)|$($e.Publication)|$sub|$($e.SubDb)").ToUpperInvariant()
    $e | Add-Member -NotePropertyName PubKey -NotePropertyValue ("$($e.PubServer)|$($e.PubDb)|$($e.Publication)").ToUpperInvariant()
    foreach ($p in 'ArticleNames', 'Change', 'ChangeText', 'Job', 'JobKey', 'SkipErrors', 'RowDiff') { $e | Add-Member -NotePropertyName $p -NotePropertyValue '' }
    $e | Add-Member -NotePropertyName JobContinuous -NotePropertyValue $false
    foreach ($p in 'Tables', 'Fails', 'Retries') { $e | Add-Member -NotePropertyName $p -NotePropertyValue $null }
}
# The same subscription read twice (e.g. two names of one distributor) is kept once
$seenKeys = @{}
$unique = @(foreach ($e in $edges) { if (-not $seenKeys.ContainsKey($e.Key)) { $seenKeys[$e.Key] = $true; $e } })
$edges = New-Object System.Collections.Generic.List[object]
foreach ($e in $unique) { $edges.Add($e) }

$artByPub = @{}
$artSeen = New-Object 'System.Collections.Generic.HashSet[string]'
$articles = @(foreach ($a in $articles) {
    $pubServer = Get-Canon (Resolve-Name (Get-NormName $a.PubServerRaw)) $a.PubDb
    $pk = ("$pubServer|$($a.PubDb)|$($a.Publication)").ToUpperInvariant()
    if (-not $artSeen.Add("$pk|$($a.Article)".ToUpperInvariant())) { continue }
    $obj = [pscustomobject]@{ PubKey = $pk; PubServer = $pubServer; PubDb = $a.PubDb; Publication = $a.Publication
                              Article = $a.Article; Source = $a.Source; Destination = $a.Destination; Change = '' }
    if (-not $artByPub.ContainsKey($pk)) { $artByPub[$pk] = New-Object System.Collections.Generic.List[object] }
    $artByPub[$pk].Add($obj)
    $obj
})
foreach ($e in $edges) {
    if ($artByPub.ContainsKey($e.PubKey)) {
        $e.Tables = $artByPub[$e.PubKey].Count
        $e.ArticleNames = (@($artByPub[$e.PubKey] | ForEach-Object { "$($_.Article) $($_.Source) $($_.Destination)" }) -join ' ')
    }
}

foreach ($srv in @($serverInfo.Keys)) {
    $roles = @(foreach ($ag in $ags.Values) { if ($ag.Replicas.Contains($srv)) { $role = $ag.Replicas[$srv]; if (-not $role) { $role = 'replica' }; "$($ag.Name) $role" } })
    $serverInfo[$srv].AgRole = ($roles -join ', ')
    $serverInfo[$srv].Aliases = (@($aliasMap.Keys | Where-Object { (Resolve-Name $_) -eq $srv } | Sort-Object) -join ', ')
}
foreach ($g in ($edges | Group-Object PubServer)) {
    foreach ($inst in (Get-Instances $g.Name)) {
        if ($serverInfo.ContainsKey($inst)) {
            $serverInfo[$inst].Publications = @($g.Group | Select-Object -ExpandProperty Publication -Unique).Count
        }
    }
}

$agentIdx = @{}; $logReaderIdx = @{}; $jobIdx = @{}; $pullJobIdx = @{}; $profileIdx = @{}; $knownJobs = @{}
foreach ($a in $agents) {
    $agentIdx["$($a.DistInst)|$($a.kind)|$($a.agent_id)"] = $a
    if ($a.kind -eq 'L') { $logReaderIdx["$($a.DistInst)|$(Get-NormName ([string]$a.publisher))|$(([string]$a.publisher_db).ToUpperInvariant())"] = $a }
    if ($a.job_id) { $knownJobs["$($a.DistInst)|$(([string]$a.job_id).ToUpperInvariant())"] = $true }
}
foreach ($srv in @($serverInfo.Keys)) {
    $info = $serverInfo[$srv]
    foreach ($j in $info.Jobs) {
        $ja = Get-AgentArgs ([string]$j.command)
        $j | Add-Member -NotePropertyName Args -NotePropertyValue $ja
        $j | Add-Member -NotePropertyName Server -NotePropertyValue $srv
        $j | Add-Member -NotePropertyName Continuous -NotePropertyValue ($ja.ContainsKey('CONTINUOUS'))
        $skip = ''
        if ($ja.ContainsKey('SKIPERRORS')) { $skip = $ja['SKIPERRORS'] }
        $j | Add-Member -NotePropertyName SkipErrors -NotePropertyValue $skip
        $enc = ''
        if ($ja.ContainsKey('ENCRYPTIONLEVEL')) { $enc = $ja['ENCRYPTIONLEVEL'] }
        $j | Add-Member -NotePropertyName EncLevel -NotePropertyValue $enc
        $jobIdx["$srv|$(([string]$j.job_id).ToUpperInvariant())"] = $j
        if ($j.category -eq 'REPL-Distribution' -and $ja.ContainsKey('PUBLICATION') -and $ja.ContainsKey('SUBSCRIBERDB') -and $ja.ContainsKey('PUBLISHER') -and $ja.ContainsKey('PUBLISHERDB')) {
            $pullJobIdx[("$srv|$(Get-NormName $ja['PUBLISHER'])|$($ja['PUBLISHERDB'])|$($ja['PUBLICATION'])|$($ja['SUBSCRIBERDB'])").ToUpperInvariant()] = $j
        }
    }
    foreach ($p in $info.Profiles) {
        $k = "$srv|$($p.profile_id)"
        if (-not $profileIdx.ContainsKey($k)) { $profileIdx[$k] = @{ Name = [string]$p.profile_name; SkipErrors = ''; EncLevel = '' } }
        if ([string]$p.parameter_name -match '(?i)SkipErrors') { $profileIdx[$k].SkipErrors = [string]$p.value }
        if ([string]$p.parameter_name -match '(?i)EncryptionLevel') { $profileIdx[$k].EncLevel = [string]$p.value }
    }
}

# ---------------------------------------------------------------------------
# 4. Health beyond Replication Monitor: jobs, SQL Server Agent, Log Reader, logs, databases
# ---------------------------------------------------------------------------
function Add-Problem($e, [string]$Level, [string]$Text) {
    if ($levelRank[$Level] -gt $levelRank[[string]$e.Health]) { $e.Health = $Level }
    $parts = @(([string]$e.Problem) -split ', ' | Where-Object { $_ })
    if ($parts -notcontains $Text) { $e.Problem = (@($parts) + $Text) -join ', ' }
}
function Get-JobState($Job, [string]$HomeServer) {
    $s = @()
    if ($Job.Continuous) { $s += 'continuous' } else { $s += 'scheduled' }
    if (-not $Job.enabled) { $s += 'DISABLED' } elseif ($Job.running) { $s += 'running' } else { $s += 'not running' }
    if ($Job.Server -ne $HomeServer) { $s += "on $($Job.Server)" }
    return ($s -join ', ')
}
$runText = @{ 1 = 'Started'; 2 = 'Succeeded'; 3 = 'In progress'; 4 = 'Idle'; 5 = 'Retrying'; 6 = 'Failed' }

foreach ($e in $edges) {
    if (-not $e.SubServer -or $NoHealth) { continue }
    $di = $e.DistributorInstance
    $ag = $null
    if ($e.AgentId) {
        $kind = 'D'
        if ($e.PubType -eq 'Merge') { $kind = 'M' }
        $k = "$di|$kind|$($e.AgentId)"
        if ($agentIdx.ContainsKey($k)) { $ag = $agentIdx[$k] }
    }
    if (-not $ag) {
        $ag = $agents | Where-Object {
            $_.DistInst -eq $di -and $_.kind -eq 'D' -and (Get-NormName ([string]$_.publisher)) -eq (Get-NormName $e.PubServerRaw) -and
            [string]$_.publisher_db -eq $e.PubDb -and ([string]$_.publication -eq $e.Publication -or [string]$_.publication -eq 'ALL') -and
            (Get-NormName ([string]$_.subscriber)) -eq (Get-NormName $e.SubServerRaw) -and [string]$_.subscriber_db -eq $e.SubDb
        } | Select-Object -First 1
    }
    if ($ag) {
        $e.Fails = $ag.fails; $e.Retries = $ag.retries
        $job = $null; $jobSrv = ''
        if ($ag.job_id) {
            $jk = "$di|$(([string]$ag.job_id).ToUpperInvariant())"
            if ($jobIdx.ContainsKey($jk)) { $job = $jobIdx[$jk]; $jobSrv = $di }
        }
        if (-not $job) {
            foreach ($inst in (Get-Instances $e.SubServer)) {
                $pk = ("$inst|$(Get-NormName $e.PubServerRaw)|$($e.PubDb)|$($e.Publication)|$($e.SubDb)").ToUpperInvariant()
                if ($pullJobIdx.ContainsKey($pk)) { $job = $pullJobIdx[$pk]; $jobSrv = $inst; break }
            }
        }
        $prof = $null
        if ($profileIdx.ContainsKey("$di|$($ag.profile_id)")) { $prof = $profileIdx["$di|$($ag.profile_id)"] }
        if ($job) {
            $e.Job = Get-JobState $job $di
            $e.JobKey = "$jobSrv|$(([string]$job.job_id).ToUpperInvariant())"; $e.JobContinuous = [bool]$job.Continuous
            if (-not $job.enabled) {
                $lvl = 'warn'
                if ($job.Continuous) { $lvl = 'error' }
                Add-Problem $e $lvl 'AGENT JOB DISABLED'
            } elseif ($job.Continuous -and -not $job.running) {
                $lvl = 'warn'
                if ($e.Pending -gt 0) { $lvl = 'error' }
                Add-Problem $e $lvl 'AGENT NOT RUNNING'
            }
        } elseif ($e.AgentStatus -eq 'Stopped' -and $e.Pending -gt 0) {
            Add-Problem $e 'warn' "STOPPED, PENDING $($e.Pending)"
        }
        if ($jobSrv -and $serverInfo.ContainsKey($jobSrv) -and $serverInfo[$jobSrv].AgentService -eq 'Stopped') { Add-Problem $e 'error' "SQL AGENT STOPPED ON $jobSrv" }
        $skip = ''
        if ($job -and $job.SkipErrors) { $skip = $job.SkipErrors } elseif ($prof -and $prof.SkipErrors) { $skip = $prof.SkipErrors }
        if ($skip) { $e.SkipErrors = $skip; Add-Problem $e 'warn' "SKIPS ERRORS $skip" }
        if ($ag.fails -gt 0) { Add-Problem $e 'warn' "$($ag.fails) FAILURE$(if ($ag.fails -ne 1) { 'S' }) IN $HistoryHours H" }
        if ($ag.retries -ge 10) { Add-Problem $e 'warn' "$($ag.retries) RETRIES IN $HistoryHours H" }
    }
    if ($e.PubType -eq 'Transactional' -or $e.PubType -eq 'P2P') {
        $lk = "$di|$(Get-NormName $e.PubServerRaw)|$($e.PubDb.ToUpperInvariant())"
        if ($logReaderIdx.ContainsKey($lk)) {
            $lr = $logReaderIdx[$lk]
            $lj = $null
            if ($lr.job_id) { $jk = "$di|$(([string]$lr.job_id).ToUpperInvariant())"; if ($jobIdx.ContainsKey($jk)) { $lj = $jobIdx[$jk] } }
            if ($lr.runstatus -eq 6) { Add-Problem $e 'error' 'LOG READER FAILED' }
            if ($lj) {
                if (-not $lj.enabled) { Add-Problem $e 'error' 'LOG READER JOB DISABLED' }
                elseif ($lj.Continuous -and -not $lj.running) { Add-Problem $e 'error' 'LOG READER NOT RUNNING' }
            }
            if ($lr.fails -gt 0) { Add-Problem $e 'warn' "LOG READER: $($lr.fails) FAILURE$(if ($lr.fails -ne 1) { 'S' }) IN $HistoryHours H" }
        }
    }
    $pinst = Get-PrimaryInstance $e.PubServer
    if ($pinst -and $serverInfo.ContainsKey($pinst) -and $serverInfo[$pinst].Dbs.ContainsKey($e.PubDb.ToUpperInvariant())) {
        $d = $serverInfo[$pinst].Dbs[$e.PubDb.ToUpperInvariant()]
        if ($d.log_reuse_wait_desc -eq 'REPLICATION' -and $null -ne $d.LogUsedPct -and $d.LogUsedPct -ge $LogUsedWarn) {
            $lvl = 'warn'
            if ($d.LogUsedPct -ge 90) { $lvl = 'error' }
            Add-Problem $e $lvl "PUBLISHER LOG $($d.LogUsedPct)% (REPLICATION)"
        }
    }
    $sinst = Get-PrimaryInstance $e.SubServer
    if ($sinst -and $serverInfo.ContainsKey($sinst) -and $serverInfo[$sinst].Dbs.Count -gt 0) {
        $sk = $e.SubDb.ToUpperInvariant()
        if (-not $serverInfo[$sinst].Dbs.ContainsKey($sk)) { Add-Problem $e 'error' 'SUBSCRIBER DB MISSING' }
        elseif ($serverInfo[$sinst].Dbs[$sk].state_desc -ne 'ONLINE') { Add-Problem $e 'warn' "SUBSCRIBER DB $($serverInfo[$sinst].Dbs[$sk].state_desc)" }
    }
}

# Log Reader agents (one per published database)
$logReaderRows = @(@(foreach ($lr in $logReaderIdx.Values) {
    $pub = Get-Canon (Resolve-Name (Get-NormName ([string]$lr.publisher))) ([string]$lr.publisher_db)
    $lj = $null
    if ($lr.job_id) { $jk = "$($lr.DistInst)|$(([string]$lr.job_id).ToUpperInvariant())"; if ($jobIdx.ContainsKey($jk)) { $lj = $jobIdx[$jk] } }
    $state = ''
    if ($lj) { $state = Get-JobState $lj $lr.DistInst }
    $status = ''
    if ($null -ne $lr.runstatus -and $runText.ContainsKey([int]$lr.runstatus)) { $status = $runText[[int]$lr.runstatus] }
    $msg = [string]$lr.comments
    if ($lr.error_text) { $msg = "$msg | $($lr.error_text)" }
    $last = ''
    if ($lr.time -is [datetime]) { $last = $lr.time.ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) }
    $lvl = 'ok'
    if ($lr.runstatus -eq 6 -or ($lj -and (-not $lj.enabled -or ($lj.Continuous -and -not $lj.running)))) { $lvl = 'error' }
    elseif ($lr.fails -gt 0) { $lvl = 'warn' }
    $maxLat = $null
    if ($null -ne $lr.max_latency) { $maxLat = [math]::Round($lr.max_latency / 1000, 1) }
    $jobKey = ''
    if ($lj) { $jobKey = $jk }
    [pscustomobject]@{ Distributor = $lr.DistInst; Publisher = $pub; PubDb = [string]$lr.publisher_db; Status = $status; Health = $lvl; LastRun = $last; JobKey = $jobKey
                       Job = $state; Fails = $lr.fails; Retries = $lr.retries; MaxLatencySec = $maxLat; Message = (($msg -replace '\s+', ' ').Trim()) }
}) | Sort-Object Publisher, PubDb)

# ---------------------------------------------------------------------------
# 5. Row counts publisher vs subscriber (metadata only)
# ---------------------------------------------------------------------------
function Get-TableKey([string]$Name) {
    if (-not $Name) { return '' }
    if (-not $Name.Contains('.')) { $Name = "dbo.$Name" }
    return $Name.ToUpperInvariant()
}
$rowCountRows = New-Object System.Collections.Generic.List[object]
$pubDbInfo = @{}     # "CANON|DB" -> publication/article settings (replicate_ddl, filters)
$pubDbName = @{}     # "CANON|DB" -> @(server, database) as written
$dbCounts = @{}      # "CANON|DB" -> @{ table -> rows } or error text
$filtCounts = @{}    # "CANON|DB" -> @{ "PUB|ART" -> publisher rows through the row filter } (-FilteredRowCounts)
$targetCanon = @{}
function Add-DbResult($it, $r, $secs, $live) {
    $canon = $targetCanon[$it.Target]
    if ($r.Error) { Write-Warning "  Row counts on $($it.Target): $(Get-ConnHint $r $it.Target)"; return }
    foreach ($c in $r.Coverage) { [void]$coverage.Add($c) }
    foreach ($d in $r.DbResults) {
        $k = "$canon|$($d.Db)".ToUpperInvariant()
        if ($d.Error) { $dbCounts[$k] = [string]$d.Error; [void]$coverage.Add("Row counts in $canon/$($d.Db): $($d.Error)") }
        else { $dbCounts[$k] = $d.Counts }
        if ($d.Pub.Count -gt 0) { $pubDbInfo[$k] = $d.Pub; $pubDbName[$k] = @($canon, $d.Db) }
        if ($d.FilteredCounts.Count -gt 0) { $filtCounts[$k] = $d.FilteredCounts }
    }
}
if ($NoRowCounts) {
    # no row counts (also in the monitors), but the publication settings (filters, DDL) are still read
    $need = @{}
    foreach ($e in $edges) {
        if (-not $e.SubServer -or $e.PubType -eq 'Merge') { continue }
        $inst = Get-PrimaryInstance $e.PubServer
        if (-not $inst -or -not $serverInfo.ContainsKey($inst)) { continue }
        $target = Get-Target $e.PubServer
        if (-not $need.ContainsKey($target)) { $need[$target] = @{}; $targetCanon[$target] = $e.PubServer }
        $need[$target][$e.PubDb] = $true
    }
    if ($need.Count -gt 0) {
        Write-Host "Publication settings ($($need.Count) server(s))..." -ForegroundColor DarkGray
        $items = @(foreach ($t in $need.Keys) { @{ Key = $t; Target = $t; Task = @{ Kind = 'dbs'; NoCounts = $true; Dbs = @(foreach ($db in $need[$t].Keys) { @{ Db = $db; Publisher = $true } }) } } })
        Invoke-Collect $items 'Add-DbResult' 'Publication settings'
    }
}
if (-not $NoRowCounts) {
    $need = @{}      # target -> @{ db -> publisher? }
    foreach ($e in $edges) {
        if (-not $e.SubServer -or $e.PubType -eq 'Merge' -or -not $artByPub.ContainsKey($e.PubKey)) { continue }
        foreach ($side in @(@($e.PubServer, $e.PubDb, $true), @($e.SubServer, $e.SubDb, $false))) {
            $canon = $side[0]; $db = $side[1]
            $inst = Get-PrimaryInstance $canon
            if (-not $inst -or -not $serverInfo.ContainsKey($inst)) { continue }
            if ($serverInfo[$inst].Dbs.Count -gt 0 -and -not $serverInfo[$inst].Dbs.ContainsKey($db.ToUpperInvariant())) { continue }
            $target = Get-Target $canon
            if (-not $need.ContainsKey($target)) { $need[$target] = @{}; $targetCanon[$target] = $canon }
            $isPub = [bool]$side[2]
            if ($need[$target].ContainsKey($db)) { $isPub = $isPub -or $need[$target][$db] }
            $need[$target][$db] = $isPub
        }
    }
    if ($need.Count -gt 0) {
        Write-Host "Row counts of replicated tables ($($need.Count) server(s))..." -ForegroundColor DarkGray
        $items = @(foreach ($t in $need.Keys) {
            @{ Key = $t; Target = $t; Task = @{ Kind = 'dbs'; Dbs = @(foreach ($db in $need[$t].Keys) { @{ Db = $db; Publisher = [bool]$need[$t][$db] } }) } }
        })
        Invoke-Collect $items 'Add-DbResult' 'Row counts'
    }
    $filters = @{}
    foreach ($k in $pubDbInfo.Keys) {
        foreach ($p in $pubDbInfo[$k]) { if ($p.article -and $p.filter_clause) { $filters["$k|$($p.publication)|$($p.article)".ToUpperInvariant()] = [string]$p.filter_clause } }
    }
    foreach ($e in $edges) {
        if (-not $e.SubServer -or $e.PubType -eq 'Merge' -or -not $artByPub.ContainsKey($e.PubKey)) { continue }
        $pk = "$($e.PubServer)|$($e.PubDb)".ToUpperInvariant(); $sk = "$($e.SubServer)|$($e.SubDb)".ToUpperInvariant()
        if (-not $dbCounts.ContainsKey($pk) -or -not $dbCounts.ContainsKey($sk)) { continue }
        if ($dbCounts[$pk] -is [string] -or $dbCounts[$sk] -is [string]) { continue }
        $drift = New-Object System.Collections.Generic.List[string]
        foreach ($a in $artByPub[$e.PubKey]) {
            $src = Get-TableKey $a.Source; $dst = Get-TableKey $a.Destination
            $pc = $null; $sc = $null
            if ($dbCounts[$pk].ContainsKey($src)) { $pc = $dbCounts[$pk][$src] }
            if ($dbCounts[$sk].ContainsKey($dst)) { $sc = $dbCounts[$sk][$dst] }
            $filtered = $filters.ContainsKey("$pk|$($e.Publication)|$($a.Article)".ToUpperInvariant())
            $note = @()
            $fk = "$($e.Publication)|$($a.Article)".ToUpperInvariant()
            if ($filtered -and $filtCounts.ContainsKey($pk) -and $filtCounts[$pk].ContainsKey($fk)) {
                $pc = $filtCounts[$pk][$fk]; $filtered = $false; $note += 'publisher rows counted with the row filter'
            }
            $diff = $null
            if ($null -eq $sc) { $note += 'table missing at the subscriber' }
            elseif ($null -ne $pc) { $diff = $sc - $pc }
            if ($filtered) { $note += 'filtered article (difference expected)' }
            if ($e.PubType -eq 'Snapshot') { $note += 'snapshot publication (refreshed on schedule)' }
            if ($e.Pending -gt 0) { $note += "$($e.Pending) commands pending" }
            # ponytail: fixed tolerance (10 rows / 0.1%); make it a parameter if busy tables give false alarms
            $tol = 10
            if ($null -ne $pc) { $tol = [math]::Max(10, [math]::Ceiling($pc * 0.001)) }
            if ($e.StatusText -and $e.StatusText -ne 'Active') { $note += "subscription $($e.StatusText.ToLower()) (not initialized yet)" }
            $bad = (-not $filtered -and $e.PubType -ne 'Snapshot' -and ($e.StatusText -eq 'Active' -or -not $e.StatusText) -and -not ($e.Pending -gt 0) -and (($null -eq $sc) -or ($null -ne $diff -and [math]::Abs($diff) -gt $tol)))
            if ($bad) { $drift.Add("$($a.Destination) (publisher $pc, subscriber $sc)") }
            $rowCountRows.Add([pscustomobject]@{
                Publication = $e.Publication; Article = $a.Article; Publisher = "$($e.PubServer)/$($e.PubDb)"; Source = $a.Source; PublisherRows = $pc
                Subscriber = "$($e.SubServer)/$($e.SubDb)"; Destination = $a.Destination; SubscriberRows = $sc; Difference = $diff
                Flag = $bad; Note = ($note -join '; ')
            })
        }
        if ($drift.Count -gt 0) {
            $e.RowDiff = ($drift -join '; ')
            $plural = ''
            if ($drift.Count -ne 1) { $plural = 's' }
            Add-Problem $e 'warn' "ROW COUNTS DIFFER ($($drift.Count) table$plural)"
        }
    }
}

# Row and column filters of the articles: "CANON|DB|PUBLICATION|ARTICLE" -> filter text and the columns that are not published
$artFilter = @{}
foreach ($k in $pubDbInfo.Keys) {
    foreach ($x in $pubDbInfo[$k]) {
        if (-not $x.article) { continue }
        $rows = [string]$x.filter_clause; $exc = ''
        if ([int]$x.pub_cols -gt 0 -and [int]$x.pub_cols -lt [int]$x.cols) { $exc = [string]$x.excluded_cols }
        if ($rows -or $exc) { $artFilter["$k|$($x.publication)|$($x.article)".ToUpperInvariant()] = [pscustomobject]@{ Article = [string]$x.article; Rows = $rows; Excluded = $exc } }
    }
}
foreach ($a in $articles) {
    $f = $null
    if ($a.PSObject.Properties['PubServer']) { $f = $artFilter["$($a.PubServer)|$($a.PubDb)|$($a.Publication)|$($a.Article)".ToUpperInvariant()] }
    $a | Add-Member -NotePropertyName RowFilter -NotePropertyValue $(if ($f) { $f.Rows } else { '' }) -Force
    $a | Add-Member -NotePropertyName ExcludedColumns -NotePropertyValue $(if ($f) { $f.Excluded } else { '' }) -Force
}
function Get-PubFilters([string]$PubServer, [string]$PubDb, [string]$Publication) {
    $pre = "$PubServer|$PubDb|$Publication|".ToUpperInvariant()
    return @(foreach ($k in $artFilter.Keys) { if ($k.StartsWith($pre)) { [pscustomobject]@{ Article = $artFilter[$k].Article; Rows = $artFilter[$k].Rows; Excluded = $artFilter[$k].Excluded } } })
}

# ---------------------------------------------------------------------------
# 6. Findings
# ---------------------------------------------------------------------------
$liveSubs = @($edges | Where-Object { $_.SubServer })
foreach ($e in ($liveSubs | Where-Object { $_.Health -eq 'error' -or $_.Health -eq 'warn' })) {
    $text = $e.Problem
    if ($e.Message) { $text += " - $($e.Message)" }
    if ($e.RowDiff) { $text += " - $($e.RowDiff)" }
    $fix = ''
    if ($e.Problem -match 'SKIPS ERRORS') { $fix = 'The agent skips data errors, so the subscriber can silently differ. Use the default agent profile and check the data (tablediff / sp_publication_validation).' }
    elseif ($e.Problem -match 'AGENT JOB DISABLED|AGENT NOT RUNNING|SQL AGENT STOPPED') { $fix = 'Enable / start the agent job (Replication Monitor or SQL Server Agent).' }
    elseif ($e.Problem -match 'LOG READER') { $fix = 'Check the Log Reader agent job of the published database; until it runs, the publisher log cannot be truncated.' }
    elseif ($e.Problem -match 'SUBSCRIBER DB MISSING') { $fix = 'Create the subscription database or drop the subscription.' }
    elseif ($e.Problem -match 'ROW COUNTS DIFFER') { $fix = 'Compare the tables (tablediff) or validate the subscription (sp_publication_validation); reinitialize if needed.' }
    Add-Finding $e.Health 'Health' $e.SubServer "$($e.Publication): $($e.PubServer)/$($e.PubDb) -> $($e.SubServer)/$($e.SubDb)" $text $fix
}
foreach ($l in ($logReaderRows | Where-Object { $_.Health -ne 'ok' })) {
    Add-Finding $l.Health 'Health' $l.Distributor "Log Reader $($l.Publisher)/$($l.PubDb)" "$($l.Status); job: $($l.Job); failures in $HistoryHours h: $($l.Fails) - $($l.Message)" 'Check the Log Reader agent job; until it runs, the publisher log cannot be truncated.'
}

# Versions: supported combinations, upgrade limits, end of support
function Get-Versions([string]$Canon) {
    return @(foreach ($i in (Get-Instances $Canon)) { if ($i -and $serverInfo.ContainsKey($i)) { Get-Major $serverInfo[$i].Version } })
}
$seenFind = @{}
foreach ($e in $liveSubs) {
    $pv = Get-Versions $e.PubServer; $dv = Get-Versions $e.Distributor; $sv = Get-Versions $e.SubServer
    foreach ($p in $pv) {
        foreach ($d in $dv) {
            if ($d -lt $p) {
                $t = "Distributor $($e.Distributor) (SQL $($verName[$d])) is older than publisher $($e.PubServer) (SQL $($verName[$p]))"
                if (-not $seenFind.ContainsKey($t)) { $seenFind[$t] = $true; Add-Finding 'error' 'Versions' $e.Distributor $e.PubServer "$t - not supported" 'Upgrade the distributor first (distributor >= publisher).' }
            }
        }
        foreach ($s in $sv) {
            $badSub = ($e.PubType -eq 'Merge' -and $s -gt $p) -or ($e.PubType -ne 'Merge' -and [math]::Abs($s - $p) -gt 2)
            if ($badSub) {
                $t = "Subscriber $($e.SubServer) (SQL $($verName[$s])) and publisher $($e.PubServer) (SQL $($verName[$p])) are not a supported combination for $($e.PubType) replication"
                if (-not $seenFind.ContainsKey($t)) { $seenFind[$t] = $true; Add-Finding 'error' 'Versions' $e.SubServer $e.Publication $t 'Transactional: subscriber within two versions of the publisher. Merge: subscriber not newer than the publisher.' }
            }
        }
    }
}
foreach ($srv in @($serverInfo.Keys)) {
    $info = $serverInfo[$srv]
    $cur = Get-Major $info.Version
    if ($supportEnd.ContainsKey($cur)) {
        $end = $supportEnd[$cur]
        if ($end -lt (Get-Date)) {
            $info.Support = "ended $($end.ToString('yyyy-MM-dd'))"
            Add-Finding 'warn' 'Versions' $srv "SQL $($verName[$cur])" "Out of extended support since $($end.ToString('yyyy-MM-dd'))" 'Plan the upgrade (see the upgrade limit in the Servers table).'
        } else {
            $info.Support = "until $($end.ToString('yyyy-MM-dd'))"
            if (($end - (Get-Date)).TotalDays -lt 365) { Add-Finding 'info' 'Versions' $srv "SQL $($verName[$cur])" "Extended support ends $($end.ToString('yyyy-MM-dd'))" 'Plan the upgrade.' }
        }
    }
    # Highest version this server can go to without breaking its replication partners
    $max = 99; $why = ''
    foreach ($e in $liveSubs) {
        if ((Get-Instances $e.PubServer) -contains $srv) {
            if ((Get-Instances $e.Distributor) -notcontains $srv) {
                foreach ($d in (Get-Versions $e.Distributor)) { if ($d -lt $max) { $max = $d; $why = "distributor $($e.Distributor) is SQL $($verName[$d])" } }
            }
            if ($e.PubType -ne 'Merge') { foreach ($s in (Get-Versions $e.SubServer)) { if ($s + 2 -lt $max) { $max = $s + 2; $why = "subscriber $($e.SubServer) is SQL $($verName[$s])" } } }
        }
        if ((Get-Instances $e.SubServer) -contains $srv) {
            foreach ($p in (Get-Versions $e.PubServer)) {
                $lim = $p + 2
                if ($e.PubType -eq 'Merge') { $lim = $p }
                if ($lim -lt $max) { $max = $lim; $why = "publisher $($e.PubServer) is SQL $($verName[$p])" }
            }
        }
    }
    if ($max -eq 99) { $info.UpgradeLimit = 'no limit from replication' }
    elseif ($max -le $cur) { $info.UpgradeLimit = "stays at SQL $($verName[$cur]) until the partner is upgraded ($why)" }
    elseif ($verName.ContainsKey($max)) { $info.UpgradeLimit = "up to SQL $($verName[$max]) ($why)" }
    else { $info.UpgradeLimit = "any current version ($why)" }
}

# Distribution databases: clean up, retention, master key
$distRows = New-Object System.Collections.Generic.List[object]
$runResult = @{ 0 = 'failed'; 1 = 'succeeded'; 3 = 'canceled' }
foreach ($srv in @($serverInfo.Keys)) {
    $info = $serverInfo[$srv]
    $sqlAuthAgents = @($agents | Where-Object { $_.DistInst -eq $srv -and $_.security_mode -eq 0 })
    foreach ($h in $info.DistHealth) {
        $db = [string]$h.Db
        $ret = $info.Retention | Where-Object { [string]$_.name -eq $db } | Select-Object -First 1
        $cleanup = $info.Jobs | Where-Object { $_.category -eq 'REPL-Distribution Cleanup' -and ([string]$_.name -match [regex]::Escape($db)) } | Select-Object -First 1
        $maxRet = $null; $minRet = $null; $histRet = $null
        if ($ret) { $maxRet = [int]$ret.max_distretention; $minRet = [int]$ret.min_distretention; $histRet = [int]$ret.history_retention }
        elseif ($cleanup -and [string]$cleanup.command -match '@max_distretention\s*=\s*(\d+)') { $maxRet = [int]$Matches[1] }
        $cleanText = ''
        if ($cleanup) {
            $cleanText = 'enabled'
            if (-not $cleanup.enabled) { $cleanText = 'DISABLED' }
            if ($cleanup.last_run -is [datetime]) { $cleanText += ", last run $($cleanup.last_run.ToString('yyyy-MM-dd HH:mm'))" }
            if ($null -ne $cleanup.last_run_status -and $runResult.ContainsKey([int]$cleanup.last_run_status)) { $cleanText += " ($($runResult[[int]$cleanup.last_run_status]))" }
            $cd = @{ Type = 'cleanup-job'; Srv = $srv; JobId = [string]$cleanup.job_id; JobName = [string]$cleanup.name; Enabled = [bool]$cleanup.enabled }
            if (-not $cleanup.enabled) { Add-Finding 'error' 'Distributor' $srv $db 'Distribution clean up job is disabled - the distribution database grows without limit' 'Enable the job "Distribution clean up: <db>".' $cd }
            elseif ($cleanup.last_run_status -eq 0) { Add-Finding 'warn' 'Distributor' $srv $db "Distribution clean up job failed: $(([string]$cleanup.last_message -replace '\s+', ' ').Trim())" 'Check the job history.' $cd }
            elseif ($cleanup.last_run -is [datetime] -and ((Get-Date) - $cleanup.last_run).TotalHours -gt 3) { Add-Finding 'warn' 'Distributor' $srv $db "Distribution clean up job last ran at $($cleanup.last_run.ToString('yyyy-MM-dd HH:mm'))" 'It normally runs every 10 minutes - check SQL Server Agent and the job schedule.' $cd }
        } elseif ($info.Jobs.Count -gt 0) {
            Add-Finding 'warn' 'Distributor' $srv $db 'No Distribution clean up job found' 'Recreate the job (it is created with the distribution database).'
        }
        $oldest = $null
        if ($h.oldest_entry -is [datetime]) {
            $oldest = $h.oldest_entry
            if ($null -ne $maxRet -and ((Get-Date) - $oldest).TotalHours -gt ($maxRet + 6)) {
                Add-Finding 'warn' 'Distributor' $srv $db "Oldest replicated command is from $($oldest.ToString('yyyy-MM-dd HH:mm')) - older than the maximum retention ($maxRet h)" 'The clean up cannot remove it: a subscription is not synchronizing or the clean up fails.'
            }
        }
        if ($h.has_dmk -eq 0 -and (Get-Major $info.Version) -ge 15 -and $sqlAuthAgents.Count -gt 0) {
            Add-Finding 'warn' 'Security' $srv $db "No database master key in the distribution database while $($sqlAuthAgents.Count) agent(s) use SQL logins (replication passwords are stored there)" 'Microsoft recommends (SQL 2022 CU18+, 2019 CU31+): CREATE MASTER KEY in the distribution database, then update the passwords with sp_changelogreader_agent / sp_changesubscriber / sp_changedistpublisher / sp_changepublication_snapshot.'
        }
        $logPct = $null
        if ($info.Dbs.ContainsKey($db.ToUpperInvariant())) { $logPct = $info.Dbs[$db.ToUpperInvariant()].LogUsedPct }
        $oldText = ''
        if ($oldest) { $oldText = $oldest.ToString('yyyy-MM-dd HH:mm') }
        $retText = ''
        if ($null -ne $maxRet) { $retText = "$minRet-$maxRet" }
        $dmkText = 'no'
        if ($h.has_dmk -eq 1) { $dmkText = 'yes' }
        $distRows.Add([pscustomobject]@{ Server = $srv; Database = $db; DataMb = $h.data_mb; LogMb = $h.log_mb; LogUsedPct = $logPct; Commands = $h.commands; Transactions = $h.transactions
                                         OldestCommand = $oldText; RetentionHours = $retText; HistoryHours = $histRet; Cleanup = $cleanText; MasterKey = $dmkText })
    }
}

# Replication with availability groups: every replica of a published AG database has to be a publisher at the
# distributor, and the original publisher has to be redirected to the listener - else a failover stops the Log Reader
$agPubDone = @{}
foreach ($p in $pubs) {
    $orig = Get-NormName ([string]$p.pub_server); $dbU = ([string]$p.pub_db).ToUpperInvariant(); $dist = [string]$p.DistInst
    if (-not $orig -or -not $agByInstDb.ContainsKey("$orig|$dbU") -or $agPubDone.ContainsKey("$dist|$orig|$dbU")) { continue }
    $agPubDone["$dist|$orig|$dbU"] = $true
    $ag = $ags[$agByInstDb["$orig|$dbU"]]; $obj = "$($p.pub_db) (AG $($ag.Name))"
    if ($serverInfo.ContainsKey($dist) -and $serverInfo[$dist].DistPubsOk) {
        $known = @{}
        foreach ($x in $serverInfo[$dist].DistPubs) { $n = Get-NormName ([string]$x.name); if ($n) { $known[$n] = $true } }
        $missing = @($ag.Replicas.Keys | Where-Object { -not $known.ContainsKey($_) })
        $workDir = ''
        foreach ($x in $serverInfo[$dist].DistPubs) { if ((Get-NormName ([string]$x.name)) -eq $orig) { $workDir = [string]$x.working_directory } }
        $subsOf = @($edges | Where-Object { $_.SubServerRaw -and (Get-NormName ([string]$_.PubServerRaw)) -eq $orig -and ([string]$_.PubDb).ToUpperInvariant() -eq $dbU } | ForEach-Object { [string]$_.SubServerRaw } | Select-Object -Unique)
        $agData = @{ Type = 'ag-register'; Dist = $dist; DistDb = [string]$p.DistDb; Replicas = $missing; WorkDir = $workDir; Subscribers = $subsOf }
        if ($missing.Count) {
            Add-Finding 'warn' 'Distributor' $dist $obj "AG replica(s) $($missing -join ', ') not registered as publisher at this distributor - after a failover to them the Log Reader stops (`"... is not known as a publisher at distributor ...`")" "At $dist : EXEC sp_adddistpublisher @publisher = N'<replica>', @distribution_db = N'$($p.DistDb)', @working_directory = N'<snapshot folder>'; on each of these replicas: EXEC sp_adddistributor @distributor = N'$dist', @password = N'<distributor_admin password>'" $agData
        }
    }
    if ($ag.Listeners.Count -gt 0 -and -not $redirect.ContainsKey("$orig|$dbU")) {
        Add-Finding 'warn' 'Distributor' $dist $obj "Publisher $orig is not redirected to the AG listener - after a failover the agents keep connecting to $orig" "At $dist : USE [$($p.DistDb)]; EXEC sp_redirect_publisher @original_publisher = N'$orig', @publisher_db = N'$($p.pub_db)', @redirected_publisher = N'$($ag.Listeners[0])'" @{ Type = 'ag-redirect'; Dist = $dist; DistDb = [string]$p.DistDb; Orig = $orig; Db = [string]$p.pub_db; Listener = $ag.Listeners[0] }
    }
}

# Publication settings
foreach ($g in ($pubs | Group-Object DistInst)) {
    $immediate = @($g.Group | Where-Object { $_.publication_type -eq 0 -and $_.immediate_sync -eq 1 } | ForEach-Object { $_.publication })
    if ($immediate) {
        Add-Finding 'info' 'Settings' $g.Name "$($immediate.Count) publication(s)" "immediate_sync = 1 keeps the snapshot commands for the whole retention period (larger distribution database): $($immediate -join ', ')" "If new subscriptions are rare, in the publication database: EXEC sp_changepublication @publication = N'<name>', @property = N'allow_anonymous', @value = 'false'; then the same with @property = N'immediate_sync'."
    }
    $shared = @($g.Group | Where-Object { $_.publication_type -eq 0 -and $_.independent_agent -eq 0 } | ForEach-Object { $_.publication })
    if ($shared) { Add-Finding 'info' 'Settings' $g.Name "$($shared.Count) publication(s)" "Shared Distribution Agent (independent_agent = 0): $($shared -join ', ')" 'One slow subscription delays the others; independent agents are the default since SQL 2005.' }
    $never = @($g.Group | Where-Object { $_.retention -eq 0 } | ForEach-Object { $_.publication })
    if ($never) { Add-Finding 'info' 'Settings' $g.Name "$($never.Count) publication(s)" "Subscriptions never expire (retention = 0): $($never -join ', ')" 'An abandoned subscription keeps commands in the distribution database forever.' }
}
foreach ($k in $pubDbInfo.Keys) {
    $noDdl = @($pubDbInfo[$k] | Where-Object { $_.publication -and $_.replicate_ddl -eq 0 } | ForEach-Object { [string]$_.publication } | Select-Object -Unique)
    if ($noDdl) { Add-Finding 'warn' 'Settings' $pubDbName[$k][0] $pubDbName[$k][1] "Schema changes (ALTER TABLE) are not replicated (replicate_ddl = 0): $($noDdl -join ', ')" "Column changes must be applied on the subscribers by hand, or: EXEC sp_changepublication @publication = N'<name>', @property = N'replicate_ddl', @value = 1." }
}

# Security
foreach ($g in ($agents | Where-Object { $_.security_mode -eq 0 } | Group-Object DistInst)) {
    $sa = @($g.Group | Where-Object { [string]$_.login_name -eq 'sa' })
    $logins = @($g.Group | ForEach-Object { [string]$_.login_name } | Where-Object { $_ } | Select-Object -Unique)
    if ($sa) { Add-Finding 'warn' 'Security' $g.Name "$($sa.Count) agent(s)" "Agents connect as 'sa': $((@($sa | ForEach-Object { $_.name }) | Select-Object -First 5) -join ', ')" 'Use Windows authentication or a dedicated login with only the permissions replication needs.' }
    elseif ($logins) { Add-Finding 'info' 'Security' $g.Name "$($g.Count) agent(s)" "Agents connect with SQL logins: $($logins -join ', ')" 'Microsoft recommends Windows authentication and a separate account per agent.' }
}
foreach ($srv in @($serverInfo.Keys)) {
    $jobs = @($serverInfo[$srv].Jobs | Where-Object { $_ })
    foreach ($j in ($jobs | Where-Object { -not $_.owner_name })) {
        Add-Finding 'error' 'Security' $srv $j.name 'Job owner login no longer exists - the job will fail' "EXEC msdb.dbo.sp_update_job @job_name = N'$($j.name)', @owner_login_name = N'sa';"
    }
    $agentJobs = @($jobs | Where-Object { $_.category -in 'REPL-Distribution', 'REPL-LogReader', 'REPL-Snapshot', 'REPL-Merge' })
    $noProxy = @($agentJobs | Where-Object { $null -eq $_.proxy_id })
    if ($noProxy) { Add-Finding 'info' 'Security' $srv "$($noProxy.Count) agent job(s)" 'Agents run under the SQL Server Agent service account (no proxy)' 'Microsoft recommends a separate Windows account per agent (job_login when creating the agent).' }
}

# Leftovers: replication flags without publications, jobs without agents
$pubDbs = @{}
foreach ($e in $edges) { $pubDbs["$($e.PubServer)|$($e.PubDb)".ToUpperInvariant()] = $true }
foreach ($srv in @($serverInfo.Keys)) {
    $info = $serverInfo[$srv]
    $distInst = $srv
    if (-not $info.DistributionDbs -and $info.RemoteDistributor) { $distInst = Resolve-Name (Get-NormName $info.RemoteDistributor) }
    $distRead = @($readOk.Keys | Where-Object { $_ -like "$distInst|*" }).Count -gt 0
    foreach ($d in $info.Dbs.Values) {
        if (($d.is_published -eq 1 -or $d.is_merge_published -eq 1) -and $d.is_distributor -ne 1 -and $distRead) {
            $canon = Get-Canon $srv ([string]$d.name)
            if (-not $pubDbs.ContainsKey("$canon|$($d.name)".ToUpperInvariant())) {
                Add-Finding 'warn' 'Leftovers' $srv $d.name 'Database is marked as published but has no publication (leftover of an old replication?)' "If nothing is published: EXEC sp_replicationdboption @dbname = N'$($d.name)', @optname = N'publish', @value = N'false';  (or sp_removedbreplication)"
            }
        }
    }
    if ($info.Error) { continue }
    foreach ($j in ($info.Jobs | Where-Object { $_.category -in 'REPL-Distribution', 'REPL-LogReader', 'REPL-Snapshot' })) {
        if ($knownJobs.ContainsKey("$srv|$(([string]$j.job_id).ToUpperInvariant())")) { continue }
        $ja = $j.Args
        if ($j.category -eq 'REPL-Distribution' -and $ja.ContainsKey('PUBLICATION') -and $ja.ContainsKey('SUBSCRIBERDB') -and $ja.ContainsKey('PUBLISHER')) {
            $match = $liveSubs | Where-Object {
                $_.Publication -eq $ja['PUBLICATION'] -and $_.SubDb -eq $ja['SUBSCRIBERDB'] -and (Get-NormName $_.PubServerRaw) -eq (Get-NormName $ja['PUBLISHER']) -and (Get-Instances $_.SubServer) -contains $srv
            } | Select-Object -First 1
            if ($match) { continue }
            if ($ja.ContainsKey('DISTRIBUTOR')) {
                $jd = Resolve-Name (Get-NormName $ja['DISTRIBUTOR'])
                if (@($readOk.Keys | Where-Object { $_ -like "$jd|*" }).Count -eq 0) { continue }
            }
        }
        Add-Finding 'warn' 'Leftovers' $srv $j.name "Replication job ($($j.category)) without a matching agent or subscription" 'If the subscription is gone, delete the job.'
    }
}
foreach ($srv in @($serverInfo.Keys)) {
    if ($serverInfo[$srv].Error) {
        Add-Finding 'error' 'Coverage' $srv 'distribution database' "Cannot read: $($serverInfo[$srv].Error)" 'The login needs db_datareader and replmonitor in the distribution database (or sysadmin) - the replmonitor role alone cannot read the MS* tables.'
    }
}
foreach ($c in ($coverage | Sort-Object)) { Add-Finding 'info' 'Coverage' '' '' "Not checked: $c" 'Run with sysadmin rights (or grant the missing permission) to see this part.' }

# ---------------------------------------------------------------------------
# 7. Table lineage through republishing
# ---------------------------------------------------------------------------
$tblNext = @{}; $tblIn = @{}; $tblShow = @{}
foreach ($e in $liveSubs) {
    if (-not $artByPub.ContainsKey($e.PubKey)) { continue }
    foreach ($a in $artByPub[$e.PubKey]) {
        $from = "$($e.PubServer)|$($e.PubDb)|$(Get-TableKey $a.Source)".ToUpperInvariant()
        $to = "$($e.SubServer)|$($e.SubDb)|$(Get-TableKey $a.Destination)".ToUpperInvariant()
        $tblShow[$from] = "$($e.PubServer)/$($e.PubDb) $($a.Source)"
        if (-not $tblShow.ContainsKey($to)) { $tblShow[$to] = "$($e.SubServer)/$($e.SubDb) $($a.Destination)" }
        if (-not $tblNext.ContainsKey($from)) { $tblNext[$from] = New-Object System.Collections.Generic.List[object] }
        $tblNext[$from].Add(@($to, $e.Publication))
        $tblIn[$to] = $true
    }
}
$lineage = New-Object System.Collections.Generic.List[object]
function Add-Lineage([string]$Root, [string]$Node, [string]$Path, [int]$Hops, $Seen) {
    if ($lineage.Count -ge 2000) { return }
    $next = @()
    if ($tblNext.ContainsKey($Node)) { $next = @($tblNext[$Node] | Where-Object { -not $Seen.ContainsKey($_[0]) }) }
    if ($next.Count -eq 0) {
        if ($Hops -ge 2) { $lineage.Add([pscustomobject]@{ Table = $tblShow[$Root]; Hops = $Hops; Path = $Path }) }
        return
    }
    foreach ($x in $next) {
        $s2 = $Seen.Clone(); $s2[$x[0]] = $true
        Add-Lineage $Root $x[0] "$Path -> [$($x[1])] -> $($tblShow[$x[0]])" ($Hops + 1) $s2
    }
}
foreach ($root in @($tblNext.Keys | Where-Object { -not $tblIn.ContainsKey($_) })) {
    Add-Lineage $root $root $tblShow[$root] 0 @{ $root = $true }
}

# ---------------------------------------------------------------------------
# 8. Comparison with a previous run
# ---------------------------------------------------------------------------
$generated = Get-Date
$changes = New-Object System.Collections.Generic.List[object]
$prevGenerated = ''
if ($CompareTo) {
    $prevPath = $CompareTo
    if (Test-Path -LiteralPath $prevPath -PathType Container) { $prevPath = Join-Path $prevPath 'topology.json' }
    if (-not (Test-Path -LiteralPath $prevPath -PathType Leaf)) { throw "-CompareTo: $prevPath not found." }
    $prev = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $prevPath).ProviderPath) | ConvertFrom-Json
    $prevGenerated = [string](Get-Prop $prev 'generated')
    $prevVersion = [string](Get-Prop $prev 'version')
    if ($prevVersion -and [version]$prevVersion -lt [version]'1.3') {
        Write-Warning "The previous run was made by version $prevVersion - AG databases now appear under the listener, so some names may differ once."
    }
    $prevEdges = @{}
    foreach ($p in @(Get-Prop $prev 'edges')) { if ($p) { $prevEdges[[string]$p.Key] = $p } }
    # Publications are compared by name, subscriptions by publication + subscriber database
    $prevPubs = @{}
    foreach ($p in $prevEdges.Values) { $prevPubs[[string]$p.PubKey] = $p }
    $curPubs = @{}
    foreach ($e in $edges) { $curPubs[$e.PubKey] = $true }
    $curKeys = @{}
    $pubAdded = @{}
    foreach ($e in @($edges.ToArray())) {
        $curKeys[$e.Key] = $true
        if (-not $prevPubs.ContainsKey($e.PubKey) -and -not $pubAdded.ContainsKey($e.PubKey)) {
            $pubAdded[$e.PubKey] = $true
            $changes.Add([pscustomobject]@{ Change = 'Added'; Item = "Publication $($e.Publication): $($e.PubServer)/$($e.PubDb)"; Detail = $e.PubType })
        }
        if (-not $e.SubServer) {
            if ($pubAdded.ContainsKey($e.PubKey)) { $e.Change = 'new'; $e.ChangeText = 'New' }
            continue
        }
        if (-not $prevEdges.ContainsKey($e.Key)) {
            $e.Change = 'new'; $e.ChangeText = 'New'
            $changes.Add([pscustomobject]@{ Change = 'Added'; Item = "Subscription $($e.Publication): $($e.PubServer)/$($e.PubDb) -> $($e.SubServer)/$($e.SubDb)"; Detail = "$($e.PubType) · $($e.SubType)" })
            continue
        }
        $p = $prevEdges[$e.Key]
        $diff = @()
        foreach ($f in 'StatusText', 'Health') {
            $old = [string](Get-Prop $p $f); $new = [string]$e.$f
            if ($old -ne $new -and ($old -or $new)) { $diff += "$f $(if ($old) { $old } else { '-' }) -> $(if ($new) { $new } else { '-' })" }
        }
        if ($diff) {
            $e.Change = 'changed'; $e.ChangeText = $diff -join '; '
            $changes.Add([pscustomobject]@{ Change = 'Changed'; Item = "Subscription $($e.Publication): $($e.PubServer)/$($e.PubDb) -> $($e.SubServer)/$($e.SubDb)"; Detail = $e.ChangeText })
        }
    }
    # Only what a distributor read in this run can be reported as removed
    $notChecked = @{}
    $pubRemoved = @{}
    foreach ($k in $prevEdges.Keys) {
        if ($curKeys.ContainsKey($k)) { continue }
        $p = $prevEdges[$k]
        $pdi = [string](Get-Prop $p 'DistributorInstance')
        if (-not $pdi) { $pdi = [string](Get-Prop $p 'Distributor') }
        $pdi = Resolve-Name (Get-NormName $pdi)
        $pdd = [string](Get-Prop $p 'DistributionDb')
        if (-not $readOk.ContainsKey("$pdi|$pdd".ToUpperInvariant())) {
            if (-not $notChecked.ContainsKey($pdi)) { $notChecked[$pdi] = 0 }
            $notChecked[$pdi]++
            continue
        }
        $pk = [string](Get-Prop $p 'PubKey')
        if (-not $curPubs.ContainsKey($pk) -and -not $pubRemoved.ContainsKey($pk)) {
            $pubRemoved[$pk] = $true
            $changes.Add([pscustomobject]@{ Change = 'Removed'; Item = "Publication $($p.Publication): $($p.PubServer)/$($p.PubDb)"; Detail = [string](Get-Prop $p 'PubType') })
        }
        $sub = [string](Get-Prop $p 'SubServer')
        if (-not $sub) { continue }
        $old = [pscustomobject]@{
            Distributor = [string](Get-Prop $p 'Distributor'); DistributionDb = $pdd; DistributorInstance = $pdi
            PubServerRaw = ''; PubDb = [string]$p.PubDb; Publication = [string]$p.Publication; PubType = [string](Get-Prop $p 'PubType')
            SubServerRaw = ''; SubDb = [string](Get-Prop $p 'SubDb'); SubType = [string](Get-Prop $p 'SubType')
            Status = $null; StatusText = ''; Inactive = $false; AgentId = ''; Health = 'removed'; AgentStatus = ''; Latency = $null; LastSync = ''
            Pending = $null; Problem = ''; Message = ''; PubInstance = ''; SubInstance = ''; PubServer = [string]$p.PubServer; SubServer = $sub
            Key = $k; PubKey = $pk; ArticleNames = ''; Change = 'removed'; ChangeText = 'Removed'; Job = ''; SkipErrors = ''; RowDiff = ''
            Tables = $null; Fails = $null; Retries = $null
        }
        $edges.Add($old)
        $changes.Add([pscustomobject]@{ Change = 'Removed'; Item = "Subscription $($old.Publication): $($old.PubServer)/$($old.PubDb) -> $sub/$($old.SubDb)"; Detail = "$($old.PubType) · $($old.SubType)" })
    }
    foreach ($d in $notChecked.Keys) {
        $changes.Add([pscustomobject]@{ Change = 'Not checked'; Item = "Distributor $d"; Detail = "$($notChecked[$d]) relation(s) from the previous run were not read now (distributor unreachable or not visited) - not reported as removed" })
    }
    $prevArt = @{}
    foreach ($a in @(Get-Prop $prev 'articles')) { if ($a) { $prevArt["$($a.PubKey)|$($a.Article)".ToUpperInvariant()] = $a } }
    $curArt = @{}
    $pubsInPrev = @{}
    foreach ($a in $prevArt.Values) { $pubsInPrev[[string]$a.PubKey] = $true }
    foreach ($a in $articles) {
        $k = "$($a.PubKey)|$($a.Article)".ToUpperInvariant()
        $curArt[$k] = $true
        # Articles of a brand new publication are not listed one by one
        if (-not $prevArt.ContainsKey($k) -and $pubsInPrev.ContainsKey($a.PubKey)) {
            $a.Change = 'new'
            $changes.Add([pscustomobject]@{ Change = 'Article added'; Item = "$($a.Publication): $($a.Article)"; Detail = "$($a.PubServer)/$($a.PubDb)" })
        }
    }
    $pubsNow = @{}
    foreach ($a in $articles) { $pubsNow[$a.PubKey] = $true }
    foreach ($k in $prevArt.Keys) {
        $a = $prevArt[$k]
        if (-not $curArt.ContainsKey($k) -and $pubsNow.ContainsKey([string]$a.PubKey)) {
            $changes.Add([pscustomobject]@{ Change = 'Article removed'; Item = "$($a.Publication): $($a.Article)"; Detail = "$($a.PubServer)/$($a.PubDb)" })
        }
    }
    $prevSrv = @{}
    foreach ($s in @(Get-Prop $prev 'servers')) { if ($s) { $prevSrv[[string]$s.Server] = $s } }
    $curSrv = @{}
    foreach ($s in @($serverInfo.Keys) + @($failed.Keys)) { $curSrv[$s] = $true }
    # AG replicas come and go with failovers - the AG itself is compared below
    $agReplicas = @{}
    foreach ($ag in $ags.Values) { foreach ($rep in $ag.Replicas.Keys) { $agReplicas[$rep] = $true } }
    foreach ($s in $curSrv.Keys) { if (-not $prevSrv.ContainsKey($s) -and -not $agReplicas.ContainsKey($s)) { $changes.Add([pscustomobject]@{ Change = 'Server added'; Item = $s; Detail = '' }) } }
    foreach ($s in $prevSrv.Keys) { if (-not $curSrv.ContainsKey($s) -and -not $agReplicas.ContainsKey($s)) { $changes.Add([pscustomobject]@{ Change = 'Server not visited'; Item = $s; Detail = 'not reached in this run (no longer referenced, or not in the start list)' }) } }
    foreach ($pa in @(Get-Prop $prev 'ags')) {
        if (-not $pa) { continue }
        $k = ([string]$pa.Name).ToUpperInvariant()
        if (-not $ags.ContainsKey($k)) { $changes.Add([pscustomobject]@{ Change = 'Not checked'; Item = "AG $($pa.Name)"; Detail = 'not seen in this run' }); continue }
        $was = [string](Get-Prop $pa 'Primary'); $now = $ags[$k].Primary
        if ($was -and $now -and $was -ne $now) { $changes.Add([pscustomobject]@{ Change = 'Failover'; Item = "AG $($pa.Name)"; Detail = "primary $was -> $now" }) }
    }
    foreach ($s in $prevSrv.Keys) {
        $wasFailed = [bool](Get-Prop $prevSrv[$s] 'Failed')
        if ($failed.ContainsKey($s) -and -not $wasFailed) { $changes.Add([pscustomobject]@{ Change = 'Changed'; Item = "Server $s"; Detail = 'now unreachable' }) }
        elseif ($serverInfo.ContainsKey($s) -and $wasFailed) { $changes.Add([pscustomobject]@{ Change = 'Changed'; Item = "Server $s"; Detail = 'reachable again' }) }
    }
}

if (@($edges | Where-Object { $_.Change -ne 'removed' }).Count -eq 0) {
    Write-Warning 'No publications found. Check that a distributor is among the servers and that the login has db_datareader and replmonitor in the distribution database (or sysadmin).'
}

# ---------------------------------------------------------------------------
# 9. Graph: servers, nodes and links (shared by HTML, Mermaid and DOT)
# ---------------------------------------------------------------------------
$gServers = [ordered]@{}   # name -> server object
$gNodes = [ordered]@{}     # "srv|db" -> node object
$frameCss = @{ dist = 'fill:#fff4d6,stroke:#c9a227'; failed = 'fill:#fde2e2,stroke:#c0392b,color:#7b1d1d'; unqueried = 'fill:#eeeeee,stroke:#999,stroke-dasharray:4'
               ag = 'fill:#e3f2fd,stroke:#1e88e5'; '' = '' }
function Add-GServer([string]$Srv) {
    if ($gServers.Contains($Srv)) { return }
    $t = $Srv; $cls = ''
    if ($agByListener.ContainsKey($Srv)) {
        $ag = $ags[$agByListener[$Srv]]
        $t += " · AG $($ag.Name)"
        $prim = Get-PrimaryInstance $Srv
        if ($prim) {
            $t += " · primary $prim"
            if ($serverInfo.ContainsKey($prim)) { $t += ' · ' + (Get-SqlYear $serverInfo[$prim].Version) }
        }
        $cls = 'ag'
    } elseif ($serverInfo.ContainsKey($Srv)) {
        $i = $serverInfo[$Srv]
        $t += ' · ' + (Get-SqlYear $i.Version)
        if ($i.DistributionDbs) { $t += ' · DISTRIBUTOR'; $cls = 'dist' }
        if ($i.AgRole) { $t += " · AG $($i.AgRole)" }
    } elseif ($failed.ContainsKey($Srv)) {
        $t += ' · NO CONNECTION'; $cls = 'failed'
    } else { $cls = 'unqueried' }
    # Mermaid sizes a frame by its content, not by its title: the title goes on several lines and an invisible copy of it
    # (class sp) sits in the frame, otherwise long titles push frames over each other
    $gServers[$Srv] = [pscustomobject]@{ name = $Srv; title = $t; mmdTitle = ((Esc-Mmd $t) -replace ' · ', '<br>'); cls = $cls; css = $frameCss[$cls] }
}
function Add-GNode([string]$Srv, [string]$Db, [string]$Kind) {
    $k = "$Srv|$Db"
    if ($gNodes.Contains($k)) { return $gNodes[$k].id }
    Add-GServer $Srv
    $id = "n$($gNodes.Count + 1)"
    $label = Esc-Mmd $Db
    $mmd = switch ($Kind) { 'dist' { "$id{{""$label""}}" } 'ph' { "$id[""$label""]" } default { "$id[(""$label"")]" } }
    $gNodes[$k] = [pscustomobject]@{ id = $id; srv = $Srv; db = $Db; kind = $Kind; mmd = $mmd; s = "$Srv $Db".ToLowerInvariant() }
    return $id
}

$levelCss = @{
    ok = 'stroke:#2e7d32,stroke-width:2px'; warn = 'stroke:#e67e22,stroke-width:2.5px'; error = 'stroke:#c0392b,stroke-width:2.5px'
    unknown = 'stroke:#333333,stroke-width:1.5px'; '' = 'stroke:#333333,stroke-width:1.5px'
    removed = 'stroke:#9e9e9e,stroke-width:1.5px,stroke-dasharray:6 4'
}
$levelColor = @{ ok = '#2e7d32'; warn = '#e67e22'; error = '#c0392b'; unknown = '#333333'; '' = '#333333'; removed = '#9e9e9e' }
$multiDist = @($edges | Select-Object -ExpandProperty Distributor -Unique).Count -gt 1

$liveEdges = @($edges | Where-Object { $_.Change -ne 'removed' } | Sort-Object PubServer, PubDb, Publication, SubServer, SubDb)
$deadEdges = @($edges | Where-Object { $_.Change -eq 'removed' } | Sort-Object PubServer, PubDb, Publication, SubServer, SubDb)
foreach ($e in @($liveEdges) + @($deadEdges)) {
    [void](Add-GNode $e.PubServer $e.PubDb 'db')
    if ($e.SubServer) { [void](Add-GNode $e.SubServer $e.SubDb 'db') }
}
foreach ($f in $failed.Keys) { if (-not $gServers.Contains($f)) { [void](Add-GNode $f '(no connection)' 'ph') } }

$gLinks = New-Object System.Collections.Generic.List[object]
$groups = @{}
$groupOrder = New-Object System.Collections.Generic.List[string]
foreach ($e in @($liveEdges) + @($deadEdges)) {
    if (-not $e.SubServer) { continue }
    $gk = "$($e.PubServer)|$($e.PubDb)|$($e.SubServer)|$($e.SubDb)|$($e.Change -eq 'removed')"
    if ($ExpandEdges) { $gk += "|$($e.Publication)" }
    if (-not $groups.ContainsKey($gk)) { $groups[$gk] = New-Object System.Collections.Generic.List[object]; $groupOrder.Add($gk) }
    $groups[$gk].Add($e)
}
foreach ($gk in $groupOrder) {
    $g = $groups[$gk].ToArray()
    $e0 = $g[0]
    $a = Add-GNode $e0.PubServer $e0.PubDb 'db'
    $b = Add-GNode $e0.SubServer $e0.SubDb 'db'
    $pubNames = @($g | Select-Object -ExpandProperty Publication -Unique)
    $types = @($g | Select-Object -ExpandProperty PubType -Unique)
    $subTypes = @($g | Where-Object { $_.SubType } | Select-Object -ExpandProperty SubType -Unique)
    $level = ''
    foreach ($x in $g) { if ($levelRank[$x.Health] -gt $levelRank[$level]) { $level = $x.Health } }
    if ($e0.Change -eq 'removed') { $level = 'removed' }
    $lines = New-Object System.Collections.Generic.List[string]
    if ($pubNames.Count -le 3) { foreach ($p in $pubNames) { $lines.Add($p) } } else { $lines.Add("$($pubNames.Count) publications") }
    $lines.Add("$($types -join '/') · $($subTypes -join '/')")
    $tables = @($g | Where-Object { $artByPub.ContainsKey($_.PubKey) } | ForEach-Object { $artByPub[$_.PubKey] } | ForEach-Object { $_.Source } | Select-Object -Unique).Count
    if ($tables -gt 0) { $lines.Add("$tables table$(if ($tables -ne 1) { 's' })") }
    if ($multiDist -and $HideDistributors) { $lines.Add("dist: $($e0.Distributor)") }
    $liveLabel = (@($lines | ForEach-Object { Esc-Mmd $_ }) -join '<br/>')   # the monitor shows health live, not in the label
    $probs = @($g | Where-Object { $_.Problem } | ForEach-Object { $_.Problem -split ', ' } | Select-Object -Unique)
    if ($probs.Count -gt 2) { $probs = @($probs[0], $probs[1], '...') }
    if ($probs) { $lines.Add($probs -join ', ') }
    $chg = @($g | Where-Object { $_.Change } | Select-Object -ExpandProperty Change -Unique)
    if ($chg -contains 'removed') { $lines.Add('REMOVED') } elseif ($chg -contains 'new') { $lines.Add('NEW') } elseif ($chg -contains 'changed') { $lines.Add('CHANGED') }
    $arrow = '-->'
    if ($types.Count -eq 1) { $arrow = switch ($types[0]) { 'Snapshot' { '-.->' } 'Merge' { '<-->' } 'P2P' { '<==>' } default { '-->' } } }
    $css = $levelCss[$level]
    if ($chg -contains 'new') { $css = $css -replace 'stroke-width:[\d.]+px', 'stroke-width:4px' }
    $label = (@($lines | ForEach-Object { Esc-Mmd $_ }) -join '<br/>')
    $search = (@($g | ForEach-Object {
        "$($_.PubServer) $($_.PubDb) $($_.Publication) $($_.PubType) $($_.SubServer) $($_.SubDb) $($_.SubType) $($_.Distributor) $($_.Health) $($_.Problem) $($_.ArticleNames) $($_.Change) $($_.PubInstance) $($_.SubInstance)"
    }) -join ' ').ToLowerInvariant()
    $gLinks.Add([pscustomobject]@{
        kind = 'repl'; a = $a; b = $b; mmd = "$a $arrow|""$label""| $b"; mmdLive = "$a $arrow|""$liveLabel""| $b"; css = $css; s = $search
        lines = @($lines); types = @($types); level = $level; isNew = ($chg -contains 'new'); keys = @($g | ForEach-Object { $_.Key })
    })
}
if (-not $HideDistributors) {
    $seenDist = @{}
    foreach ($e in $liveEdges) {
        $k = "$($e.PubServer)|$($e.PubDb)|$($e.Distributor)|$($e.DistributionDb)"
        if ($seenDist.ContainsKey($k)) { continue }
        $seenDist[$k] = $true
        $a = Add-GNode $e.PubServer $e.PubDb 'db'
        $b = Add-GNode $e.Distributor "[$($e.DistributionDb)]" 'dist'
        $gLinks.Add([pscustomobject]@{ kind = 'dist'; a = $a; b = $b; mmd = "$a -.- $b"; mmdLive = "$a -.- $b"; css = 'stroke:#b8b8b8,stroke-width:1px'; s = ''; lines = @(); types = @(); level = ''; isNew = $false; keys = @() })
    }
}

# Mermaid text from a subset of nodes and links (topology.html builds the same in JavaScript)
function Build-Mermaid($Nodes, $Links) {
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add("flowchart $Direction")
    $styles = New-Object System.Collections.Generic.List[string]
    $si = 0
    foreach ($s in $gServers.Values) {
        $ns = @($Nodes | Where-Object { $_.srv -eq $s.name })
        if (-not $ns) { continue }
        $si++
        $out.Add("  subgraph s$si[""$($s.mmdTitle)""]")
        $out.Add("    w$si[""$($s.mmdTitle)""]:::sp")
        foreach ($n in $ns) { $out.Add("    $($n.mmd)") }
        $out.Add('  end')
        if ($s.css) { $styles.Add("  style s$si $($s.css)") }
    }
    $byCss = [ordered]@{}
    $i = 0
    foreach ($l in $Links) {
        $out.Add("  $($l.mmd)")
        if (-not $byCss.Contains($l.css)) { $byCss[$l.css] = New-Object System.Collections.Generic.List[int] }
        $byCss[$l.css].Add($i); $i++
    }
    foreach ($s in $styles) { $out.Add($s) }
    foreach ($c in $byCss.Keys) { $out.Add("  linkStyle $($byCss[$c] -join ',') $c") }
    $out.Add('  classDef sp fill:none,stroke:none,color:transparent')
    return ($out -join "`n")
}
$mmdText = Build-Mermaid @($gNodes.Values) $gLinks.ToArray()

# --- Graphviz DOT ---
$dot = New-Object System.Collections.Generic.List[string]
$dot.Add('digraph replication {')
$dot.Add("  rankdir=$Direction; compound=true; fontname=""Segoe UI""; nodesep=0.4; ranksep=1.0;")
$dot.Add('  node [fontname="Segoe UI", fontsize=10, shape=cylinder, style=filled, fillcolor="#e8f0fe"];')
$dot.Add('  edge [fontname="Segoe UI", fontsize=9];')
$ci = 0
foreach ($s in $gServers.Values) {
    $ci++
    $fill = @{ dist = '#fff4d6'; failed = '#fde2e2'; unqueried = '#eeeeee'; ag = '#e3f2fd'; '' = '#f7f7f7' }[$s.cls]
    $dot.Add("  subgraph cluster_$ci { label=""$(Esc-Dot $s.title)""; style=filled; fillcolor=""$fill"";")
    foreach ($n in @($gNodes.Values | Where-Object { $_.srv -eq $s.name })) {
        $shape = @{ dist = 'hexagon'; ph = 'box'; db = 'cylinder' }[$n.kind]
        $dot.Add("    $($n.id) [label=""$(Esc-Dot $n.db)"", shape=$shape];")
    }
    $dot.Add('  }')
}
foreach ($l in $gLinks) {
    if ($l.kind -eq 'dist') { $dot.Add("  $($l.a) -> $($l.b) [style=dotted, color=""#aaaaaa"", arrowhead=none];"); continue }
    $attr = 'style=solid'
    if ($l.types.Count -eq 1) { $attr = switch ($l.types[0]) { 'Snapshot' { 'style=dashed' } 'Merge' { 'dir=both' } 'P2P' { 'dir=both, penwidth=2' } default { 'style=solid' } } }
    if ($l.level -eq 'removed') { $attr = 'style=dashed' }
    $col = $levelColor[$l.level]
    $pen = ''
    if ($l.isNew) { $pen = ', penwidth=3' }
    $lbl = (@($l.lines | ForEach-Object { Esc-Dot $_ }) -join '\n')
    $dot.Add("  $($l.a) -> $($l.b) [label=""$lbl"", $attr, color=""$col"", fontcolor=""$col""$pen];")
}
$dot.Add('}')
$dotText = $dot -join "`n"

# ---------------------------------------------------------------------------
# 9b. Repairs for common problems and reports for an AI assistant
# ---------------------------------------------------------------------------
# A problem (one subscription, Log Reader or finding) gives repair actions. An action is a list of steps (server,
# database, T-SQL) with a level: safe (run with -AllowRepair), full (run with -AllowAllRepair) or script (never run by
# the tool - it needs a password or a person who decides). Nothing here talks to a server: the monitor runs the steps,
# the report writes them to repairs.sql.
$repairMode = 'none'
if ($AllowAllRepair) { $repairMode = 'all' } elseif ($AllowRepair) { $repairMode = 'safe' }

function New-Problem {
    return [ordered]@{ Kind = ''; Key = ''; Label = ''; Level = ''; Problem = ''; Status = ''; Job = ''; JobSrv = ''; JobId = ''; JobName = ''
                       Msg = ''; Codes = (New-Object System.Collections.Generic.List[int]); Text = ''; Seq = ''; Fail = $null
                       PubServer = ''; PubName = ''; PubDb = ''; Publication = ''; PubType = ''; SubServer = ''; SubName = ''; SubDb = ''; SubType = ''
                       DistServer = ''; DistDb = ''; LogWait = ''; Recent = $false; ArtFilter = $null }
}
function New-RepairAction([string]$Id, [string]$Title, [string]$Level, [string]$Why, [string]$Risk, [string]$Undo, [string]$Check, [string]$Phrase = '') {
    return [ordered]@{ id = $Id; title = $Title; level = $Level; why = $Why; risk = $Risk; undo = $Undo; check = $Check; confirm = $Phrase
                       steps = (New-Object System.Collections.Generic.List[object]) }
}
function Add-RepairStep($A, [string]$Srv, [string]$Db, [string]$Sql) { $A.steps.Add([ordered]@{ srv = $Srv; db = $Db; sql = $Sql.Trim() }) }
function Get-SqlLit([string]$s) { return "N'" + ($s -replace "'", "''") + "'" }
function Get-JobStateWord([string]$Text) {
    if ($Text -match 'DISABLED|disabled') { return 'disabled' }
    if ($Text -match 'not running') { return 'not running' }
    if ($Text -match 'running') { return 'running' }
    return ''
}

function Get-RepairActions($P) {
    $acts = New-Object System.Collections.Generic.List[object]
    $codes = @($P.Codes)
    $isSub = ($P.Kind -eq 'sub'); $isLr = ($P.Kind -eq 'lr')
    $agentWord = 'Distribution Agent'
    if ($isLr) { $agentWord = 'Log Reader Agent' }
    $jobRef = ''; $jobName = $P.JobName
    if ($P.JobId) { $jobRef = "@job_id = N'$($P.JobId)'"; if (-not $jobName) { $jobName = $P.JobId } }
    # stop the job only while it runs: sp_stop_job on a stopped job fails with 22022, and TRY/CATCH does not catch it
    $stopJob = "IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobactivity WHERE job_id = N'$($P.JobId)' AND start_execution_date IS NOT NULL AND stop_execution_date IS NULL`n" +
               "           AND session_id = (SELECT MAX(session_id) FROM msdb.dbo.syssessions))`n    EXEC msdb.dbo.sp_stop_job $jobRef;`nWAITFOR DELAY '00:00:05';"
    # repairs that follow from error texts only while the agent fails now (old errors of a healthy agent do not count)
    $failing = ($P.Status -in 'Failed', 'Retrying') -or ($P.Level -eq 'error') -or $P.Recent   # Recent: an error in the last 30 min (the agent retries in between)

    # 1. the agent job: disabled, not running, or running with a failed / retrying agent
    if ($jobRef -and $P.JobSrv) {
        if ($P.Job -eq 'disabled') {
            $a = New-RepairAction 'enable-job' 'Enable and start the agent job' 'safe' "The $agentWord job $jobName is disabled, so the agent does not run." `
                'None - it only starts the agent.' "EXEC msdb.dbo.sp_update_job $jobRef, @enabled = 0;" 'The agent shows Running within a minute and the pending commands go down.'
            Add-RepairStep $a $P.JobSrv 'msdb' "EXEC msdb.dbo.sp_update_job $jobRef, @enabled = 1;`nEXEC msdb.dbo.sp_start_job $jobRef;"
            $acts.Add($a)
        } elseif ($P.Job -eq 'not running') {
            $a = New-RepairAction 'start-job' 'Start the agent job' 'safe' "The $agentWord job $jobName is not running." 'None.' "EXEC msdb.dbo.sp_stop_job $jobRef;" `
                'The agent shows Running within a minute. If it fails again, the error in the detail tells why.'
            Add-RepairStep $a $P.JobSrv 'msdb' "EXEC msdb.dbo.sp_start_job $jobRef;"
            $acts.Add($a)
        } elseif ($P.Job -eq 'running' -and $P.Status -in 'Failed', 'Retrying') {
            $a = New-RepairAction 'restart-job' 'Restart the agent job' 'safe' "The $agentWord is $($P.Status.ToLowerInvariant()) - a restart helps after network breaks, timeouts and deadlocks." `
                'None - the agent continues where it stopped.' 'Nothing to undo.' 'The agent shows Running; if the same error comes back, it is not a transient one (see the other repairs).'
            Add-RepairStep $a $P.JobSrv 'msdb' "$stopJob`nEXEC msdb.dbo.sp_start_job $jobRef;"
            $acts.Add($a)
        }
    }
    if ($isSub) {
        $pubLit = Get-SqlLit $P.Publication
        # 2. never initialized: a new snapshot
        if ($P.Problem -match 'UNINITIALIZED') {
            $a = New-RepairAction 'snapshot' 'Start the Snapshot Agent' 'safe' 'The subscription waits for an initial snapshot.' `
                'A snapshot reads every article of the publication on the publisher (load, locks with concurrent snapshot off).' 'Nothing to undo.' `
                'The Distribution Agent applies the snapshot; the subscription leaves UNINITIALIZED.'
            Add-RepairStep $a $P.PubServer $P.PubDb "EXEC sp_startpublication_snapshot @publication = $pubLit;"
            $acts.Add($a)
        }
        # 3. inactive or expired: reinitialize
        if ($P.Problem -match 'INACTIVE|EXPIR' -or $codes -contains 21074 -or $P.Text -match '(?i)marked inactive|has expired|must be reinitialized') {
            $a = New-RepairAction 'reinit' 'Reinitialize the subscription (new snapshot)' 'full' 'The subscription is inactive or expired - the agent cannot continue without a new snapshot.' `
                'The subscriber tables are reloaded from a new snapshot (load on the publisher and the network; changes made only at the subscriber are lost).' `
                'No undo - the snapshot replaces the subscriber data.' 'The snapshot is generated and applied; the subscription goes back to Running.' $P.SubDb
            if ($P.SubType -match 'Pull') {
                Add-RepairStep $a $P.SubServer $P.SubDb "EXEC sp_reinitpullsubscription @publisher = $(Get-SqlLit $P.PubName), @publisher_db = $(Get-SqlLit $P.PubDb), @publication = $pubLit;"
                Add-RepairStep $a $P.PubServer $P.PubDb "EXEC sp_startpublication_snapshot @publication = $pubLit;"
            } else {
                Add-RepairStep $a $P.PubServer $P.PubDb ("EXEC sp_reinitsubscription @publication = $pubLit, @article = N'all', @subscriber = $(Get-SqlLit $P.SubName), @destination_db = $(Get-SqlLit $P.SubDb);`n" +
                                                         "EXEC sp_startpublication_snapshot @publication = $pubLit;")
            }
            $acts.Add($a)
        }
        # 4. data errors: row missing at the subscriber (20598) or duplicate key (2601, 2627)
        $dataErr = @($codes | Where-Object { $_ -in 20598, 2601, 2627 }).Count -gt 0 -or $P.Text -match '(?i)row was not found at the Subscriber|duplicate key'
        if ($dataErr -and $failing) {
            if ($P.Seq -and $jobRef) {
                $a = New-RepairAction 'skip-tx' 'Skip the failing transaction' 'full' 'The agent stops on a data error and retries the same transaction forever.' `
                    'The whole transaction is not applied at the subscriber - the tables differ afterwards. Compare them (the comparison repair below) and fix the rows.' `
                    'No undo - apply the skipped changes by hand (the Command button shows them).' 'The agent continues with the next transaction.' 'SKIP'
                Add-RepairStep $a $P.JobSrv 'msdb' $stopJob
                Add-RepairStep $a $P.SubServer $P.SubDb ("-- the last applied transaction becomes the failing one, so the agent continues after it`n" +
                    "EXEC sp_setsubscriptionxactseqno @publisher = $(Get-SqlLit $P.PubName), @publisher_db = $(Get-SqlLit $P.PubDb), @publication = $pubLit, @xact_seqno = $($P.Seq);")
                Add-RepairStep $a $P.JobSrv 'msdb' "EXEC msdb.dbo.sp_start_job $jobRef;"
                $acts.Add($a)
            }
            $f = $P.Fail
            $srcOwner = 'dbo'; $src = '<table>'; $dstOwner = 'dbo'; $dst = '<table>'; $tbl = 'table'
            if ($f -and $f.src) {
                $src = $f.src; $dst = $f.dst; $tbl = $f.dst
                if ($f.srcOwner) { $srcOwner = $f.srcOwner }
                if ($f.dstOwner) { $dstOwner = $f.dstOwner }
                if (-not $dst) { $dst = $src; $tbl = $src }
            }
            $safeName = $tbl -replace '[^A-Za-z0-9_]', '_'
            if ($P.ArtFilter) {
                # tablediff compares whole tables: on a filtered article its fix would add the rows and columns the filter leaves out
                $flt = $P.ArtFilter
                $a = New-RepairAction 'compare-filtered' "Compare the filtered table $srcOwner.$src by hand (tablediff would compare the whole table)" 'script' `
                    "The article is filtered$(if ($flt.Rows) { " (rows WHERE $($flt.Rows))" })$(if ($flt.Excluded) { " (columns not published: $($flt.Excluded))" }) - tablediff knows no filter, its fix would copy the rows and columns the filter leaves out." `
                    'None - only counts rows.' 'Nothing to undo.' 'Both counts are equal; then compare the keys of the missing rows (the error names the key).'
                $where = ''
                if ($flt.Rows) { $where = " WHERE $($flt.Rows)" }
                Add-RepairStep $a $P.PubServer $P.PubDb "SELECT COUNT_BIG(*) AS rows_at_publisher FROM [$srcOwner].[$src]$where;  -- the rows the filter lets through"
                Add-RepairStep $a $P.SubServer $P.SubDb "SELECT COUNT_BIG(*) AS rows_at_subscriber FROM [$dstOwner].[$dst];"
                $acts.Add($a)
            } else {
            $a = New-RepairAction 'tablediff' "Compare the table $(if ($f -and $f.src) { "$dstOwner.$dst " })and generate the fix (tablediff)" 'script' `
                'tablediff compares the publisher and the subscriber table row by row and writes the T-SQL that makes the subscriber equal.' `
                'Reading both tables (large tables take time). The generated fix changes subscriber rows - review it first.' 'Keep a copy of the subscriber table before running the fix.' `
                'tablediff reports "identical" when run again.'
            $tdCmd = "`"%ProgramFiles%\Microsoft SQL Server\<version: 150 = 2019, 160 = 2022>\COM\tablediff.exe`" -sourceserver `"$(Get-Target $P.PubServer)`" -sourcedatabase `"$($P.PubDb)`" " +
                     "-sourceschema `"$srcOwner`" -sourcetable `"$src`" -destinationserver `"$(Get-Target $P.SubServer)`" -destinationdatabase `"$($P.SubDb)`" " +
                     "-destinationschema `"$dstOwner`" -destinationtable `"$dst`" -f `"C:\Temp\fix_$safeName.sql`""
            $note = 'Run in a command prompt (cmd), then review C:\Temp\fix_' + $safeName + '.sql and run it at the subscriber; then restart the agent.'
            if (-not ($f -and $f.src)) { $note += ' The table of the failing command is shown by the Command button of the error. Do not use tablediff on a filtered article (row or column filter - see the Articles table): its fix would copy the rows and columns the filter leaves out.' }
            Add-RepairStep $a $P.SubServer '' "$tdCmd`n$note"
            $acts.Add($a)
            }
        }
        # 5. login failed (password changed): script with the new password
        if ($failing -and (($codes -contains 18456 -and $codes -notcontains 4060) -or ($P.Text -match '(?i)login failed for user' -and $P.Text -notmatch '(?i)cannot open database'))) {
            $a = New-RepairAction 'password' 'Set the new password of the agent login' 'script' 'The agent cannot log in - the password of its login was probably changed.' `
                'None if the password is right.' 'Set the old password again.' 'The agent logs in and shows Running.'
            if ($P.SubType -match 'Pull') {
                Add-RepairStep $a $P.SubServer $P.SubDb ("EXEC sp_change_subscription_properties @publisher = $(Get-SqlLit $P.PubName), @publisher_db = $(Get-SqlLit $P.PubDb), @publication = $pubLit,`n" +
                                                         "     @property = N'distributor_password', @value = N'<new password>';")
            } else {
                Add-RepairStep $a $P.PubServer $P.PubDb ("-- SQL login of the push agent at the subscriber:`nEXEC sp_changesubscription @publication = $pubLit, @article = N'all', @subscriber = $(Get-SqlLit $P.SubName), @destination_db = $(Get-SqlLit $P.SubDb),`n" +
                                                         "     @property = N'subscriber_password', @value = N'<new password>';`n" +
                                                         "-- Windows account the job runs as: @property = N'distrib_job_password'")
            }
            $acts.Add($a)
        }
    }
    if ($isLr) {
        # 6. the Log Reader cannot find its place in the log (after a restore or a failover with lost log)
        if ($failing -and $P.Text -match '(?i)sp_repldone|start of replication in the log|log scan number|LSN') {
            $a = New-RepairAction 'replrestart' 'Resynchronize the Log Reader with the log (sp_replrestart)' 'full' 'The Log Reader points to a log position that the publisher database no longer has (restore, lost log).' `
                'Transactions between the old and the new position may be missing at the subscribers - validate them afterwards.' 'No undo.' `
                'The Log Reader runs again; validate the subscriptions (sp_publication_validation).' 'RESTART'
            if ($jobRef) { Add-RepairStep $a $P.JobSrv 'msdb' $stopJob }
            Add-RepairStep $a $P.PubServer $P.PubDb 'EXEC sp_replrestart;'
            if ($jobRef) { Add-RepairStep $a $P.JobSrv 'msdb' "EXEC msdb.dbo.sp_start_job $jobRef;" }
            $acts.Add($a)
        }
        # 7. the publisher log cannot be truncated (log_reuse_wait = REPLICATION) - last resort
        if ($P.Level -in 'error', 'warn' -or $P.LogWait -eq 'REPLICATION') {
            $a = New-RepairAction 'repldone' 'Mark the whole log as replicated (sp_repldone) - last resort when the log is full' 'full' `
                'The publisher log keeps growing because the Log Reader does not read it (log_reuse_wait = REPLICATION).' `
                'The subscribers never get the changes made until now - every subscription of this database has to be reinitialized afterwards.' `
                'No undo.' 'The log can be truncated (backup log); reinitialize the subscriptions.' 'REPLDONE'
            if ($jobRef) { Add-RepairStep $a $P.JobSrv 'msdb' $stopJob }
            Add-RepairStep $a $P.PubServer $P.PubDb "EXEC sp_repldone @xactid = NULL, @xact_segno = NULL, @numtrans = 0, @time = 0, @reset = 1;`nEXEC sp_replflush;"
            if ($jobRef) { Add-RepairStep $a $P.JobSrv 'msdb' "EXEC msdb.dbo.sp_start_job $jobRef;" }
            $acts.Add($a)
        }
        # 8. login failed
        if ($failing -and $P.Text -match '(?i)login failed for user') {
            $a = New-RepairAction 'password' 'Set the new password of the Log Reader login' 'script' 'The Log Reader cannot log in - the password of its login was probably changed.' `
                'None if the password is right.' 'Set the old password again.' 'The Log Reader logs in and shows Running.'
            Add-RepairStep $a $P.PubServer $P.PubDb ("-- SQL login to the publisher:`nEXEC sp_changelogreader_agent @publisher_password = N'<new password>';`n" +
                                                     "-- Windows account the job runs as: EXEC sp_changelogreader_agent @job_login = N'<domain\user>', @job_password = N'<new password>';")
            $acts.Add($a)
        }
    }
    return , $acts
}

# Repairs of findings (cleanup job, replication with availability groups)
function Get-FindingRepairs($F) {
    $acts = New-Object System.Collections.Generic.List[object]
    if (-not $F.PSObject.Properties['Data'] -or -not $F.Data) { return , $acts }
    $d = $F.Data
    switch ($d.Type) {
        'cleanup-job' {
            if (-not $d.JobId) { break }
            $ref = "@job_id = N'$($d.JobId)'"
            if (-not $d.Enabled) {
                $a = New-RepairAction 'enable-cleanup' 'Enable and start the distribution clean up job' 'safe' 'Without the clean up job the distribution database grows without limit.' `
                    'The first run can take long and load the distributor when much is to be deleted.' "EXEC msdb.dbo.sp_update_job $ref, @enabled = 0;" 'The job runs every 10 minutes and succeeds.'
                Add-RepairStep $a $d.Srv 'msdb' "EXEC msdb.dbo.sp_update_job $ref, @enabled = 1;`nEXEC msdb.dbo.sp_start_job $ref;"
            } else {
                $a = New-RepairAction 'start-cleanup' 'Run the distribution clean up job now' 'safe' 'The clean up job failed or has not run recently.' `
                    'The run can take long and load the distributor when much is to be deleted.' 'Nothing to undo.' 'The job succeeds (job history).'
                Add-RepairStep $a $d.Srv 'msdb' "EXEC msdb.dbo.sp_start_job $ref;"
            }
            $acts.Add($a)
        }
        'ag-register' {
            $work = $d.WorkDir
            if (-not $work) { $work = '<snapshot folder of the other publishers>' }
            $a = New-RepairAction 'ag-register' 'Register the AG replicas at the distributor' 'script' 'After a failover to a replica that is not a publisher at the distributor the Log Reader stops.' `
                'None.' 'EXEC sp_dropdistpublisher @publisher = N''<replica>'';' 'The finding disappears; a test failover keeps the Log Reader running.'
            foreach ($r in $d.Replicas) {
                Add-RepairStep $a $d.Dist 'master' ("EXEC sp_adddistpublisher @publisher = $(Get-SqlLit $r), @distribution_db = $(Get-SqlLit $d.DistDb), @security_mode = 1,`n" +
                                                    "     @working_directory = $(Get-SqlLit $work);  -- SQL login instead: @security_mode = 0, @login = N'<login>', @password = N'<password>'")
            }
            foreach ($r in $d.Replicas) {
                $sql = "EXEC sp_adddistributor @distributor = $(Get-SqlLit $d.Dist), @password = N'<distributor_admin password>';"
                foreach ($sub in $d.Subscribers) { $sql += "`nIF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = $(Get-SqlLit $sub)) EXEC sp_addlinkedserver @server = $(Get-SqlLit $sub);  -- push subscriber" }
                Add-RepairStep $a $r 'master' $sql
            }
            $acts.Add($a)
        }
        'ag-redirect' {
            $a = New-RepairAction 'ag-redirect' 'Redirect the publisher to the AG listener' 'full' 'The agents connect to the original publisher instead of the listener, so a failover stops them.' `
                'The agents reconnect through the listener (one retry).' 'Redirect to the original server again (sp_redirect_publisher with @redirected_publisher = the old name).' `
                'sp_validate_redirected_publisher succeeds; the finding disappears.' 'REDIRECT'
            Add-RepairStep $a $d.Dist $d.DistDb "EXEC sp_redirect_publisher @original_publisher = $(Get-SqlLit $d.Orig), @publisher_db = $(Get-SqlLit $d.Db), @redirected_publisher = $(Get-SqlLit $d.Listener);"
            $acts.Add($a)
        }
    }
    return , $acts
}

function Test-RepairAllowed($A) { return (($A.level -eq 'safe' -and $repairMode -ne 'none') -or ($A.level -eq 'full' -and $repairMode -eq 'all')) }

# T-SQL file of one action: steps with :CONNECT (SSMS in SQLCMD mode runs the whole file across servers)
function Format-RepairScript([string]$Label, $A) {
    $o = New-Object System.Collections.Generic.List[string]
    $o.Add("-- Repair: $($A.title)  [$($A.level)]")
    $o.Add("-- For:    $Label")
    foreach ($kv in @(@('Why', $A.why), @('Risk', $A.risk), @('Undo', $A.undo), @('Check', $A.check))) { if ($kv[1]) { $o.Add(('-- {0,-7} {1}' -f ($kv[0] + ':'), $kv[1])) } }
    $o.Add("-- Generated by Get-ReplTopology.ps1 $scriptVersion on $((Get-Date).ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)). SSMS: Query > SQLCMD Mode (for the :CONNECT lines).")
    $i = 0
    foreach ($s in $A.steps) {
        $i++
        $where = "server $($s.srv)"
        if ($s.db) { $where += ", database $($s.db)" } else { $where += ' (command line, not T-SQL)' }
        $o.Add("-- Step $i of $($A.steps.Count): $where")
        if (-not $s.db) { foreach ($ln in ($s.sql -split "`n")) { $o.Add("-- $ln") }; continue }
        $o.Add(":CONNECT $(Get-Target $s.srv)")
        $o.Add("USE [$($s.db)];")
        $o.Add($s.sql)
        $o.Add('GO')
    }
    return ($o -join "`r`n")
}

# ---- reports for an AI assistant: names and data values masked unless -NoMask ----
function New-AiMasker { return @{ Names = @{}; Map = (New-Object System.Collections.Generic.List[string]); Count = @{} } }
function Add-AiName($M, [string]$Name, [string]$Kind) {
    if (-not $Name) { return }
    $Name = $Name.Trim()
    if ($Name.Length -lt 3 -or $Name -match '^(?i)(dbo|sys|master|msdb|tempdb|model|distribution|all|null|sql|agent)$') { return }
    $k = $Name.ToUpperInvariant()
    if ($M.Names.ContainsKey($k)) { return }
    if (-not $M.Count.ContainsKey($Kind)) { $M.Count[$Kind] = 0 }
    $M.Count[$Kind]++
    $tok = "$Kind$($M.Count[$Kind])"
    $M.Names[$k] = $tok; $M.Map.Add("$tok = $Name")
}
function Add-AiServer($M, [string]$Name) {
    if (-not $Name) { return }
    $n = Remove-Port $Name
    Add-AiName $M $n 'SRV'
    if ($n.Contains('\')) { $p = $n.Split([char]'\', 2); Add-AiName $M $p[0] 'HOST'; Add-AiName $M $p[1] 'INST' }
}
# literal values in a replicated command: strings, binary and numbers become their type
function Protect-AiValues([string]$Text) {
    if ($NoMask -or -not $Text) { return $Text }
    $Text = [regex]::Replace($Text, "N?'(?:[^']|'')*'", [System.Text.RegularExpressions.MatchEvaluator] {
        param($m) $v = $m.Value; if ($v.StartsWith('N')) { "<nvarchar $($v.Length - 3)>" } else { "<varchar $($v.Length - 2)>" } })
    $Text = [regex]::Replace($Text, '0x[0-9A-Fa-f]+', '<binary>')
    return [regex]::Replace($Text, '(?<![\w<#\]])-?\d+(?:\.\d+)?(?![\w>])', '<n>')
}
function Protect-AiText($M, [string]$Text) {
    if ($NoMask) { return $Text }
    # replication procedures carry the owner and the table in their name (sp_MSupd_dboOrders)
    $Text = [regex]::Replace($Text, '(?i)\bsp_MS(ins|upd|del)_[A-Za-z0-9_]+', 'sp_MS$1_<article>')
    foreach ($k in @($M.Names.Keys | Sort-Object Length -Descending)) {
        # '_' counts as a border: snapshot files (Orders_3.sch) and folders (SRV_DB_PUB) join names with it
        $Text = [regex]::Replace($Text, '(?<![A-Za-z0-9])' + [regex]::Escape($k) + '(?![A-Za-z0-9])', $M.Names[$k], 'IgnoreCase')
    }
    $Text = [regex]::Replace($Text, '(?i)(key value is \()[^)]*(\))', '$1<masked>$2')
    $Text = [regex]::Replace($Text, '\b(?:\d{1,3}\.){3}\d{1,3}\b', '<ip>')
    return [regex]::Replace($Text, '(?i)\b(?:[a-z0-9-]+\.)+(?:com|net|org|local|lan|corp|intra|int|pl|de|fr|eu|uk|biz|info)\b', '<domain>')
}
# Names the masker knows: servers, listeners, AGs, databases, publications, tables
function Add-AiKnownNames($M) {
    foreach ($s in @($gServers.Keys)) { Add-AiServer $M $s }
    foreach ($s in @($serverInfo.Keys)) { Add-AiServer $M $s }
    foreach ($ag in $ags.Values) { Add-AiName $M ([string]$ag.Name) 'AG'; foreach ($l in $ag.Listeners) { Add-AiServer $M $l }; foreach ($r in @($ag.Replicas.Keys)) { Add-AiServer $M $r } }
    foreach ($e in $edges) {
        foreach ($n in @($e.PubServerRaw, $e.SubServerRaw, $e.PubServer, $e.SubServer, $e.Distributor)) { Add-AiServer $M ([string]$n) }
        Add-AiName $M ([string]$e.PubDb) 'DB'; Add-AiName $M ([string]$e.SubDb) 'DB'; Add-AiName $M ([string]$e.DistributionDb) 'DB'; Add-AiName $M ([string]$e.Publication) 'PUB'
    }
    foreach ($a in $articles) {
        foreach ($n in @($a.Article, $a.Source, $a.Destination)) { $t = ([string]$n -replace '^.*\.', '') -replace '[\[\]]', ''; Add-AiName $M $t 'TAB' }
    }
    # columns left out by a column filter (names like PESEL or SALARY say more than they should)
    foreach ($f in $artFilter.Values) { foreach ($c in ([string]$f.Excluded -split ',\s*')) { Add-AiName $M $c 'COL' } }
    # every database and replication job of the visited servers (leftovers and orphaned jobs carry names too)
    foreach ($si in $serverInfo.Values) {
        foreach ($db in @($si.Dbs.Values)) { Add-AiName $M ([string]$db.name) 'DB' }
        foreach ($j in $si.Jobs) { if ([string]$j.category -like 'REPL-*') { Add-AiName $M ([string]$j.name) 'JOB' } }
    }
}
$aiQuestion = @(
    'I run SQL Server replication (transactional, with availability groups where noted). Below is what a monitoring tool',
    'collected. Names are replaced by tokens (SRV1, DB1, PUB1, TAB1 ...) and data values by their type.',
    'Please find the most likely root cause, then give the fix step by step with T-SQL, and mark the steps that change',
    'data or need a new snapshot. Say what else I should check and with which queries.')
# Writes the report (masked unless -NoMask) and the token list; returns the paths
function Save-AiReport([string]$Raw, $M, [string]$BaseName) {
    if (-not (Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $file = Join-Path $OutputDir "$BaseName-$stamp.md"
    $text = Protect-AiText $M $Raw
    [System.IO.File]::WriteAllText($file, $text, (New-Object System.Text.UTF8Encoding $false))
    $mapFile = ''
    if (-not $NoMask) {
        $mapFile = Join-Path $OutputDir "$BaseName-$stamp.names.txt"
        $hdr = @('# Tokens of ' + (Split-Path $file -Leaf) + ' - keep this file here, do not paste it into the AI chat.', '')
        [System.IO.File]::WriteAllText($mapFile, (($hdr + @($M.Map)) -join "`r`n"), (New-Object System.Text.UTF8Encoding $false))
    }
    return [pscustomobject]@{ File = $file; Map = $mapFile; Text = $text }
}

# ---------------------------------------------------------------------------
# 10. Monitor (-Monitor): live page served by this script. Read only, except tracer
#     tokens (-AllowTracerTokens). Every server is queried on its own schedule.
# ---------------------------------------------------------------------------
# Problems that the monitor re-evaluates live; the rest of the crawl problems stay as notes
$transientRx = '^(FAILED|RETRYING|ERROR|PERFORMANCE CRITICAL|LONG-RUNNING MERGE|EXPIRING|UNINITIALIZED|LATENCY |PENDING |AGENT NOT RUNNING|AGENT JOB DISABLED|STOPPED, PENDING|LOG READER|INACTIVE|\d+ (FAILURE|RETRIES))'
$runName = @{ 0 = ''; 1 = 'Started'; 2 = 'Stopped'; 3 = 'Running'; 4 = 'Idle'; 5 = 'Retrying'; 6 = 'Failed' }
# What to do about common replication errors (web page and console)
$monHints = [ordered]@{
    '20598' = 'The row to update or delete does not exist at the subscriber. Find the row by the key in the command, fix the data or reinitialize; skipping hides data differences.'
    '2627'  = 'Duplicate key at the subscriber: the row already exists (inserted at the subscriber or applied twice).'
    '2601'  = 'Duplicate key at the subscriber (unique index): the row already exists.'
    '547'   = 'Foreign key or check constraint at the subscriber. Replicated tables normally use NOT FOR REPLICATION constraints.'
    '8152'  = 'String or binary data would be truncated: the subscriber column is shorter than at the publisher.'
    '2628'  = 'String or binary data would be truncated: the subscriber column is shorter than at the publisher.'
    '208'   = 'Object not found at the subscriber (schema differs, table dropped or renamed).'
    '207'   = 'Column not found at the subscriber (schema differs).'
    '1205'  = 'Deadlock - the agent retries by itself; frequent deadlocks point to concurrent work at the subscriber.'
    '18456' = 'Login failed - check the agent login and password (sp_changesubscription / agent security).'
    '4060'  = 'Database not available at the subscriber - missing, offline or no access.'
    '-2'    = 'Query timeout - the agent waited too long (blocking or a slow subscriber); look at blocking and waits.'
    '20084' = 'The agent cannot connect to the server.'
    '14151' = 'The agent stopped with an error - the details are in the next message.'
}
$mon = @{}

function Get-Worse([string]$A, [string]$B) { if ($levelRank[$B] -gt $levelRank[$A]) { return $B } return $A }
function Get-Secs($From, $To) {
    if ($From -is [datetime] -and $To -is [datetime]) { return [int][math]::Max(0, ($To - $From).TotalSeconds) }
    return $null
}
function Format-Dt($d) { if ($d -is [datetime]) { return $d.ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) } return '' }
function New-MonList { return , (New-Object System.Collections.Generic.List[object]) }
# Built-in JSON (100x faster than ConvertTo-JsonText for the live state); -Html escapes < > & for a <script> block
function ConvertTo-FastJson($Obj, [switch]$Html) {
    $p = @{ InputObject = $Obj; Depth = 12; Compress = $true }
    if ($Html -and $PSVersionTable.PSVersion.Major -ge 6) { $p.EscapeHandling = 'EscapeHtml' }   # Windows PowerShell 5.1 escapes < > & by itself
    return (ConvertTo-Json @p)
}

function Add-MonEvent([string]$Level, [string]$Text, [string]$Key = '') {
    $mon.Events.Insert(0, [ordered]@{ t = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture); l = $Level; x = $Text; k = $Key })
    if ($mon.Events.Count -gt 500) { $mon.Events.RemoveAt($mon.Events.Count - 1) }
    if ($mon.Ui -eq 'console') { return }   # shown in the console view itself
    $col = @{ error = 'Red'; warn = 'Yellow'; ok = 'Green'; info = 'Gray' }[$Level]
    Write-Host ("[{0}] {1}" -f (Get-Date).ToString('HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture), $Text) -ForegroundColor $col
}
function Add-MonHist([string]$Key, [string]$Name, $Value) {
    if (-not $mon.Hist.ContainsKey($Key)) { $mon.Hist[$Key] = @{} }
    $h = $mon.Hist[$Key]
    if (-not $h.ContainsKey($Name)) { $h[$Name] = New-MonList }
    $h[$Name].Add($Value)
    if ($h[$Name].Count -gt 60) { $h[$Name].RemoveAt(0) }
}
function Get-MonHist([string]$Key, [string]$Name) {
    if ($mon.Hist.ContainsKey($Key) -and $mon.Hist[$Key].ContainsKey($Name)) { return , $mon.Hist[$Key][$Name].ToArray() }
    return , @()
}

# Static model: subscriptions, Log Readers, servers to query and how agent sessions are recognised
function New-MonModel {
    $mon.Subs = New-MonList; $mon.Lrs = New-MonList; $mon.SubByKey = @{}; $mon.LrByKey = @{}
    $mon.AgentKey = @{}; $mon.AgentByName = @{}; $mon.ByName = @{}; $mon.Targets = [ordered]@{}
    $mon.Raw = @{}; $mon.Pending = @{}; $mon.Hist = @{}; $mon.Prev = @{}; $mon.Rate = @{}; $mon.ErrLast = @{}
    $mon.WaitPrev = @{}; $mon.Waits = @{}; $mon.SessPrev = @{}; $mon.AgentWaits = @{}; $mon.Events = New-MonList; $mon.Errors = New-MonList
    $mon.Deferred = New-MonList; $mon.Seq = 0; $mon.JsonSeq = -1; $mon.Json = ''; $mon.Paused = $false; $mon.Interval = $RefreshSeconds
    $mon.Stop = $false; $mon.Ui = 'web'; $mon.Url = ''; $mon.LastFault = ''; $mon.LastDetail = @{}; $mon.Repair = $null; $mon.Skipped = @{}; $mon.Out = @{ Subs = @(); Lrs = @(); Blocking = @(); Sessions = @(); Ag = @() }; $mon.LastLine = ''; $mon.LastLineAt = [datetime]::MinValue
    $typeNum = @{ Transactional = 0; P2P = 0; Snapshot = 1; Merge = 2 }
    $sqlNames = New-Object 'System.Collections.Generic.HashSet[string]'

    foreach ($a in $agents) {
        $k = "$($a.DistInst)|$(([string]$a.DistDb).ToUpperInvariant())|$($a.kind)|$($a.agent_id)"
        $lbl = "$($a.kind) agent $($a.name)"
        if ($a.kind -eq 'S') { $lbl = "Snapshot Agent $($a.publisher)/$($a.publisher_db) $($a.publication)" }
        $mon.AgentKey[$k] = @{ k = ''; lbl = $lbl }
        if ($a.name) { $mon.AgentByName["$($a.DistInst)|$(([string]$a.name).ToUpperInvariant())"] = $k }
    }
    foreach ($k in @($logReaderIdx.Keys | Sort-Object)) {
        $lr = $logReaderIdx[$k]
        $pub = Get-Canon (Resolve-Name (Get-NormName ([string]$lr.publisher))) ([string]$lr.publisher_db)
        $jobKey = ''; $cont = $false
        if ($lr.job_id) {
            $jk = "$($lr.DistInst)|$(([string]$lr.job_id).ToUpperInvariant())"
            if ($jobIdx.ContainsKey($jk)) { $jobKey = $jk; $cont = [bool]$jobIdx[$jk].Continuous }
        }
        $agName = ''
        if ($agByListener.ContainsKey($pub)) { $agName = $agByListener[$pub] }
        $o = [pscustomobject]@{
            Key = $k; DistInst = $lr.DistInst; DistDb = [string]$lr.DistDb; DbKey = "$($lr.DistInst)|$(([string]$lr.DistDb).ToUpperInvariant())"
            AgentId = [string]$lr.agent_id; Publisher = $pub; PubDb = [string]$lr.publisher_db; PubInsts = @(Get-Instances $pub)
            JobKey = $jobKey; JobContinuous = $cont; Ag = $agName; Label = "Log Reader $pub/$($lr.publisher_db)"
        }
        $mon.Lrs.Add($o); $mon.LrByKey[$k] = $o
        $mon.AgentKey["$($o.DbKey)|L|$($o.AgentId)"] = @{ k = $k; lbl = $o.Label }
    }
    foreach ($e in @($edges | Where-Object { $_.SubServer -and $_.Change -ne 'removed' } | Sort-Object PubServer, PubDb, Publication, SubServer, SubDb)) {
        $lrKey = ''
        if ($e.PubType -eq 'Transactional' -or $e.PubType -eq 'P2P') {
            $lk = "$($e.DistributorInstance)|$(Get-NormName $e.PubServerRaw)|$($e.PubDb.ToUpperInvariant())"
            if ($mon.LrByKey.ContainsKey($lk)) { $lrKey = $lk }
        }
        $agentName = ''
        if ($agentIdx.ContainsKey("$($e.DistributorInstance)|D|$($e.AgentId)")) { $agentName = [string]$agentIdx["$($e.DistributorInstance)|D|$($e.AgentId)"].name }
        $o = [pscustomobject]@{
            Key = $e.Key; Edge = $e; LrKey = $lrKey; DistInst = $e.DistributorInstance; DistDb = $e.DistributionDb
            DbKey = "$($e.DistributorInstance)|$($e.DistributionDb.ToUpperInvariant())"
            HKey = ("$($e.PubServerRaw)|$($e.PubDb)|$($e.Publication)|$($e.SubServerRaw)|$($e.SubDb)").ToUpperInvariant()
            AgentId = [string]$e.AgentId; AgentName = $agentName; JobKey = [string]$e.JobKey; JobContinuous = [bool]$e.JobContinuous
            SubName = "$($e.PubServerRaw)_$($e.PubDb)_$($e.Publication)"; SubInsts = @(Get-Instances $e.SubServer)
            Label = "$($e.Publication): $($e.PubServer)/$($e.PubDb) -> $($e.SubServer)/$($e.SubDb)"
            Notes = (@(([string]$e.Problem) -split ', ' | Where-Object { $_ -and $_ -notmatch $transientRx }) -join ', ')
        }
        $mon.Subs.Add($o); $mon.SubByKey[$o.Key] = $o
        if ($o.AgentId) { $mon.AgentKey["$($o.DbKey)|D|$($o.AgentId)"] = @{ k = $o.Key; lbl = $o.Label } }
        foreach ($pair in @(@($agentName, 'distributor', ''), @($o.SubName, 'subscriber', $e.SubDb.ToUpperInvariant()))) {
            if (-not $pair[0]) { continue }
            [void]$sqlNames.Add($pair[0])
            $u = $pair[0].ToUpperInvariant()
            if (-not $mon.ByName.ContainsKey($u)) { $mon.ByName[$u] = New-MonList }
            $mon.ByName[$u].Add(@{ Key = $o.Key; Side = $pair[1]; Db = $pair[2]; Insts = $o.SubInsts })
        }
    }

    # Servers to query: distributors (agent state, errors, pending) and every visited server (sessions, waits, AG, jobs)
    foreach ($inst in @(@($mon.Subs | ForEach-Object { $_.DistInst }) + @($mon.Lrs | ForEach-Object { $_.DistInst }) + @($serverInfo.Keys | Sort-Object))) {
        if (-not $inst -or $mon.Targets.Contains($inst)) { continue }
        $target = Get-Target $inst
        if (-not $connectFor.ContainsKey($inst)) {
            # A replica reached only through its AG listener is queried the same way (the answer is checked by name)
            foreach ($ln in $listenerInst.Keys) { if ($listenerInst[$ln] -eq $inst -and $connectFor.ContainsKey($ln)) { $target = $connectFor[$ln] } }
        }
        $t = @{ Name = $inst; Target = $target; Dist = [ordered]@{}; Sessions = $false; Ag = $false; Jobs = $false
                PS = $null; Handle = $null; Next = [datetime]::MinValue; Started = $null; Cycle = 0; Took = $null; Ok = $null; Err = ''
                At = ''; Notes = @(); PendingNow = $false; PendingFresh = $false }
        if ($serverInfo.ContainsKey($inst)) {
            $i = $serverInfo[$inst]
            $t.Sessions = [bool]$i.ViewServerState; $t.Ag = ([bool]$i.Hadr -and $t.Sessions); $t.Jobs = ($null -ne $i.Jobs -and $i.Jobs.Count -gt 0)
            if (-not $t.Sessions) { $t.Notes = @("Sessions, blocking, waits and AG state on $inst : the login needs VIEW SERVER STATE") }
        }
        $mon.Targets[$inst] = $t
    }
    foreach ($s in $mon.Subs) {
        $d = $mon.Targets[$s.DistInst].Dist
        if (-not $d.Contains($s.DistDb)) { $d[$s.DistDb] = New-Object 'System.Collections.Generic.HashSet[string]' }
        [void]$d[$s.DistDb].Add("$($s.Edge.PubServerRaw)|$($typeNum[$s.Edge.PubType])")
    }
    foreach ($l in $mon.Lrs) {
        $d = $mon.Targets[$l.DistInst].Dist
        if (-not $d.Contains($l.DistDb)) { $d[$l.DistDb] = New-Object 'System.Collections.Generic.HashSet[string]' }
    }
    $inList = (@($sqlNames | ForEach-Object { "N'" + ($_ -replace "'", "''") + "'" }) -join ', ')
    if (-not $inList) { $inList = "N''" }
    # The publisher part of that name is not certain for every server name form (named instances), so the
    # end of the name is matched as well: '%_<publisher db>_<publication>'
    $mon.BySuffix = @{}
    $likes = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($sub in $mon.Subs) {
        $suffixRaw = "_$($sub.Edge.PubDb)_$($sub.Edge.Publication)"
        $suffix = $suffixRaw.ToUpperInvariant()
        if (-not $mon.BySuffix.ContainsKey($suffix)) { $mon.BySuffix[$suffix] = New-MonList }
        $mon.BySuffix[$suffix].Add($sub)
        $pat = ($suffixRaw -replace '\[', '[[]' -replace '%', '[%]' -replace '_', '[_]') -replace "'", "''"
        [void]$likes.Add("s.program_name LIKE N'%$pat'")
    }
    $likeSql = ''
    if ($likes.Count) { $likeSql = ' OR ' + (@($likes) -join ' OR ') }
    $mon.SessionSql = $q.LiveSessions.Replace('{NAMES}', $inList).Replace('{LIKES}', $likeSql)
    $mon.Opt = $opt.Clone()
    $mon.Opt.QueryTimeout = [Math]::Min($QueryTimeout, 60)
}

# Which replication agent a session belongs to (program name; for subscriber connections also the database)
function Get-SessionAgent([string]$Srv, $Sess) {
    $pn = [string]$Sess.program_name
    $db = ([string]$Sess.db).ToUpperInvariant()
    if ($pn -match '^Repl-LogReader-\d+-(.+)-\d+$') {
        $pdb = $Matches[1].ToUpperInvariant()
        $c = @($mon.Lrs | Where-Object { $_.PubDb.ToUpperInvariant() -eq $pdb })
        if ($c.Count -gt 1) {
            $c2 = @($c | Where-Object { $_.DistInst -eq $Srv -or $_.PubInsts -contains $Srv })
            if ($c2.Count) { $c = $c2 }
        }
        if (-not $c.Count) { return $null }
        $side = 'publisher'
        if ($db -ne $pdb) { $side = 'distributor' }
        return @{ Key = $c[0].Key; Side = $side; Label = $c[0].Label }
    }
    $u = $pn.ToUpperInvariant()
    if (-not $mon.ByName.ContainsKey($u)) {
        # subscriber side by the end of the program name, on one of the subscriber's instances
        $best = $null
        foreach ($suffix in $mon.BySuffix.Keys) {
            if (-not $u.EndsWith($suffix)) { continue }
            foreach ($sub in $mon.BySuffix[$suffix]) {
                if ($sub.SubInsts -notcontains $Srv) { continue }
                if ($sub.Edge.SubDb.ToUpperInvariant() -eq $db) { return @{ Key = $sub.Key; Side = 'subscriber'; Label = $sub.Label } }
                if (-not $best) { $best = $sub }
            }
        }
        if ($best) { return @{ Key = $best.Key; Side = 'subscriber'; Label = $best.Label } }
        return $null
    }
    $best = $null
    foreach ($x in $mon.ByName[$u]) {
        if ($x.Side -eq 'distributor') { return @{ Key = $x.Key; Side = 'distributor'; Label = $mon.SubByKey[$x.Key].Label } }
        if ($x.Insts -contains $Srv) {
            if ($x.Db -eq $db) { return @{ Key = $x.Key; Side = 'subscriber'; Label = $mon.SubByKey[$x.Key].Label } }
            if (-not $best) { $best = $x }
        }
    }
    if ($best) { return @{ Key = $best.Key; Side = 'subscriber'; Label = $mon.SubByKey[$best.Key].Label } }
    return $null
}

function Start-LiveJob($t) {
    $t.Cycle++
    $pend = ($t.Cycle -eq 1) -or (($t.Cycle - 1) % $PendingEvery -eq 0) -or $t.PendingNow
    $t.PendingNow = $false
    $dist = @(foreach ($db in $t.Dist.Keys) {
        $ek = "$($t.Name)|$($db.ToUpperInvariant())"
        $last = -1
        if ($mon.ErrLast.ContainsKey($ek)) { $last = $mon.ErrLast[$ek] }
        @{ Db = $db; Pairs = @($t.Dist[$db]); Pending = $pend; LastErr = $last }
    })
    $task = @{ Kind = 'live'; Dist = $dist; SessionSql = ''; Ag = $t.Ag; Jobs = $t.Jobs }
    if ($t.Sessions) { $task.SessionSql = $mon.SessionSql }
    $ps = [powershell]::Create()
    $ps.RunspacePool = $mon.Pool
    [void]$ps.AddScript($collectText).AddArgument($t.Target).AddArgument($mon.Opt).AddArgument($task)
    $t.PS = $ps; $t.Handle = $ps.BeginInvoke(); $t.Started = Get-Date
    $t.Next = $t.Started.AddSeconds($mon.Interval)
}
function Complete-MonJob($Ps, $Handle) {
    $r = $null
    try {
        $out = $Ps.EndInvoke($Handle)
        if ($out.Count -gt 0) { $r = $out[0] }
    } catch { $r = [pscustomobject]@{ Error = $_.Exception.Message; ErrorNumber = 0; Probe = '' } }
    if (-not $r) {
        $msg = @($Ps.Streams.Error | ForEach-Object { $_.ToString() }) -join ' '
        $r = [pscustomobject]@{ Error = "No result. $msg"; ErrorNumber = 0; Probe = '' }
    }
    $Ps.Dispose()
    return $r
}

# Commands per second between two history entries of an agent (wall clock). The agent's own
# delivery_rate is the speed while it works (a 200-command batch in 20 ms = 10000/s), not the flow.
function Get-FlowRate([string]$Key, $Row, [string]$CmdCol, [bool]$PerSession, $Age) {
    if (-not $Row -or -not ($Row.time -is [datetime])) { return $null }
    $cmds = $Row.$CmdCol
    $prev = $null
    if ($mon.Rate.ContainsKey($Key)) { $prev = $mon.Rate[$Key] }
    if (-not $prev -or (Format-Dt $prev.time) -ne (Format-Dt $Row.time)) {
        $rate = $null
        if ($prev -and $null -ne $cmds -and $null -ne $prev.cmds -and (-not $PerSession -or (Format-Dt $prev.start) -eq (Format-Dt $Row.start_time))) {
            $sec = ($Row.time - $prev.time).TotalSeconds
            if ($sec -gt 0) { $rate = [math]::Round([math]::Max(0, ([double]$cmds - [double]$prev.cmds) / $sec), 1) }
        }
        $prev = @{ time = $Row.time; start = $Row.start_time; cmds = $cmds; rate = $rate }
        $mon.Rate[$Key] = $prev
    }
    if ($Row.runstatus -ne 3 -or $null -eq $Age -or $Age -gt 90) { return 0 }   # idle, stopped or silent agent delivers nothing
    return $prev.rate
}

# One server answered: connection state, new replication errors, waits since the previous sample
function Add-LiveResult($t, $r) {
    $name = $t.Name
    $was = $t.Ok
    $t.At = (Get-Date).ToString('HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
    $real = $null
    if (-not $r.Error) { $real = Resolve-Name (Get-NormName ([string]$r.SrvName)) }
    if ($r.Error -or ($real -and $real -ne $name)) {
        if ($r.Error) { $t.Err = Get-ConnHint $r $t.Target }
        else { $t.Err = "$($t.Target) now leads to $real, not to $name" }   # e.g. an AG listener after a failover: do not mix the servers up
        $t.Ok = $false
        if ($was -ne $false) { Add-MonEvent 'error' "Cannot query $name : $($t.Err)" }
        # its last answer is no longer true: no stale health, sessions, waits or pending counts
        $mon.Raw.Remove($name); $mon.Waits.Remove($name); $mon.WaitPrev.Remove($name)
        foreach ($k in @($mon.Pending.Keys | Where-Object { $_.StartsWith("$name|") })) { $mon.Pending.Remove($k) }
        return
    }
    if ($was -eq $false) { Add-MonEvent 'ok' "$name answers again" }
    $t.Ok = $true; $t.Err = ''
    $L = $r.Live
    $t.Notes = @(@($t.Notes | Where-Object { $_ -like 'Sessions, blocking*' }) + $L.Notes.ToArray())   # the permission note stays
    $now = Get-Date

    # Pending commands are counted every -PendingEvery cycles; the last count is kept in between
    foreach ($db in $L.PendingDbs) {
        $dk = "$name|$($db.ToUpperInvariant())"
        foreach ($k in @($mon.Pending.Keys | Where-Object { $_ -like "$dk|*" })) { $mon.Pending.Remove($k) }
    }
    foreach ($p in $L.Pending) { $mon.Pending["$name|$(([string]$p.Db).ToUpperInvariant())|$($p.agent_id)"] = $p }
    $t.PendingFresh = ($L.PendingDbs.Count -gt 0)

    # Replication errors: MSrepl_errors rows grouped per error event, the agent from history or from the text
    $first = @{}
    foreach ($db in @($L.ErrMax.Keys)) {
        $ek = "$name|$($db.ToUpperInvariant())"
        $first[$db.ToUpperInvariant()] = -not $mon.ErrLast.ContainsKey($ek)
        $max = $L.ErrMax[$db]
        $got = @($L.Errors | Where-Object { ([string]$_.Db).ToUpperInvariant() -eq $db.ToUpperInvariant() } | ForEach-Object { [int]$_.id })
        $last = -1
        if ($mon.ErrLast.ContainsKey($ek)) { $last = $mon.ErrLast[$ek] }
        if ($got.Count) { $last = [Math]::Max($last, ($got | Measure-Object -Maximum).Maximum) }
        if ($first[$db.ToUpperInvariant()] -or -not $got.Count) { if ($null -ne $max) { $last = [Math]::Max($last, [int]$max) } }
        $mon.ErrLast[$ek] = [int]$last
    }
    $map = @{}
    foreach ($m in $L.ErrMap) { $map["$(([string]$m.Db).ToUpperInvariant())|$($m.error_id)"] = $m }
    $cur = $null; $added = 0
    $groups = [ordered]@{}
    foreach ($row in $L.Errors) {
        $gk = "$(([string]$row.Db).ToUpperInvariant())|$($row.id)"
        if (-not $groups.Contains($gk)) { $groups[$gk] = New-MonList }
        $groups[$gk].Add($row)
    }
    foreach ($gk in @($groups.Keys)) {
        $g = @{ Name = $gk }
        $rows = $groups[$gk]; $r0 = $rows[0]; $dbU = ([string]$r0.Db).ToUpperInvariant()
        $text0 = [string]$r0.error_text
        $agentK = ''
        if ($map.ContainsKey($g.Name)) { $agentK = "$name|$dbU|$($map[$g.Name].kind)|$($map[$g.Name].agent_id)" }
        elseif ($text0 -match 'agent (\S+) (failed|scheduled for retry)' -and $mon.AgentByName.ContainsKey("$name|$($Matches[1].ToUpperInvariant())")) { $agentK = $mon.AgentByName["$name|$($Matches[1].ToUpperInvariant())"] }
        if (-not $agentK) {
            # the details of an error come under the next id - also when the error itself came with the previous refresh
            $prev = $null
            if ($cur -and $cur.db -eq $dbU -and [int]$r0.id -eq ($cur.id + 1)) { $prev = $cur }
            else { foreach ($x in $mon.Errors) { if ($x.srv -eq $name -and $x.db -eq $dbU -and $x.id -eq ([int]$r0.id - 1)) { $prev = $x; break } } }
            if ($prev -and ($r0.time - $prev.time0).TotalSeconds -le 2) {
                foreach ($x in $rows) { $prev.more.Add("$($x.error_code): $([string]$x.error_text)") }
                continue
            }
        }
        $who = @{ k = ''; lbl = 'unknown agent' }
        if ($agentK -and $mon.AgentKey.ContainsKey($agentK)) { $who = $mon.AgentKey[$agentK] }
        $cur = [ordered]@{ id = [int]$r0.id; key = "$name|$dbU|$($r0.id)"; t = (Format-Dt $r0.time); srv = $name; db = [string]$r0.Db
                           k = $who.k; lbl = $who.lbl; code = $r0.error_code; m = $text0; more = (New-MonList); seq = ''; cmd = $null
                           agent = ''; time0 = $r0.time }
        if ($agentK) { $cur.agent = ($agentK -split '\|')[-1] }
        for ($i = 1; $i -lt $rows.Count; $i++) { $cur.more.Add("$($rows[$i].error_code): $([string]$rows[$i].error_text)") }
        foreach ($x in $rows) {
            $sq = [string]$x.xact_seqno
            if ($sq -and $sq -notmatch '^0x0+$' -and -not $cur.seq) { $cur.seq = $sq; if ($null -ne $x.command_id -and [int]$x.command_id -gt 0) { $cur.cmd = [int]$x.command_id } }
        }
        $mon.Errors.Insert(0, $cur); $added++
        if (-not $first[$dbU]) {
            $msg = ($text0 -replace '\s+', ' ').Trim()
            if ($msg.Length -gt 160) { $msg = $msg.Substring(0, 160) + '...' }
            Add-MonEvent 'error' "Replication error $($r0.error_code) - $($who.lbl): $msg" $who.k
        }
    }
    if ($added) {
        # newest first across distribution databases
        $sorted = @($mon.Errors | Sort-Object { $_.time0 } -Descending)
        $mon.Errors.Clear()
        foreach ($x in $sorted) { $mon.Errors.Add($x) }
    }
    while ($mon.Errors.Count -gt 300) { $mon.Errors.RemoveAt($mon.Errors.Count - 1) }

    # Waits of the server and of every agent session since the previous sample
    if ($L.WaitsOk) {
        $cw = @{}
        foreach ($w in $L.Waits) { $cw[[string]$w.wait_type] = @([double]$w.wait_time_ms, [double]$w.waiting_tasks_count) }
        if ($mon.WaitPrev.ContainsKey($name)) {
            $p = $mon.WaitPrev[$name]; $sec = ($now - $p.T).TotalSeconds
            $top = @(@(foreach ($k in $cw.Keys) {
                $d = $cw[$k][0]; $n = $cw[$k][1]
                if ($p.W.ContainsKey($k)) { $d -= $p.W[$k][0]; $n -= $p.W[$k][1] }
                if ($d -gt 0) { [ordered]@{ w = $k; ms = [math]::Round($d); n = [math]::Max(0, $n) } }
            }) | Sort-Object { $_.ms } -Descending | Select-Object -First 10)
            $mon.Waits[$name] = [ordered]@{ srv = $name; sec = [math]::Round($sec, 1); top = $top }
        }
        $mon.WaitPrev[$name] = @{ T = $now; W = $cw }
        $sw = @{}
        foreach ($w in $L.SessWaits) {
            $sid = [int]$w.session_id
            if (-not $sw.ContainsKey($sid)) { $sw[$sid] = @{} }
            $sw[$sid][[string]$w.wait_type] = [double]$w.wait_time_ms
        }
        $seen = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($s in $L.Sessions) {
            if ([int]$s.lvl -ne 0) { continue }
            $sid = [int]$s.session_id
            $ag = Get-SessionAgent $name $s
            if (-not $ag -or -not $sw.ContainsKey($sid)) { continue }
            $idk = "$name|$sid|$(Format-Dt $s.login_time)"
            [void]$seen.Add($idk)
            if ($mon.SessPrev.ContainsKey($idk)) {
                if (-not $mon.AgentWaits.ContainsKey($ag.Key)) { $mon.AgentWaits[$ag.Key] = @{ total = @{}; last = @{}; at = '' } }
                $aw = $mon.AgentWaits[$ag.Key]
                if ($aw.at -ne $t.At) { $aw.last = @{}; $aw.at = $t.At }
                foreach ($k in $sw[$sid].Keys) {
                    $d = $sw[$sid][$k]
                    if ($mon.SessPrev[$idk].ContainsKey($k)) { $d -= $mon.SessPrev[$idk][$k] }
                    if ($d -le 0) { continue }
                    if (-not $aw.total.ContainsKey($k)) { $aw.total[$k] = 0 }
                    if (-not $aw.last.ContainsKey($k)) { $aw.last[$k] = 0 }
                    $aw.total[$k] += $d; $aw.last[$k] += $d
                }
            }
            $mon.SessPrev[$idk] = $sw[$sid]
        }
        foreach ($k in @($mon.SessPrev.Keys | Where-Object { $_.StartsWith("$name|") -and -not $seen.Contains($_) })) { $mon.SessPrev.Remove($k) }
    }
    $mon.Raw[$name] = $L
}

# Everything the page shows, rebuilt after each server answers
function Update-MonModel([string]$From) {
    $hIdx = @{}; $aIdx = @{}; $jIdx = @{}; $jobsOk = @{}; $sessByKey = @{}
    $blocking = New-MonList; $sessRows = New-MonList; $agRows = [ordered]@{}
    foreach ($tn in $mon.Raw.Keys) {
        $raw = $mon.Raw[$tn]
        foreach ($x in $raw.Subs) { $hIdx["$tn|$(([string]$x.Db).ToUpperInvariant())|$($x.Key)"] = $x }
        foreach ($x in $raw.Agents) { $aIdx["$tn|$(([string]$x.Db).ToUpperInvariant())|$($x.kind)|$($x.agent_id)"] = $x }
        if ($raw.JobsOk) { $jobsOk[$tn] = $true }
        foreach ($x in $raw.Jobs) { $jIdx["$tn|$(([string]$x.job_id).ToUpperInvariant())"] = $x }
        foreach ($x in $raw.Ag) {
            $k = "$($x.ag_name)|$($x.replica)|$($x.db)".ToUpperInvariant()
            if (-not $agRows.Contains($k) -or ($x.my_role -eq 'PRIMARY' -and $agRows[$k].my_role -ne 'PRIMARY')) { $agRows[$k] = $x }
        }
        # Agent sessions, who blocks them (the head of the chain) and whom they block
        $byId = @{}
        foreach ($x in $raw.Sessions) { $byId[[int]$x.session_id] = $x }
        foreach ($x in $raw.Sessions) {
            $lvl = [int]$x.lvl
            $sid = [int]$x.session_id
            if ($lvl -eq -1) {
                $b = $byId[[int]$x.blocking_session_id]
                $ag = $null
                if ($b) { $ag = Get-SessionAgent $tn $b }
                $lbl = ''
                if ($ag) { $lbl = $ag.Label }
                $blocking.Add([ordered]@{ srv = $tn; spid = $sid; k = ''; lbl = "$($x.program_name) ($($x.host_name), $($x.login_name))"; w = [string]$x.wait_type; ms = $x.wait_time
                                          res = [string]$x.wait_resource; by = [int]$x.blocking_session_id; chain = ''; agentBlocks = $true; byLbl = $lbl
                                          hProg = ''; hHost = ''; hLogin = ''; hDb = ''; hSt = ''; hTran = $null; hCmd = ''; hSql = (([string]$x.sql_text) -replace '\s+', ' ').Trim(); hJob = '' })
                continue
            }
            if ($lvl -ne 0) { continue }
            $ag = Get-SessionAgent $tn $x
            $row = [ordered]@{ srv = $tn; spid = $sid; k = ''; lbl = [string]$x.program_name; side = ''; st = [string]$x.status; req = [string]$x.req_status
                               cmd = [string]$x.command; w = [string]$x.wait_type; ms = $x.wait_time; blk = $x.blocking_session_id; cpu = $x.cpu_time
                               rd = $x.reads; wr = $x.writes; lr = $x.logical_reads; tran = $x.open_transaction_count; db = [string]$x.db; host = [string]$x.host_name
                               last = (Format-Dt $x.last_request_start_time); sql = (([string]$x.sql_text) -replace '\s+', ' ').Trim() }
            if ($row.sql.Length -gt 600) { $row.sql = $row.sql.Substring(0, 600) + '...' }
            if ($ag) {
                $row.k = $ag.Key; $row.lbl = $ag.Label; $row.side = $ag.Side
                if (-not $sessByKey.ContainsKey($ag.Key)) { $sessByKey[$ag.Key] = New-MonList }
                $sessByKey[$ag.Key].Add($row)
            }
            $sessRows.Add($row)
            if ($x.blocking_session_id -and [int]$x.blocking_session_id -gt 0) {
                $chain = New-Object System.Collections.Generic.List[int]
                $c = [int]$x.blocking_session_id
                while ($chain.Count -lt 20) {
                    $chain.Add($c)
                    if (-not $byId.ContainsKey($c)) { break }
                    $nb = $byId[$c].blocking_session_id
                    if (-not $nb -or [int]$nb -le 0 -or $chain.Contains([int]$nb)) { break }
                    $c = [int]$nb
                }
                $h = $null
                if ($byId.ContainsKey($chain[$chain.Count - 1])) { $h = $byId[$chain[$chain.Count - 1]] }
                $res = [string]$x.wait_resource
                if ($x.wait_object) { $res = "$($x.wait_object) ($res)" }
                $e = [ordered]@{ srv = $tn; spid = $sid; k = $row.k; lbl = $row.lbl; w = [string]$x.wait_type; ms = $x.wait_time; res = $res
                                 by = $chain[0]; chain = ((@($sid) + $chain.ToArray()) -join ' <- '); agentBlocks = $false; byLbl = ''
                                 hProg = ''; hHost = ''; hLogin = ''; hDb = ''; hSt = ''; hTran = $null; hCmd = ''; hSql = ''; hJob = '' }
                if ($h) {
                    $e.hProg = [string]$h.program_name; $e.hHost = [string]$h.host_name; $e.hLogin = [string]$h.login_name; $e.hDb = [string]$h.db
                    $e.hSt = [string]$h.status; $e.hTran = $h.open_transaction_count; $e.hCmd = [string]$h.command; $e.hJob = [string]$h.job_name
                    $e.hSql = (([string]$h.sql_text) -replace '\s+', ' ').Trim()
                    if ($e.hSql.Length -gt 1000) { $e.hSql = $e.hSql.Substring(0, 1000) + '...' }
                    $hag = Get-SessionAgent $tn $h
                    if ($hag) { $e.byLbl = $hag.Label }
                }
                $blocking.Add($e)
            }
        }
    }

    # Availability groups: lag of every secondary behind its primary
    $agOut = New-MonList
    foreach ($x in $agRows.Values) {
        $prim = $null
        foreach ($y in $agRows.Values) { if ($y.ag_name -eq $x.ag_name -and $y.db -eq $x.db -and $y.role -eq 'PRIMARY') { $prim = $y } }
        $lvl = 'ok'; $p = New-Object System.Collections.Generic.List[string]
        $isPrim = ($x.role -eq 'PRIMARY')
        if (-not $isPrim -and $x.connected -and $x.connected -ne 'CONNECTED') { $lvl = 'error'; $p.Add('DISCONNECTED') }
        if ($x.suspended -eq 1) { $lvl = 'error'; $p.Add("SUSPENDED $($x.suspend_reason)") }
        if ($x.sync_state -eq 'NOT SYNCHRONIZING') { $lvl = 'error'; $p.Add('NOT SYNCHRONIZING') }
        elseif ($x.mode -eq 'SYNCHRONOUS_COMMIT' -and -not $isPrim -and $x.sync_state -ne 'SYNCHRONIZED') { $lvl = Get-Worse $lvl 'warn'; $p.Add([string]$x.sync_state) }
        if ($x.db_health -eq 'NOT_HEALTHY') { $lvl = 'error' } elseif ($x.db_health -eq 'PARTIALLY_HEALTHY') { $lvl = Get-Worse $lvl 'warn' }
        if ($x.send_queue_kb -gt 102400) { $lvl = Get-Worse $lvl 'warn'; $p.Add("SEND QUEUE $([math]::Round($x.send_queue_kb / 1024)) MB") }
        if ($x.redo_queue_kb -gt 102400) { $lvl = Get-Worse $lvl 'warn'; $p.Add("REDO QUEUE $([math]::Round($x.redo_queue_kb / 1024)) MB") }
        $lag = $null
        if (-not $isPrim -and $prim) { $lag = Get-Secs $x.last_commit_time $prim.last_commit_time }
        $agOut.Add([ordered]@{ ag = [string]$x.ag_name; db = [string]$x.db; replica = [string]$x.replica; role = [string]$x.role; mode = [string]$x.mode
                               conn = [string]$x.connected; sync = [string]$x.sync_state; health = [string]$x.db_health; h = $lvl; p = ($p -join ', ')
                               sendKb = $x.send_queue_kb; sendRate = $x.send_rate_kbs; redoKb = $x.redo_queue_kb; redoRate = $x.redo_rate_kbs; lag = $lag
                               last = (Format-Dt $x.last_commit_time) })
    }

    $fresh = $From -and $mon.Targets.Contains($From)
    $agentHot = @{}
    foreach ($b in $blocking) { if ($b.k -and -not $b.agentBlocks -and $b.ms -ge 5000) { $agentHot[$b.k] = $b } }

    # Log Readers
    $lrOut = New-MonList; $lrLevel = @{}
    foreach ($l in $mon.Lrs) {
        $tg = $mon.Targets[$l.DistInst]
        $raw = $null
        if ($mon.Raw.ContainsKey($l.DistInst)) { $raw = $mon.Raw[$l.DistInst] }
        $ar = $aIdx["$($l.DbKey)|L|$($l.AgentId)"]
        $lvl = 'unknown'; $p = New-Object System.Collections.Generic.List[string]; $st = ''
        $lat = $null; $rate = $null; $age = $null; $msg = ''; $cmds = $null; $lastTxt = ''
        if ($ar) {
            $lvl = 'ok'
            if ($null -ne $ar.runstatus) { $st = $runName[[int]$ar.runstatus] }
            if ($ar.runstatus -eq 6) { $lvl = 'error'; $p.Add('FAILED') } elseif ($ar.runstatus -eq 5) { $lvl = 'warn'; $p.Add('RETRYING') }
            if ($null -ne $ar.delivery_latency) { $lat = [math]::Round([double]$ar.delivery_latency / 1000, 1) }
            $age = Get-Secs $ar.time $raw.Now
            $msg = Get-MonStatsText ([string]$ar.comments); $cmds = $ar.delivered_commands; $lastTxt = Format-Dt $ar.time
            $rate = Get-FlowRate $l.Key $ar 'delivered_commands' $true $age
        } elseif ($tg.Ok -eq $false) { $p.Add('DISTRIBUTOR NOT REACHABLE') }
        $job = ''
        if ($l.JobKey) {
            $jSrv = ($l.JobKey -split '\|')[0]
            if ($jIdx.ContainsKey($l.JobKey)) {
                $j = $jIdx[$l.JobKey]
                if (-not $j.enabled) { $job = 'disabled'; $lvl = 'error'; $p.Add('JOB DISABLED') }
                elseif ($j.running) { $job = 'running' }
                else {
                    $job = 'not running'
                    if ($l.JobContinuous) { $lvl = 'error'; $p.Add('NOT RUNNING'); $st = 'Not running' }
                }
            } elseif ($jobsOk.ContainsKey($jSrv)) { $job = 'job missing'; $lvl = Get-Worse $lvl 'warn'; $p.Add('AGENT JOB MISSING') }
        }
        if ($st -in 'Running', 'Idle', 'Started' -and $null -ne $age -and $age -gt 600) { $lvl = Get-Worse $lvl 'warn'; $p.Add("NO PROGRESS $([int]($age / 60)) MIN") }
        $agTxt = ''
        if ($l.Ag) {
            $mine = @($agOut | Where-Object { $_.ag -eq $l.Ag -and $_.db -eq $l.PubDb })
            $prim = @($mine | Where-Object { $_.role -eq 'PRIMARY' } | ForEach-Object { $_.replica })
            $agTxt = "AG $($l.Ag)"
            if ($prim) { $agTxt += ", primary $($prim -join ', ')" }
            foreach ($x in $mine) {
                if ($x.role -ne 'PRIMARY' -and $x.mode -eq 'SYNCHRONOUS_COMMIT' -and ($x.sync -ne 'SYNCHRONIZED' -or ($x.conn -and $x.conn -ne 'CONNECTED'))) {
                    $lvl = Get-Worse $lvl 'warn'
                    $p.Add("AG SECONDARY $($x.replica) $($x.sync) (LOG READER WAITS FOR IT, UNLESS TRACE FLAG 1448)")
                }
            }
        }
        $ses = @()
        if ($sessByKey.ContainsKey($l.Key)) { $ses = $sessByKey[$l.Key].ToArray() }
        $blk = ''
        if ($agentHot.ContainsKey($l.Key)) {
            $b = $agentHot[$l.Key]; $lvl = Get-Worse $lvl 'warn'
            $blk = "blocked $([int]($b.ms / 1000)) s by session $($b.by) on $($b.srv)"
            $p.Add("BLOCKED $([int]($b.ms / 1000)) S")
            if ($null -ne $rate) { $rate = 0 }
        }
        if ($fresh -and $From -eq $l.DistInst) { Add-MonHist $l.Key 'lat' $lat; Add-MonHist $l.Key 'rt' $rate }
        $lrLevel[$l.Key] = @{ h = $lvl; p = ($p -join ', ') }
        $lrOut.Add([ordered]@{ k = $l.Key; h = $lvl; p = ($p -join ', '); st = $st; lat = $lat; lh = (Get-MonHist $l.Key 'lat'); rt = $rate
                               rh = (Get-MonHist $l.Key 'rt'); cmds = $cmds; age = $age; last = $lastTxt; msg = $msg; job = $job
                               ag = $agTxt; ses = $ses; blk = $blk; wt = (Get-MonWait $ses) })
    }

    # Subscriptions
    $subOut = New-MonList
    foreach ($s in $mon.Subs) {
        $tg = $mon.Targets[$s.DistInst]
        $raw = $null
        if ($mon.Raw.ContainsKey($s.DistInst)) { $raw = $mon.Raw[$s.DistInst] }
        $hr = $hIdx["$($s.DbKey)|$($s.HKey)"]
        $agentId = $s.AgentId
        if ($hr -and $hr.AgentId) {
            $agentId = [string]$hr.AgentId
            if (-not $mon.AgentKey.ContainsKey("$($s.DbKey)|D|$agentId")) { $mon.AgentKey["$($s.DbKey)|D|$agentId"] = @{ k = $s.Key; lbl = $s.Label } }
        }
        $s.AgentId = $agentId
        $ar = $aIdx["$($s.DbKey)|D|$agentId"]
        $lvl = 'unknown'; $p = New-Object System.Collections.Generic.List[string]; $st = ''
        if ($hr) { $lvl = $hr.Level; foreach ($x in $hr.Problems) { $p.Add($x) }; $st = $hr.AgentStatus }
        elseif ($tg.Ok -eq $false) { $p.Add('DISTRIBUTOR NOT REACHABLE') }
        if ($st -eq 'In progress') { $st = 'Running' }
        $lat = $null; $rate = $null; $age = $null; $msg = ''; $last = ''
        if ($hr) { $lat = $hr.Latency; $last = $hr.LastSync }
        if ($ar) {
            if ($null -eq $lat -and $null -ne $ar.current_delivery_latency) { $lat = [math]::Round([double]$ar.current_delivery_latency / 1000, 1) }
            $age = Get-Secs $ar.time $raw.Now
            $rate = Get-FlowRate $s.Key $ar 'total_delivered_commands' $false $age
            $msg = Get-MonStatsText ([string]$ar.comments)
            if (-not $st -and $null -ne $ar.runstatus) { $st = $runName[[int]$ar.runstatus] }
        }
        $job = ''
        if ($s.JobKey) {
            $jSrv = ($s.JobKey -split '\|')[0]
            if ($jIdx.ContainsKey($s.JobKey)) {
                $j = $jIdx[$s.JobKey]
                if (-not $j.enabled) {
                    $job = 'disabled'
                    if ($s.JobContinuous) { $lvl = 'error' } else { $lvl = Get-Worse $lvl 'warn' }
                    $p.Add('AGENT JOB DISABLED')
                } elseif ($j.running) { $job = 'running' }
                else {
                    $job = 'not running'
                    if ($s.JobContinuous) { $st = 'Not running'; $lvl = Get-Worse $lvl 'warn'; $p.Add('AGENT NOT RUNNING') }
                }
            } elseif ($jobsOk.ContainsKey($jSrv)) { $job = 'job missing'; $lvl = Get-Worse $lvl 'warn'; $p.Add('AGENT JOB MISSING') }
        }
        $pd = $null; $eta = $null; $old = $null
        $pk = "$($s.DbKey)|$agentId"
        if ($mon.Pending.ContainsKey($pk)) {
            $pr = $mon.Pending[$pk]
            $pd = [long]$pr.pending
            if ($pd -gt 0) {
                if ($pr.rate -gt 0) { $eta = [int]($pd / [double]$pr.rate) }
                $old = Get-Secs $pr.oldest_entry $pr.now
            }
            if ($pd -ge $PendingWarn) { $lvl = Get-Worse $lvl 'warn'; $p.Add("PENDING $pd") }
            if ($s.JobContinuous -and $null -ne $old -and $old -ge 300) {
                $lv2 = 'warn'
                if ($old -ge 1800) { $lv2 = 'error' }
                $lvl = Get-Worse $lvl $lv2; $p.Add("OLDEST PENDING $([int]($old / 60)) MIN")
            }
            if ($pd -gt 0 -and $p -contains 'AGENT NOT RUNNING') { $lvl = 'error' }
        }
        if ($st -in 'Running', 'Idle', 'Started' -and $null -ne $age -and $age -gt 600 -and $job -ne 'not running') { $lvl = Get-Worse $lvl 'warn'; $p.Add("NO PROGRESS $([int]($age / 60)) MIN") }
        if ($s.LrKey -and $lrLevel.ContainsKey($s.LrKey) -and $lrLevel[$s.LrKey].h -eq 'error') {
            $lvl = 'error'; $p.Add("LOG READER: $($lrLevel[$s.LrKey].p)")
        }
        $ses = @()
        if ($sessByKey.ContainsKey($s.Key)) { $ses = $sessByKey[$s.Key].ToArray() }
        $blk = ''
        if ($agentHot.ContainsKey($s.Key)) {
            $b = $agentHot[$s.Key]; $lvl = Get-Worse $lvl 'warn'
            $who = "session $($b.by)"
            if ($b.hProg) { $who += " ($($b.hProg), $($b.hHost))" }
            $blk = "blocked $([int]($b.ms / 1000)) s by $who on $($b.srv)"
            $p.Add("BLOCKED $([int]($b.ms / 1000)) S ON $($b.srv)")
            if ($null -ne $rate) { $rate = 0 }
        }
        if ($fresh -and $From -eq $s.DistInst) {
            Add-MonHist $s.Key 'lat' $lat; Add-MonHist $s.Key 'rt' $rate
            if ($tg.PendingFresh) { Add-MonHist $s.Key 'pd' $pd }
        }
        $subOut.Add([ordered]@{ k = $s.Key; h = $lvl; p = ($p -join ', '); st = $st; lat = $lat; lh = (Get-MonHist $s.Key 'lat'); pd = $pd
                                ph = (Get-MonHist $s.Key 'pd'); eta = $eta; old = $old; rt = $rate; rh = (Get-MonHist $s.Key 'rt'); last = $last
                                age = $age; msg = $msg; job = $job; ses = $ses; blk = $blk; wt = (Get-MonWait $ses); agent = $agentId })
    }

    # State changes become events (the first sample of each item only sets the baseline)
    foreach ($x in ($lrOut.ToArray() + $subOut.ToArray())) {
        $lbl = ''
        if ($mon.SubByKey.ContainsKey($x.k)) { $lbl = $mon.SubByKey[$x.k].Label } else { $lbl = $mon.LrByKey[$x.k].Label }
        if ($x.h -eq 'unknown') { continue }
        if ($mon.Prev.ContainsKey($x.k)) {
            $pv = $mon.Prev[$x.k]
            if ($pv.h -ne $x.h) {
                $lv = $x.h
                $txt = "$lbl : $($pv.h) -> $($x.h)"
                if ($x.p) { $txt += " ($($x.p))" }
                Add-MonEvent $lv $txt $x.k
            }
            if (-not $pv.b -and $x.blk) { Add-MonEvent 'warn' "$lbl : $($x.blk)" $x.k }
            elseif ($pv.b -and -not $x.blk) { Add-MonEvent 'ok' "$lbl : no longer blocked" $x.k }
        }
        $mon.Prev[$x.k] = @{ h = $x.h; b = [bool]$x.blk }
    }

    $mon.Out = @{ Subs = $subOut; Lrs = $lrOut; Blocking = $blocking; Sessions = $sessRows; Ag = $agOut }
    $mon.Seq++
    Write-MonLine
}

# An agent's periodic statistics message (<stats state=...>) as a sentence
function Get-MonStatsText([string]$Msg) {
    if ($Msg -notmatch '^\s*<stats') { return $Msg }
    $cmds = ''
    if ($Msg -match '<sincelaststats[^>]*\scmds="(\d+)"') { $cmds = ", $($Matches[1]) commands in the last interval" }
    if ($Msg -match 'state="2"') { return "Agent statistics: the reader waits for the writer - applying the commands is the bottleneck$cmds" }
    if ($Msg -match 'state="3"') { return "Agent statistics: the writer waits for the reader - reading the commands is the bottleneck$cmds" }
    return "Agent statistics: normal$cmds"
}

# The most telling wait of an agent: a blocked session, otherwise the longest current wait
function Get-MonWait($Ses) {
    $best = $null
    foreach ($x in $Ses) {
        if (-not $x.w) { continue }
        if (-not $best -or ($x.blk -and -not $best.blk) -or ([bool]$x.blk -eq [bool]$best.blk -and $x.ms -gt $best.ms)) { $best = $x }
    }
    if (-not $best) { return '' }
    $txt = "$($best.w) $([math]::Round([double]$best.ms / 1000, 1)) s"
    if ($best.blk -and [int]$best.blk -gt 0) { $txt += " (blocked by $($best.blk))" }
    return $txt
}

function Get-MonSummary {
    $c = @{}
    foreach ($l in 'ok', 'warn', 'error', 'unknown') {
        $c["s$l"] = @($mon.Out.Subs | Where-Object { $_.h -eq $l }).Count
        $c["l$l"] = @($mon.Out.Lrs | Where-Object { $_.h -eq $l }).Count
    }
    $lat = @($mon.Out.Subs | Where-Object { $null -ne $_.lat } | ForEach-Object { [double]$_.lat })
    $pend = @($mon.Out.Subs | Where-Object { $null -ne $_.pd } | ForEach-Object { [double]$_.pd })
    $rate = @(@($mon.Out.Subs | Where-Object { $null -ne $_.rt } | ForEach-Object { [double]$_.rt }) + @($mon.Out.Lrs | Where-Object { $null -ne $_.rt } | ForEach-Object { [double]$_.rt }))
    $errHour = 0
    foreach ($e in $mon.Errors) {
        $now = Get-Date
        if ($mon.Raw.ContainsKey($e.srv) -and $mon.Raw[$e.srv].Now -is [datetime]) { $now = $mon.Raw[$e.srv].Now }
        if ($e.time0 -is [datetime] -and ($now - $e.time0).TotalHours -le 1) { $errHour++ }
    }
    return [ordered]@{
        subs = [ordered]@{ ok = $c.sok; warn = $c.swarn; error = $c.serror; unknown = $c.sunknown }
        lrs = [ordered]@{ ok = $c.lok; warn = $c.lwarn; error = $c.lerror; unknown = $c.lunknown }
        maxLat = $(if ($lat.Count) { ($lat | Measure-Object -Maximum).Maximum } else { $null })
        pending = $(if ($pend.Count) { ($pend | Measure-Object -Sum).Sum } else { $null })
        rate = $(if ($rate.Count) { [math]::Round(($rate | Measure-Object -Sum).Sum, 1) } else { $null })
        blocked = @($mon.Out.Blocking | Where-Object { -not $_.agentBlocks }).Count
        agentBlocks = @($mon.Out.Blocking | Where-Object { $_.agentBlocks }).Count
        errHour = $errHour
        agBad = @($mon.Out.Ag | Where-Object { $_.h -ne 'ok' }).Count
        down = @($mon.Targets.Values | Where-Object { $_.Ok -eq $false }).Count
    }
}
# One console line when the overall state changes (and every 5 minutes)
function Write-MonLine([switch]$Force) {
    if ($mon.Ui -eq 'console') { return }
    foreach ($t in $mon.Targets.Values) { if ($t.Dist.Count -and $null -eq $t.Ok -and -not $Force) { return } }
    $s = Get-MonSummary
    $line = "subscriptions $($s.subs.ok) OK, $($s.subs.warn) warning, $($s.subs.error) error"
    if ($s.subs.unknown) { $line += ", $($s.subs.unknown) no data" }
    $line += " | Log Readers $($s.lrs.ok) OK, $($s.lrs.warn) warning, $($s.lrs.error) error | blocked $($s.blocked)"
    if ($null -ne $s.maxLat) { $line += " | max latency $($s.maxLat) s" }
    if ($null -ne $s.pending) { $line += " | pending $($s.pending)" }
    if ($s.down) { $line += " | servers down $($s.down)" }
    $key = "$($s.subs.ok)|$($s.subs.warn)|$($s.subs.error)|$($s.subs.unknown)|$($s.lrs.ok)|$($s.lrs.warn)|$($s.lrs.error)|$($s.blocked)|$($s.down)"
    if ($Force -or $key -ne $mon.LastLine -or ((Get-Date) - $mon.LastLineAt).TotalMinutes -ge 5) {
        $col = 'Green'
        if ($s.subs.warn -or $s.lrs.warn -or $s.blocked) { $col = 'Yellow' }
        if ($s.subs.error -or $s.lrs.error -or $s.down) { $col = 'Red' }
        Write-Host ("[{0}] {1}" -f (Get-Date).ToString('HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture), $line) -ForegroundColor $col
        $mon.LastLine = $key; $mon.LastLineAt = Get-Date
    }
}

function Get-MonStateJson {
    if ($mon.JsonSeq -eq $mon.Seq) { return $mon.Json }
    $agentWaits = @(foreach ($k in $mon.AgentWaits.Keys) {
        $aw = $mon.AgentWaits[$k]
        $top = @($aw.total.Keys | Sort-Object { $aw.total[$_] } -Descending | Select-Object -First 6 | ForEach-Object {
            $last = 0
            if ($aw.last.ContainsKey($_)) { $last = [math]::Round($aw.last[$_]) }
            [ordered]@{ w = $_; ms = [math]::Round($aw.total[$_]); last = $last }
        })
        $lbl = $k
        if ($mon.SubByKey.ContainsKey($k)) { $lbl = $mon.SubByKey[$k].Label } elseif ($mon.LrByKey.ContainsKey($k)) { $lbl = $mon.LrByKey[$k].Label }
        if ($top.Count) { [ordered]@{ k = $k; lbl = $lbl; top = $top } }
    })
    $servers = @(foreach ($t in $mon.Targets.Values) {
        $run = $null
        if ($t.PS) { $run = [int]((Get-Date) - $t.Started).TotalSeconds }
        [ordered]@{ n = $t.Name; ok = $t.Ok; err = $t.Err; took = $t.Took; at = $t.At; running = $run; notes = @($t.Notes) }
    })
    $o = [ordered]@{
        seq = $mon.Seq; time = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture); paused = $mon.Paused; interval = $mon.Interval
        sum = (Get-MonSummary); servers = $servers; subs = $mon.Out.Subs; lrs = $mon.Out.Lrs; blocking = $mon.Out.Blocking
        sessions = $mon.Out.Sessions; waits = @($mon.Waits.Values); agentWaits = $agentWaits; ag = $mon.Out.Ag
        errors = @($mon.Errors | ForEach-Object { [ordered]@{ key = $_.key; t = $_.t; srv = $_.srv; db = $_.db; k = $_.k; lbl = $_.lbl; code = $_.code
                                                              m = $_.m; more = $_.more; seq = $_.seq; cmd = $_.cmd } })
        events = $mon.Events
    }
    $mon.Json = ConvertTo-FastJson $o
    $mon.JsonSeq = $mon.Seq
    return $mon.Json
}

# --- HTTP (one thread: requests are read without blocking, detail queries run in the background) ---
function Receive-MonRequest($Cl) {
    $stream = $Cl.C.GetStream()
    $buf = New-Object byte[] 16384
    while ($stream.DataAvailable) {
        $n = $stream.Read($buf, 0, $buf.Length)
        if ($n -le 0) { break }
        $Cl.M.Write($buf, 0, $n)
        if ($Cl.M.Length -gt 1MB) { throw 'Request too large' }
    }
    $bytes = $Cl.M.ToArray()
    $text = [Text.Encoding]::ASCII.GetString($bytes)
    $end = $text.IndexOf("`r`n`r`n")
    if ($end -lt 0) { return $null }
    $lines = $text.Substring(0, $end) -split "`r`n"
    $first = $lines[0].Split(' ')
    if ($first.Count -lt 2) { throw 'Bad request' }
    $hdr = @{}
    foreach ($l in ($lines | Select-Object -Skip 1)) {
        $i = $l.IndexOf(':')
        if ($i -gt 0) { $hdr[$l.Substring(0, $i).Trim().ToLowerInvariant()] = $l.Substring($i + 1).Trim() }
    }
    $len = 0
    if ($hdr.ContainsKey('content-length')) { $len = [int]$hdr['content-length'] }
    if ($bytes.Length - ($end + 4) -lt $len) { return $null }
    $path = $first[1]; $query = @{}
    $qi = $path.IndexOf('?')
    if ($qi -ge 0) {
        foreach ($pair in $path.Substring($qi + 1).Split('&')) {
            if (-not $pair) { continue }
            $kv = $pair.Split([char]'=', 2)
            $v = ''
            if ($kv.Count -gt 1) { $v = [uri]::UnescapeDataString($kv[1].Replace('+', ' ')) }
            $query[[uri]::UnescapeDataString($kv[0])] = $v
        }
        $path = $path.Substring(0, $qi)
    }
    return @{ Method = $first[0].ToUpperInvariant(); Path = $path; Query = $query; Headers = $hdr }
}
function Send-MonResponse($C, [int]$Code, [string]$Type, $Body, [string]$Cache = 'no-store') {
    try {
        if ($null -eq $Body) { $bytes = New-Object byte[] 0 }
        elseif ($Body -is [byte[]]) { $bytes = $Body }
        else { $bytes = [Text.Encoding]::UTF8.GetBytes([string]$Body) }
        $reason = @{ 200 = 'OK'; 204 = 'No Content'; 400 = 'Bad Request'; 403 = 'Forbidden'; 404 = 'Not Found'; 405 = 'Method Not Allowed'; 500 = 'Internal Server Error' }[$Code]
        $head = "HTTP/1.1 $Code $reason`r`nContent-Type: $Type`r`nContent-Length: $($bytes.Length)`r`nCache-Control: $Cache`r`n" +
                "X-Content-Type-Options: nosniff`r`nReferrer-Policy: no-referrer`r`nX-Frame-Options: DENY`r`n" +
                "Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'`r`n" +
                "Connection: close`r`n`r`n"
        $hb = [Text.Encoding]::ASCII.GetBytes($head)
        $s = $C.GetStream()
        $s.Write($hb, 0, $hb.Length)
        if ($bytes.Length) { $s.Write($bytes, 0, $bytes.Length) }
        $s.Flush()
    } catch { Write-Verbose "HTTP: $($_.Exception.Message)" } finally { try { $C.Close() } catch { } }
}
function Send-MonJson($C, $Obj, [int]$Code = 200) { Send-MonResponse $C $Code 'application/json; charset=utf-8' (ConvertTo-FastJson $Obj) }

# A detail, command or tracer query runs in the background; the browser (or the console) gets the answer later
function Start-MonQuery($C, [string]$Target, $Task, [string]$Kind, $Extra) {
    $ps = [powershell]::Create()
    $ps.RunspacePool = $mon.Pool
    [void]$ps.AddScript($collectText).AddArgument($Target).AddArgument($mon.Opt).AddArgument($Task)
    $mon.Deferred.Add(@{ C = $C; PS = $ps; Handle = $ps.BeginInvoke(); Kind = $Kind; Extra = $Extra; T = Get-Date })
}
# The three on-demand queries; $null = started, otherwise the reason why not
function Start-MonDetail($C, [string]$Key, [int]$Hours) {
    if ($mon.SubByKey.ContainsKey($Key)) {
        $s = $mon.SubByKey[$Key]
        if (-not $s.AgentId) { return 'The Distribution Agent of this subscription is not known yet.' }
        $task = @{ Kind = 'detail'; Mode = 'sub'; Db = $s.DistDb; AgentId = $s.AgentId; AgentName = $s.AgentName; Hours = $Hours
                   Publication = $s.Edge.Publication; Pending = ($s.Edge.PubType -eq 'Transactional') }
        Start-MonQuery $C $mon.Targets[$s.DistInst].Target $task 'detail' $Key
        return $null
    }
    if ($mon.LrByKey.ContainsKey($Key)) {
        $l = $mon.LrByKey[$Key]
        $name = ''
        if ($agentIdx.ContainsKey("$($l.DistInst)|L|$($l.AgentId)")) { $name = [string]$agentIdx["$($l.DistInst)|L|$($l.AgentId)"].name }
        $task = @{ Kind = 'detail'; Mode = 'lr'; Db = $l.DistDb; AgentId = $l.AgentId; AgentName = $name; Hours = $Hours; Pending = $false }
        Start-MonQuery $C $mon.Targets[$l.DistInst].Target $task 'detail' $Key
        return $null
    }
    return 'Unknown subscription or Log Reader.'
}
# Text of the replicated command an error points to (sp_browsereplcmds)
function Start-MonCommand($C, [string]$Srv, [string]$Db, [string]$Seq, $Cmd, $Agent) {
    if (-not $mon.Targets.Contains($Srv) -or $Seq -notmatch '^0x[0-9A-Fa-f]{1,40}$' -or "$Cmd" -notmatch '^\d+$') { return 'This error does not point to a replicated command.' }
    if (-not $mon.Targets[$Srv].Dist.Contains($Db)) { return 'Unknown distribution database.' }
    $agentId = 0
    if ("$Agent" -match '^\d+$') { $agentId = [int]"$Agent" }
    # sp_browsereplcmds takes the 10-byte LSN part of the sequence number (errors may carry 14 bytes)
    $task = @{ Kind = 'detail'; Mode = 'cmd'; Db = $Db; Seq = $Seq.Substring(0, [Math]::Min(22, $Seq.Length)); Cmd = [int]"$Cmd"; AgentId = $agentId }
    Start-MonQuery $C $mon.Targets[$Srv].Target $task 'cmd' "$Srv|$Db|$Seq|$Cmd"
    return $null
}
function Start-MonTracer($C, [string]$Key) {
    if (-not $AllowTracerTokens) { return 'Start the monitor with -AllowTracerTokens to post tracer tokens.' }
    if (-not $mon.SubByKey.ContainsKey($Key)) { return 'Unknown subscription.' }
    $e = $mon.SubByKey[$Key].Edge
    if ($e.PubType -ne 'Transactional') { return 'Tracer tokens work only for transactional publications.' }
    $task = @{ Kind = 'detail'; Mode = 'post'; Db = $e.PubDb; Publication = $e.Publication }
    Start-MonQuery $C (Get-Target $e.PubServer) $task 'post' $Key
    return $null
}
# ---- repairs and AI reports in the monitor (web page and console share these) ----
# Problem of a subscription / Log Reader from the live model, the recent errors and the last detail that was loaded
function Get-MonProblem([string]$Key) {
    $P = New-Problem; $P.Key = $Key; $x = $null; $jobKey = ''
    if ($mon.SubByKey.ContainsKey($Key)) {
        $s = $mon.SubByKey[$Key]; $e = $s.Edge
        $P.Kind = 'sub'; $P.Label = $s.Label; $jobKey = [string]$s.JobKey
        $P.PubServer = [string]$e.PubServer; $P.PubName = [string]$e.PubServerRaw; $P.PubDb = [string]$e.PubDb; $P.Publication = [string]$e.Publication; $P.PubType = [string]$e.PubType
        $P.SubServer = [string]$e.SubServer; $P.SubName = [string]$e.SubServerRaw; $P.SubDb = [string]$e.SubDb; $P.SubType = [string]$e.SubType
        $P.DistServer = [string]$s.DistInst; $P.DistDb = [string]$s.DistDb
        foreach ($o in $mon.Out.Subs) { if ($o.k -eq $Key) { $x = $o; break } }
    } elseif ($mon.LrByKey.ContainsKey($Key)) {
        $l = $mon.LrByKey[$Key]
        $P.Kind = 'lr'; $P.Label = $l.Label; $jobKey = [string]$l.JobKey
        $P.PubServer = [string]$l.Publisher; $P.PubDb = [string]$l.PubDb; $P.DistServer = [string]$l.DistInst; $P.DistDb = [string]$l.DistDb
        foreach ($o in $mon.Out.Lrs) { if ($o.k -eq $Key) { $x = $o; break } }
    } else { return $null }
    if ($x) { $P.Level = [string]$x.h; $P.Problem = [string]$x.p; $P.Status = [string]$x.st; $P.Msg = [string]$x.msg; $P.Job = [string]$x.job }
    if ($jobKey) {
        $P.JobSrv = ($jobKey -split '\|')[0]; $P.JobId = ($jobKey -split '\|')[1]
        if ($serverInfo.ContainsKey($P.JobSrv)) {
            foreach ($j in $serverInfo[$P.JobSrv].Jobs) { if (([string]$j.job_id).ToUpperInvariant() -eq $P.JobId) { $P.JobName = [string]$j.name; break } }
        }
    }
    $text = New-Object System.Collections.Generic.List[string]
    $text.Add($P.Problem); $text.Add($P.Msg)
    $n = 0
    $now = Get-Date
    if ($mon.Raw.ContainsKey($P.DistServer) -and $mon.Raw[$P.DistServer].Now -is [datetime]) { $now = $mon.Raw[$P.DistServer].Now }
    foreach ($er in $mon.Errors) {
        if ($er.k -ne $Key) { continue }
        if (++$n -gt 10) { break }
        if ($er.time0 -is [datetime] -and ($now - $er.time0).TotalMinutes -le 30) { $P.Recent = $true }
        if ("$($er.code)" -match '^-?\d+$') { $P.Codes.Add([int]"$($er.code)") }
        foreach ($m in $er.more) { if ($m -match '^(-?\d+):') { $P.Codes.Add([int]$Matches[1]) }; $text.Add([string]$m) }
        $text.Add([string]$er.m)
        if (-not $P.Seq -and $er.seq) { $P.Seq = ([string]$er.seq).Substring(0, [Math]::Min(22, ([string]$er.seq).Length)) }
    }
    if ($mon.LastDetail.ContainsKey($Key)) {
        $d = $mon.LastDetail[$Key]
        if ($d.Fail) { $P.Fail = $d.Fail; $P.Seq = [string]$d.Fail.seq }
    }
    if ($P.Fail -and $P.Fail.article) { $P.ArtFilter = $artFilter["$($P.PubServer)|$($P.PubDb)|$($P.Publication)|$($P.Fail.article)".ToUpperInvariant()] }
    # a transaction skipped already is not offered again until the agent reports the next one (about a minute)
    if ($P.Seq -and $mon.Skipped.ContainsKey($Key) -and $mon.Skipped[$Key] -eq $P.Seq) { $P.Seq = '' }
    $P.Text = ($text | Where-Object { $_ }) -join ' | '
    return $P
}
function Get-MonRepairs([string]$Key) {
    $P = Get-MonProblem $Key
    if (-not $P) { return , @() }
    return , (Get-RepairActions $P)
}
function ConvertTo-RepairJson([string]$Label, $Acts) {
    return , @(foreach ($a in $Acts) {
        [ordered]@{ id = $a.id; title = $a.title; level = $a.level; why = $a.why; risk = $a.risk; undo = $a.undo; check = $a.check
                    confirm = $a.confirm; run = (Test-RepairAllowed $a); sql = (Format-RepairScript $Label $a) }
    })
}
function Write-RepairLog([string]$Text) {
    try {
        if (-not (Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
        Add-Content -LiteralPath (Join-Path $OutputDir 'repairs.log') -Value ('{0} {1}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture), $Text) -Encoding UTF8
    } catch {
        $m = "Cannot write repairs.log in $OutputDir (-OutputDir): $($_.Exception.Message)"
        if ($m -ne $mon.LastFault) { $mon.LastFault = $m; Add-MonEvent 'error' $m }
    }
}
# Runs one repair, step after step; $null = started, otherwise the reason why not
function Start-MonRepair($C, [string]$Key, [int]$FindId, [string]$ActionId, [string]$Phrase) {
    if ($mon.Repair) { return 'Another repair is running - wait until it ends.' }
    $label = ''; $acts = @()
    if ($Key) {
        $P = Get-MonProblem $Key
        if (-not $P) { return 'Unknown item.' }
        $label = $P.Label; $acts = (Get-RepairActions $P)
    } elseif ($FindId -ge 0 -and $FindId -lt $findings.Count) {
        $f = $findings[$FindId]; $label = "$($f.Server) $($f.Object)"; $acts = (Get-FindingRepairs $f)
    } else { return 'Unknown item.' }
    $a = $null
    foreach ($x in $acts) { if ($x.id -eq $ActionId) { $a = $x } }
    if (-not $a) { return 'This repair does not apply any more - the state has changed. Reload the detail.' }
    if ($a.level -eq 'script') { return 'This repair is a script only (it needs a password or a decision) - save it and run it in SSMS.' }
    if (-not (Test-RepairAllowed $a)) {
        if ($a.level -eq 'full') { return 'This repair needs the monitor started with -AllowAllRepair.' }
        return 'Repairs need the monitor started with -AllowRepair (or -AllowAllRepair).'
    }
    if ($a.level -eq 'full') { if (([string]$Phrase).Trim() -cne $a.confirm) { return "Not confirmed - type $($a.confirm) to run this repair." } }
    elseif ($Phrase -ne 'yes') { return 'Not confirmed.' }
    $seq = ''
    if ($Key -and $a.id -eq 'skip-tx') { $seq = $P.Seq }
    $mon.Repair = @{ C = $C; A = $a; Label = $label; Step = 0; Key = $Key; Seq = $seq }
    Write-RepairLog "START [$($a.level)] $($a.title) | $label | $authText"
    Add-MonEvent 'warn' "Repair started: $($a.title) - $label" $Key
    Start-MonRepairStep
    return $null
}
function Start-MonRepairStep {
    $r = $mon.Repair; $s = $r.A.steps[$r.Step]
    Write-RepairLog ('  step {0}/{1} on {2} / {3}: {4}' -f ($r.Step + 1), $r.A.steps.Count, $s.srv, $s.db, ($s.sql -replace '\s+', ' '))
    Start-MonQuery $r.C (Get-Target $s.srv) @{ Kind = 'repair'; Db = $s.db; Sql = $s.sql } 'repair' $r.Step
}
function Complete-MonRepair($Res) {
    $r = $mon.Repair
    if (-not $r) { return }
    $err = ''
    if ($Res.Error) { $err = Get-ConnHint $Res 'server' } elseif ($Res.Repair -and $Res.Repair.Error) { $err = $Res.Repair.Error }
    $s = $r.A.steps[$r.Step]
    if ($err) {
        Write-RepairLog "  FAILED: $err"
        $msg = "Repair failed at step $($r.Step + 1) of $($r.A.steps.Count) ($($s.srv) / $($s.db)): $err"
        Add-MonEvent 'error' "$msg - $($r.A.title), $($r.Label)" $r.Key
        $mon.Repair = $null
        if ($r.C) { Send-MonJson $r.C ([ordered]@{ error = $msg }) } else { Set-ConMsg $msg }
        return
    }
    $r.Step++
    if ($r.Step -lt $r.A.steps.Count) { Start-MonRepairStep; return }
    Write-RepairLog '  DONE'
    if ($r.Seq) { $mon.Skipped[$r.Key] = $r.Seq }
    $msg = "Repair done: $($r.A.title). $($r.A.check)"
    Add-MonEvent 'info' "$msg - $($r.Label)" $r.Key
    $mon.Repair = $null
    foreach ($t in $mon.Targets.Values) { $t.Next = Get-Date; $t.PendingNow = $true }   # show the effect at once
    if ($r.C) { Send-MonJson $r.C ([ordered]@{ ok = $true; message = $msg }) } else { Set-ConMsg $msg }
}
# Report for an AI assistant about one subscription / Log Reader (what the monitor knows now plus the last detail)
function New-MonAiReport([string]$Key) {
    $P = Get-MonProblem $Key
    if (-not $P) { return [pscustomobject]@{ Error = 'Unknown item.' } }
    $x = $null
    foreach ($o in $mon.Out.Subs) { if ($o.k -eq $Key) { $x = $o } }   # @(List) throws in PowerShell 7.4
    foreach ($o in $mon.Out.Lrs) { if ($o.k -eq $Key) { $x = $o } }
    $d = $null
    if ($mon.LastDetail.ContainsKey($Key)) { $d = $mon.LastDetail[$Key] }
    $mask = New-AiMasker; Add-AiKnownNames $mask   # not $M: PowerShell names ignore case and the loops use $m
    foreach ($r in $mon.Out.Sessions) { Add-AiName $mask ([string]$r.host) 'HOST' }
    $L = New-Object System.Collections.Generic.List[string]
    $L.Add('# SQL Server replication problem - report for an AI assistant'); $L.Add('')
    foreach ($q in $aiQuestion) { $L.Add($q) }
    $L.Add(''); $L.Add("Collected by Get-ReplTopology.ps1 $scriptVersion (live monitor) on $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)).")
    $L.Add(''); $L.Add('## The item')
    if ($P.Kind -eq 'sub') {
        $L.Add("- Subscription of the $($P.PubType) publication $($P.Publication): publisher $($P.PubServer) / $($P.PubDb) -> subscriber $($P.SubServer) / $($P.SubDb) ($($P.SubType)); distributor $($P.DistServer) / $($P.DistDb)")
    } else { $L.Add("- Log Reader of $($P.PubServer) / $($P.PubDb); distributor $($P.DistServer) / $($P.DistDb)") }
    foreach ($srv in @($P.PubServer, $P.SubServer)) {
        if ($srv -and $agByListener.ContainsKey($srv)) {
            $ag = $ags[$agByListener[$srv]]
            $L.Add("- $srv is the listener of AG $($ag.Name); replicas: $(@(foreach ($r in @($ag.Replicas.Keys)) { "$r ($($ag.Replicas[$r]))" }) -join ', ')")
        }
    }
    $L.Add("- Health: $($P.Level) - $($P.Problem)")
    $L.Add("- Agent status: $($P.Status); agent job: $($P.Job) $($P.JobName)")
    if ($x) {
        $facts = @()
        foreach ($f in @(@('latency s', 'lat'), @('pending commands', 'pd'), @('oldest undelivered transaction s', 'old'), @('commands/s', 'rt'), @('last agent entry s ago', 'age'), @('delivered commands', 'cmds'))) {
            if ($x.Contains($f[1]) -and $null -ne $x[$f[1]]) { $facts += "$($f[0]): $($x[$f[1]])" }
        }
        if ($facts) { $L.Add('- ' + ($facts -join '; ')) }
        if ($x.Contains('blk') -and $x.blk) { $L.Add("- Blocking: $($x.blk)") }
    }
    if ($P.Msg) { $L.Add("- Last agent message: $(($P.Msg -replace '\s+', ' ').Trim())") }
    if ($P.Kind -eq 'sub') {
        foreach ($f in (Get-PubFilters $P.PubServer $P.PubDb $P.Publication)) {
            $t = "- Filtered article $($f.Article):"
            if ($f.Rows) { $t += " rows WHERE $(Protect-AiValues $f.Rows)" }
            if ($f.Excluded) { $t += " columns not published: $($f.Excluded)" }
            $L.Add($t)
        }
    }
    if ($P.Kind -eq 'sub' -and $mon.SubByKey[$Key].LrKey) {
        foreach ($o in $mon.Out.Lrs) { if ($o.k -eq $mon.SubByKey[$Key].LrKey) { $L.Add("- Log Reader of the publication database: $($o.st), $($o.h) $($o.p)") } }
    }
    if ($d) {
        if ($d.Errors.Count) {
            $L.Add(''); $L.Add('## Errors (newest first)')
            foreach ($er in @($d.Errors | Select-Object -First 15)) {
                $L.Add("- $($er.t) error $($er.code): $(($er.m -replace '\s+', ' ').Trim())")
                foreach ($m in $er.more) { $L.Add("  - $(($m -replace '\s+', ' ').Trim())") }
            }
        }
        if ($d.Fail) {
            $L.Add(''); $L.Add('## The replicated command that fails (values masked)')
            $from = (@($d.Fail.srcOwner, $d.Fail.src) | Where-Object { $_ }) -join '.'; $to = (@($d.Fail.dstOwner, $d.Fail.dst) | Where-Object { $_ }) -join '.'
            $L.Add("Transaction $($d.Fail.seq), command $($d.Fail.cmd), article $($d.Fail.article): $from -> $to")
            $L.Add('```'); $L.Add((Protect-AiValues ([string]$d.Fail.command))); $L.Add('```')
        }
        $msgs = @($d.Msgs | Where-Object { $_.m -notmatch '^\s*<stats' } | Select-Object -First 25)
        if ($msgs.Count) {
            $L.Add(''); $L.Add('## Agent history (changes of the message, newest first)')
            foreach ($m in $msgs) { $st = ''; if ($null -ne $m.st -and $runName.ContainsKey([int]$m.st)) { $st = $runName[[int]$m.st] }; $L.Add("- $($m.t) $st - $(($m.m -replace '\s+', ' ').Trim())") }
        }
        $stats = @($d.Msgs | Where-Object { $_.m -match '^\s*<stats' } | Select-Object -First 1)
        if ($stats.Count) { $L.Add(''); $L.Add('## Last agent statistics (<stats> from the history)'); $L.Add('```xml'); $L.Add([string]$stats[0].m); $L.Add('```') }
        if ($d.Articles.Count) {
            $L.Add(''); $L.Add("## Pending commands per article ($($d.Transactions) transactions)")
            foreach ($a in @($d.Articles | Select-Object -First 15)) { $L.Add("- $($a.a): $($a.n)") }
            foreach ($t in @($d.TopTx | Select-Object -First 5)) { $L.Add("- large transaction $($t.seq): $($t.n) commands, entered $($t.t)") }
        }
        if ($d.Tracer.Count) {
            $L.Add(''); $L.Add('## Tracer tokens (seconds publisher -> distributor -> subscriber)')
            foreach ($t in @($d.Tracer | Select-Object -First 5)) { $L.Add("- $($t.t): $($t.toDist) / $($t.toSub) / total $($t.total)") }
        }
        foreach ($n in $d.Notes) { $L.Add("- note: $n") }
    } else { $L.Add(''); $L.Add('(The detail was not loaded, so errors and history are missing - open the detail and create the report again.)') }
    $ses = @($mon.Out.Sessions | Where-Object { $_.k -eq $Key })
    if ($ses.Count) {
        $L.Add(''); $L.Add('## Agent sessions now')
        foreach ($s in $ses) { $L.Add("- $($s.srv) session $($s.spid) ($($s.side)): $($s.st) $($s.req), command $($s.cmd), wait $($s.w) $($s.ms) ms, blocked by $($s.blk), cpu $($s.cpu), open tran $($s.tran); sql: $(Protect-AiValues ([string]$s.sql))") }
    }
    foreach ($b in @($mon.Out.Blocking | Where-Object { $_.k -eq $Key })) { $L.Add("- blocked $($b.ms) ms by session $($b.by) ($($b.hProg) $($b.hHost)), wait $($b.w) on $($b.res); head sql: $(Protect-AiValues ([string]$b.hSql))") }
    $agRows = @($mon.Out.Ag | Where-Object { $_.db -in $P.PubDb, $P.SubDb })
    if ($agRows.Count) {
        $L.Add(''); $L.Add('## Availability group state of these databases')
        foreach ($r in $agRows) { $L.Add("- AG $($r.ag) / $($r.db): $($r.replica) $($r.role) $($r.mode), $($r.sync), $($r.health) $($r.p)") }
    }
    $srvs = @($P.PubServer, $P.SubServer, $P.DistServer) | Where-Object { $_ }
    $rel = @($findings | Where-Object { $_.Severity -in 'error', 'warn' -and ($_.Server -in $srvs -or "$($_.Object)" -match [regex]::Escape([string]$P.PubDb)) } | Select-Object -First 20)
    if ($rel.Count) { $L.Add(''); $L.Add('## Findings of the report about these servers'); foreach ($f in $rel) { $L.Add("- [$($f.Severity)] $($f.Category) $($f.Server) $($f.Object): $($f.Finding)") } }
    $L.Add(''); $L.Add('## Versions')
    foreach ($s in ($serverInfo.Values | Sort-Object Server)) { $L.Add("- $($s.Server): $(Get-SqlYear $s.Version) ($($s.Version)) $($s.Edition)") }
    $acts = (Get-RepairActions $P)
    if ($acts.Count) { $L.Add(''); $L.Add('## Repairs the tool offers for this problem'); foreach ($a in $acts) { $L.Add("- $($a.title) [$($a.level)]: $($a.why)") } }
    $base = 'ai-subscription'
    if ($P.Kind -eq 'lr') { $base = 'ai-logreader' }
    return Save-AiReport ($L -join "`n") $mask $base
}
function Complete-MonQuery($D) {
    $r = Complete-MonJob $D.PS $D.Handle
    if ($D.Kind -eq 'repair') { Complete-MonRepair $r; return }
    $err = ''
    if ($r.Error) { $err = Get-ConnHint $r 'server' }
    $x = $null
    if (-not $err) { $x = $r.Detail }
    if ($D.Kind -eq 'post' -and $x -and $null -ne $x.TracerId) {
        $e = $mon.SubByKey[$D.Extra].Edge
        Add-MonEvent 'info' "Tracer token $($x.TracerId) posted: $($e.Publication) on $($e.PubServer)/$($e.PubDb)" $D.Extra
    }
    if ($D.Kind -eq 'detail' -and $x) { $mon.LastDetail[$D.Extra] = $x }   # for the repairs and the AI report
    if (-not $D.C) { Complete-ConQuery $D $x $err; return }
    if ($err) { Send-MonJson $D.C ([ordered]@{ error = $err }); return }
    switch ($D.Kind) {
        'cmd' { Send-MonJson $D.C ([ordered]@{ cmd = $x.Cmd; notes = $x.Notes }) }
        'post' { Send-MonJson $D.C ([ordered]@{ tracerId = $x.TracerId; notes = $x.Notes }) }
        default {
            Send-MonJson $D.C ([ordered]@{ k = $D.Extra; now = $x.Now; chart = $x.Chart; msgs = $x.Msgs; errors = $x.Errors; tracer = $x.Tracer
                                         articles = $x.Articles; topTx = $x.TopTx; transactions = $x.Transactions; notes = $x.Notes; fail = $x.Fail
                                         repairs = (ConvertTo-RepairJson (Get-MonProblem $D.Extra).Label (Get-MonRepairs $D.Extra)) })
        }
    }
}
# Pause, resume, refresh now, interval, stop - from the page or from the console keys
function Invoke-MonControl([string]$Action, $Value) {
    switch ($Action) {
        'pause' { $mon.Paused = $true; Add-MonEvent 'info' 'Refresh paused' }
        'resume' { $mon.Paused = $false; foreach ($t in $mon.Targets.Values) { $t.Next = Get-Date }; Add-MonEvent 'info' 'Refresh resumed' }
        'refresh' { foreach ($t in $mon.Targets.Values) { $t.Next = Get-Date; $t.PendingNow = $true } }
        'interval' {
            if ("$Value" -notmatch '^\d+$') { return 'The interval must be a number of seconds.' }
            $mon.Interval = [Math]::Max(2, [Math]::Min(3600, [int]"$Value"))
            foreach ($t in $mon.Targets.Values) { if (-not $t.PS) { $t.Next = Get-Date } }
        }
        'stop' { $mon.Stop = $true; Add-MonEvent 'info' 'Monitor stopped' }
        default { return 'Unknown action' }
    }
    $mon.Seq++
    return $null
}

function Invoke-MonRequest($C, $Req) {
    $p = $Req.Path
    if ($p -eq '/favicon.ico') { Send-MonResponse $C 204 'text/plain' $null; return }
    # The page and the library accept the key from the URL; the API only from the X-Token header
    $tok = $Req.Headers['x-token']
    if (-not $p.StartsWith('/api/') -and -not $tok) { $tok = $Req.Query['t'] }
    if ($tok -ne $mon.Token) {
        Send-MonResponse $C 403 'text/html; charset=utf-8' '<!doctype html><meta charset="utf-8"><title>Replication Monitor</title><p style="font-family:sans-serif">Open the address printed in the PowerShell window - it contains the access key.</p>'
        return
    }
    if ($p -eq '/') { Send-MonResponse $C 200 'text/html; charset=utf-8' $mon.Page; return }
    if ($p -eq '/mermaid.min.js') {
        if ($mon.Lib) { Send-MonResponse $C 200 'application/javascript; charset=utf-8' $mon.Lib 'private, max-age=86400' }
        else { Send-MonResponse $C 404 'text/plain' 'mermaid.min.js was not found next to the script' }
        return
    }
    if ($p -eq '/api/state') {
        if ($Req.Query['since'] -eq [string]$mon.Seq) { Send-MonResponse $C 204 'application/json' $null; return }
        Send-MonResponse $C 200 'application/json; charset=utf-8' (Get-MonStateJson)
        return
    }
    $why = $null
    if ($p -eq '/api/detail') {
        $h = 6
        if ($Req.Query['h'] -match '^\d+$') { $h = [Math]::Max(1, [Math]::Min(720, [int]$Req.Query['h'])) }
        $why = Start-MonDetail $C ([string]$Req.Query['k']) $h
    } elseif ($p -eq '/api/command') {
        $why = Start-MonCommand $C ([string]$Req.Query['srv']) ([string]$Req.Query['db']) ([string]$Req.Query['seq']) $Req.Query['cmd'] $Req.Query['agent']
    } elseif ($Req.Method -ne 'POST') {
        Send-MonResponse $C 405 'text/plain' 'POST only'; return
    } elseif ($p -eq '/api/tracer') {
        $why = Start-MonTracer $C ([string]$Req.Query['k'])
    } elseif ($p -eq '/api/repair') {
        $fid = -1
        if ([string]$Req.Query['f'] -match '^\d+$') { $fid = [int]$Req.Query['f'] }
        $why = Start-MonRepair $C ([string]$Req.Query['k']) $fid ([string]$Req.Query['a']) ([string]$Req.Query['c'])
    } elseif ($p -eq '/api/aireport') {
        try {
            $ai = New-MonAiReport ([string]$Req.Query['k'])
            if ($ai.PSObject.Properties['Error']) { $why = $ai.Error }
            else { Send-MonJson $C ([ordered]@{ file = $ai.File; map = $ai.Map; md = $ai.Text; masked = (-not $NoMask) }); return }
        } catch { $why = "The report could not be written: $($_.Exception.Message)" }
    } elseif ($p -eq '/api/control') {
        $why = Invoke-MonControl ([string]$Req.Query['a']) $Req.Query['v']
        if (-not $why) { Send-MonJson $C ([ordered]@{ ok = $true; paused = $mon.Paused; interval = $mon.Interval }); return }
    } else { Send-MonResponse $C 404 'text/plain' 'Not found'; return }
    if ($why) { Send-MonJson $C ([ordered]@{ error = $why }) }
}

# ---------------------------------------------------------------------------
# Console monitor (-Console): full-screen text view with keys, the same data as the web page.
# Only changed lines are rewritten (no flicker). Characters: ASCII plus ■ ░ ▒ ▓ █ - present in the console code pages 437/850/852 and in Consolas or
# Lucida Console (Windows PowerShell 5.1 writes [Console] output in the OEM code page; '·' would become '?').
# ---------------------------------------------------------------------------
$con = @{}
$conLevelColor = @{ ok = 'Green'; warn = 'Yellow'; error = 'Red'; unknown = 'DarkGray'; '' = 'DarkGray'; info = 'Gray' }
$conStatusColor = @{ Running = 'Green'; Idle = 'Cyan'; Started = 'Green'; Retrying = 'Yellow'; Failed = 'Red'; 'Not running' = 'Red'; Stopped = 'DarkGray' }
$conViews = @(@('subs', 'Subscriptions'), @('lrs', 'Log Readers'), @('waits', 'Blocking+waits'), @('ag', 'AG'), @('errors', 'Errors'), @('events', 'Events'), @('servers', 'Servers'), @('findings', 'Findings'))
$conQuick = @('all', 'problems', 'errors', 'blocked', 'pending', 'not running', 'latency')
$conSorts = @{ subs = @('health', 'latency', 'pending', 'oldest', 'flow', 'publication', 'subscriber'); lrs = @('health', 'latency', 'flow', 'publisher') }

# Can this window draw the console monitor? (not in PowerShell ISE, a remote session or with redirected output)
function Test-ConUi {
    try {
        if ([Console]::IsOutputRedirected -or [Console]::IsInputRedirected) { return $false }
        [void][Console]::KeyAvailable
        return ([Console]::WindowWidth -ge 70 -and [Console]::WindowHeight -ge 16)
    } catch { return $false }
}
function Initialize-ConUi {
    $con.Fg = [Console]::ForegroundColor; $con.Bg = [Console]::BackgroundColor
    if ([int]$con.Fg -lt 0) { $con.Fg = [ConsoleColor]::Gray }
    if ([int]$con.Bg -lt 0) { $con.Bg = [ConsoleColor]::Black }
    $con.Cursor = $true
    try { $con.Cursor = [Console]::CursorVisible } catch { }
    try { [Console]::CursorVisible = $false } catch { }
    $con.View = 'subs'; $con.Sel = @{}; $con.UserSel = @{}; $con.Top = @{}; $con.Filter = ''; $con.FilterBefore = ''; $con.Typing = $false; $con.Quick = 0
    $con.Sort = @{ subs = 0; lrs = 0 }; $con.Detail = $null; $con.Prev = @{}; $con.W = 0; $con.H = 0; $con.Dirty = $true
    $con.LastDraw = [datetime]::MinValue; $con.LastSeq = -1; $con.Msg = ''; $con.MsgAt = [datetime]::MinValue; $con.Ask = $null; $con.CmdCache = @{}; $con.Reload = @()
    $con.Text = @{}; $con.Sum = $null; $con.SumSeq = -1; $con.CacheKey = ''; $con.CacheBase = ''; $con.LastKey = [datetime]::MinValue; $con.Cache = $null; $con.DetailKey = ''; $con.DetailLines = $null; $con.DetailVer = 0
    foreach ($s in $mon.Subs) {
        $e = $s.Edge
        $con.Text[$s.Key] = "$($e.PubServer) $($e.PubInstance) $($e.PubDb) $($e.Publication) $($e.PubType) $($e.SubServer) $($e.SubInstance) $($e.SubDb) $($e.SubType) $($e.Distributor) $($s.Notes) $($e.ArticleNames)".ToLowerInvariant()
    }
    foreach ($l in $mon.Lrs) { $con.Text[$l.Key] = "$($l.Publisher) $($l.PubDb) $($l.DistInst) $($l.Ag) log reader".ToLowerInvariant() }
    # keys pressed while the topology was read (and terminal answers to the progress bar) are not commands
    try { while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) } } catch { }
    try { [Console]::Clear() } catch { }
}
function Close-ConUi {
    try { [Console]::ResetColor() } catch { }   # the console's own colors (not an explicit white on black)
    try { [Console]::Clear() } catch { }
    try { [Console]::CursorVisible = $con.Cursor } catch { }
}
function Set-ConMsg([string]$Text) { $con.Msg = $Text; $con.MsgAt = Get-Date; $con.Dirty = $true }

# --- drawing helpers: a line is a list of segments (text, color) with an optional background ---
function New-ConLine($Bg = $null) { return @{ Segs = (New-Object System.Collections.Generic.List[object]); Bg = $Bg } }
function Add-ConSeg($Line, $Text, $Fg = $null, $Bg = $null) { $Line.Segs.Add(@(([string]$Text), $Fg, $Bg)) }
function Format-ConCell($Text, [int]$Len, [switch]$Right) {
    $s = [string]$Text
    if ($s.IndexOfAny([char[]]"`r`n`t") -ge 0 -or $s.Contains('  ')) { $s = $s -replace '\s+', ' ' }
    $s = $s.Trim()
    if ($Len -le 0) { return '' }
    if ($s.Length -gt $Len) { if ($Len -le 1) { return $s.Substring(0, $Len) } return $s.Substring(0, $Len - 1) + '~' }
    if ($Right) { return $s.PadLeft($Len) }
    return $s.PadRight($Len)
}
function Format-ConNum($v, [int]$Dec = 0) {
    if ($null -eq $v -or "$v" -eq '') { return '' }
    return ([double]$v).ToString("N$Dec", [Globalization.CultureInfo]::InvariantCulture)
}
function Format-ConAge($s) {
    if ($null -eq $s -or "$s" -eq '') { return '' }
    $s = [int]$s
    if ($s -lt 60) { return "$s s" }
    if ($s -lt 3600) { return "$([int][math]::Floor($s / 60)) min" }
    if ($s -lt 86400) { return "$([int][math]::Floor($s / 3600)) h $([int][math]::Floor(($s % 3600) / 60)) min" }
    return "$([int][math]::Floor($s / 86400)) d $([int][math]::Floor(($s % 86400) / 3600)) h"
}
function Get-ConNumColor($v, $Warn, $Err) {
    if ($null -eq $v) { return $null }
    if ($v -ge $Err) { return 'Red' }
    if ($v -ge $Warn) { return 'Yellow' }
    return $null
}
# Trend from the last samples as shades (░ ▒ ▓ █), highest value = █
function Get-ConSpark($Values, [int]$Len) {
    $v = @($Values)
    if ($v.Count -gt $Len) { $v = $v[($v.Count - $Len)..($v.Count - 1)] }
    if ($v.Count -lt 2) { return ''.PadRight($Len) }
    $max = 0
    foreach ($x in $v) { if ($null -ne $x -and [double]$x -gt $max) { $max = [double]$x } }
    $ch = ' ░▒▓█'
    $out = foreach ($x in $v) {
        if ($null -eq $x -or $max -le 0) { ' ' } else { $ch[[int][math]::Ceiling(4 * [double]$x / $max)] }
    }
    return (-join $out).PadLeft($Len)
}
# Wrap text into lines of a width (for messages and SQL)
function Split-ConText($Text, [int]$Width) {
    $s = ([string]$Text -replace '\s+', ' ').Trim()
    $out = New-Object System.Collections.Generic.List[string]
    if ($Width -lt 10) { $Width = 10 }
    while ($s.Length -gt $Width) {
        $cut = $s.LastIndexOf(' ', $Width)
        if ($cut -lt $Width / 2) { $cut = $Width }
        $out.Add($s.Substring(0, $cut)); $s = $s.Substring($cut).TrimStart()
    }
    if ($s -or $out.Count -eq 0) { $out.Add($s) }
    return , $out
}
function Write-ConFrame($Lines, [int]$W, [int]$H) {
    if ($W -ne $con.W -or $H -ne $con.H) { $con.Prev = @{}; $con.W = $W; $con.H = $H; try { [Console]::Clear() } catch { } }
    for ($y = 0; $y -lt $H; $y++) {
        $ln = $null
        if ($y -lt $Lines.Count) { $ln = $Lines[$y] }
        $sig = ''
        if ($ln) {
            if ($ln.ContainsKey('Sig')) { $sig = $ln.Sig }
            else {
                $sb = New-Object System.Text.StringBuilder
                [void]$sb.Append([string]$ln.Bg); foreach ($sg in $ln.Segs) { [void]$sb.Append('|').Append([string]$sg[1]).Append('/').Append([string]$sg[2]).Append(':').Append($sg[0]) }
                $sig = $sb.ToString(); $ln.Sig = $sig
            }
        }
        if ($con.Prev.ContainsKey($y) -and $con.Prev[$y] -eq $sig) { continue }
        $con.Prev[$y] = $sig
        $bg = $con.Bg
        if ($ln -and $ln.Bg) { $bg = $ln.Bg }
        [Console]::SetCursorPosition(0, $y)
        [Console]::BackgroundColor = $bg
        $used = 0
        if ($ln) {
            foreach ($s in $ln.Segs) {
                if ($used -ge $W) { break }
                $t = $s[0] -replace '[\r\n\t]', ' '
                if ($t.Length -gt $W - $used) { $t = $t.Substring(0, $W - $used) }
                $fg = $con.Fg
                if ($s[1]) { $fg = $s[1] }
                if ($ln.Bg -and $fg -eq 'DarkGray') { $fg = 'Gray' }
                [Console]::ForegroundColor = $fg
                if ($s.Count -gt 2 -and $s[2]) { [Console]::BackgroundColor = $s[2] } else { [Console]::BackgroundColor = $bg }
                [Console]::Write($t)
                $used += $t.Length
            }
        }
        [Console]::ForegroundColor = $con.Fg; [Console]::BackgroundColor = $bg
        if ($used -lt $W) { [Console]::Write(' ' * ($W - $used)) }
    }
    [Console]::ForegroundColor = $con.Fg; [Console]::BackgroundColor = $con.Bg
}

# --- data for the views ---
function Get-ConLive([string]$Key, $Index) {
    if ($Index.ContainsKey($Key)) { return $Index[$Key] }
    return [ordered]@{ k = $Key; h = 'unknown'; p = ''; st = ''; lat = $null; lh = @(); rt = $null; rh = @(); age = $null; msg = ''; job = ''; ses = @(); blk = ''; wt = '' }
}
function Test-ConPass([string]$Key, $X) {
    $q = $conQuick[$con.Quick]
    if ($q -ne 'all') {
        $ok = switch ($q) {
            'problems' { $X.h -eq 'warn' -or $X.h -eq 'error' }
            'errors' { $X.h -eq 'error' }
            'blocked' { [bool]$X.blk }
            'pending' { $null -ne $X['pd'] -and $X['pd'] -gt 0 }
            'not running' { $X.st -in 'Not running', 'Stopped', 'Failed', 'Retrying' }
            'latency' { $null -ne $X.lat -and $X.lat -ge 30 }
        }
        if (-not $ok) { return $false }
    }
    if ($con.Filter) {
        $t = $con.Text[$Key] + ' ' + "$($X.p) $($X.msg) $($X.wt) $($X.st) $($X.blk) $($X.h) $($X.job) $($X['ag'])".ToLowerInvariant()
        foreach ($wd in ($con.Filter.ToLowerInvariant() -split '\s+')) { if ($wd -and -not $t.Contains($wd)) { return $false } }
    }
    return $true
}
function Test-ConText([string]$Text) {
    if (-not $con.Filter) { return $true }
    $t = $Text.ToLowerInvariant()
    foreach ($wd in ($con.Filter.ToLowerInvariant() -split '\s+')) { if ($wd -and -not $t.Contains($wd)) { return $false } }
    return $true
}
# Consecutive identical errors become one entry with a count (like the web page)
function Get-ConErrors($List) {
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($e in $List) {
        $sig = "$($e['k'])$($e['lbl'])|$($e.code)|$($e.m)|$($e.more -join '|')"
        if ($out.Count -and $out[$out.Count - 1].Sig -eq $sig) { $p = $out[$out.Count - 1]; $p.N++; $p.First = $e.t; continue }
        $out.Add(@{ E = $e; Sig = $sig; N = 1; First = $e.t })
    }
    return , $out
}
function Get-ConCause($E) {
    $code = $E.code; $text = [string]$E.m
    if ("$($E.code)" -eq '14151') {
        foreach ($m in $E.more) { if ($m -match '^(-?\d+): (.*)$') { $code = $Matches[1]; $text = $Matches[2]; break } }
    }
    return @($code, $text)
}

function Add-ConItem($Items, $Key, $Lines) { $Items.Add(@{ Key = [string]$Key; Lines = $Lines }) }
function Add-ConHeader($Items, [string]$Text, [int]$W) {
    $l = New-ConLine 'DarkGray'
    Add-ConSeg $l (Format-ConCell " $Text" $W) 'White'
    Add-ConItem $Items '' @($l)
}

function Get-ConSubItems([int]$W) {
    $items = New-Object System.Collections.Generic.List[object]
    $idx = @{}
    foreach ($x in $mon.Out.Subs) { $idx[$x.k] = $x }
    $rows = @(foreach ($s in $mon.Subs) {
        $x = Get-ConLive $s.Key $idx
        if (Test-ConPass $s.Key $x) { [pscustomobject]@{ S = $s; X = $x } }
    })
    $rank = @{ '' = 0; ok = 1; unknown = 2; warn = 3; error = 4 }
    switch ($conSorts.subs[$con.Sort.subs]) {
        'health' { $rows = @($rows | Sort-Object @{ e = { $rank[$_.X.h] }; Descending = $true }, @{ e = { [double]("0$($_.X.lat)") }; Descending = $true }) }
        'latency' { $rows = @($rows | Sort-Object @{ e = { [double]("0$($_.X.lat)") }; Descending = $true }) }
        'pending' { $rows = @($rows | Sort-Object @{ e = { [double]("0$($_.X['pd'])") }; Descending = $true }) }
        'oldest' { $rows = @($rows | Sort-Object @{ e = { [double]("0$($_.X['old'])") }; Descending = $true }) }
        'flow' { $rows = @($rows | Sort-Object @{ e = { [double]("0$($_.X.rt)") }; Descending = $true }) }
        'publication' { $rows = @($rows | Sort-Object @{ e = { $_.S.Edge.Publication } }, @{ e = { $_.S.Edge.SubServer } }) }
        'subscriber' { $rows = @($rows | Sort-Object @{ e = { "$($_.S.Edge.SubServer)/$($_.S.Edge.SubDb)" } }) }
    }
    $showTrend = $W -ge 120; $showOld = $W -ge 105; $showAge = $W -ge 140
    $fixed = 2 + 8 + 12 + 8 + 10 + 8
    if ($showTrend) { $fixed += 9 }
    if ($showOld) { $fixed += 9 }
    if ($showAge) { $fixed += 9 }
    $rest = [math]::Max(30, $W - $fixed)
    $wPub = [int][math]::Min(18, [math]::Max(8, $rest * 0.18))
    $wRoute = [int][math]::Min(46, [math]::Max(16, $rest * 0.42))
    $wProb = [math]::Max(8, $rest - $wPub - $wRoute - 2)
    $hd = New-ConLine 'DarkGray'
    $t = '  ' + (Format-ConCell 'Health' 8) + (Format-ConCell 'Status' 12) + (Format-ConCell 'Publication' $wPub) + ' ' + (Format-ConCell 'Publisher/DB -> Subscriber/DB' $wRoute) + ' ' +
         (Format-ConCell 'Latency' 7 -Right) + ' '
    if ($showTrend) { $t += (Format-ConCell 'trend' 8) + ' ' }
    $t += (Format-ConCell 'Pending' 9 -Right) + ' '
    if ($showOld) { $t += (Format-ConCell 'Oldest' 8 -Right) + ' ' }
    $t += (Format-ConCell 'cmd/s' 7 -Right) + ' '
    if ($showAge) { $t += (Format-ConCell 'Activity' 8 -Right) + ' ' }
    $t += 'Problem / wait / message'
    Add-ConSeg $hd $t 'White'
    foreach ($r in $rows) {
        $s = $r.S; $x = $r.X; $e = $s.Edge
        $l = New-ConLine
        Add-ConSeg $l '  '
        Add-ConSeg $l '■ ' $conLevelColor[$x.h]; Add-ConSeg $l (Format-ConCell $x.h 6) $conLevelColor[$x.h]
        $stc = $null
        if ($conStatusColor.ContainsKey([string]$x.st)) { $stc = $conStatusColor[[string]$x.st] }
        $stText = $x.st
        if (-not $stText -and $x.job) { $stText = [string]$x.job }   # 'not running' / 'DISABLED' fit the 12-character column
        Add-ConSeg $l (Format-ConCell $stText 12) $stc
        Add-ConSeg $l ((Format-ConCell $e.Publication $wPub) + ' ') 'White'
        Add-ConSeg $l ((Format-ConCell "$($e.PubServer)/$($e.PubDb) -> $($e.SubServer)/$($e.SubDb)" $wRoute) + ' ')
        $lat = $x.lat
        $latTxt = ''
        if ($null -ne $lat) { $latTxt = "$(Format-ConNum $lat) s" }
        Add-ConSeg $l ((Format-ConCell $latTxt 7 -Right) + ' ') (Get-ConNumColor $lat 30 300)
        if ($showTrend) { Add-ConSeg $l ((Get-ConSpark $x.lh 8) + ' ') 'DarkCyan' }
        $pd = $x['pd']
        Add-ConSeg $l ((Format-ConCell (Format-ConNum $pd) 9 -Right) + ' ') (Get-ConNumColor $pd $PendingWarn ($PendingWarn * 10))
        if ($showOld) { Add-ConSeg $l ((Format-ConCell (Format-ConAge $x['old']) 8 -Right) + ' ') (Get-ConNumColor $x['old'] 60 600) }
        Add-ConSeg $l ((Format-ConCell (Format-ConNum $x.rt 1) 7 -Right) + ' ')
        if ($showAge) { Add-ConSeg $l ((Format-ConCell (Format-ConAge $x.age) 8 -Right) + ' ') 'DarkGray' }
        if ($x.blk) { Add-ConSeg $l (Format-ConCell $x.blk $wProb) 'Magenta' }
        elseif ($x.p) { Add-ConSeg $l (Format-ConCell $x.p $wProb) $conLevelColor[$x.h] }
        elseif ($x.wt) { Add-ConSeg $l (Format-ConCell $x.wt $wProb) 'Gray' }
        else { Add-ConSeg $l (Format-ConCell $x.msg $wProb) 'DarkGray' }
        Add-ConItem $items $s.Key @($l)
    }
    return @{ Header = $hd; Items = $items; Count = $rows.Count }
}

function Get-ConLrItems([int]$W) {
    $items = New-Object System.Collections.Generic.List[object]
    $idx = @{}
    foreach ($x in $mon.Out.Lrs) { $idx[$x.k] = $x }
    $rows = @(foreach ($l in $mon.Lrs) {
        $x = Get-ConLive $l.Key $idx
        if (Test-ConPass $l.Key $x) { [pscustomobject]@{ S = $l; X = $x } }
    })
    $rank = @{ '' = 0; ok = 1; unknown = 2; warn = 3; error = 4 }
    switch ($conSorts.lrs[$con.Sort.lrs]) {
        'health' { $rows = @($rows | Sort-Object @{ e = { $rank[$_.X.h] }; Descending = $true }, @{ e = { [double]("0$($_.X.lat)") }; Descending = $true }) }
        'latency' { $rows = @($rows | Sort-Object @{ e = { [double]("0$($_.X.lat)") }; Descending = $true }) }
        'flow' { $rows = @($rows | Sort-Object @{ e = { [double]("0$($_.X.rt)") }; Descending = $true }) }
        'publisher' { $rows = @($rows | Sort-Object @{ e = { "$($_.S.Publisher)/$($_.S.PubDb)" } }) }
    }
    $wDb = [int][math]::Min(36, [math]::Max(16, ($W - 70) * 0.35))
    $wProb = [math]::Max(10, $W - 2 - 8 - 12 - $wDb - 1 - 8 - 9 - 8 - 11 - 9)
    $hd = New-ConLine 'DarkGray'
    Add-ConSeg $hd ('  ' + (Format-ConCell 'Health' 8) + (Format-ConCell 'Status' 12) + (Format-ConCell 'Published database' $wDb) + ' ' + (Format-ConCell 'Latency' 7 -Right) + ' ' +
                    (Format-ConCell 'trend' 8) + ' ' + (Format-ConCell 'cmd/s' 7 -Right) + ' ' + (Format-ConCell 'Commands' 10 -Right) + ' ' + (Format-ConCell 'Activity' 8 -Right) + ' ' + 'AG / problem / message') 'White'
    foreach ($r in $rows) {
        $s = $r.S; $x = $r.X
        $l = New-ConLine
        Add-ConSeg $l '  '
        Add-ConSeg $l '■ ' $conLevelColor[$x.h]; Add-ConSeg $l (Format-ConCell $x.h 6) $conLevelColor[$x.h]
        $stc = $null
        if ($conStatusColor.ContainsKey([string]$x.st)) { $stc = $conStatusColor[[string]$x.st] }
        Add-ConSeg $l (Format-ConCell $x.st 12) $stc
        Add-ConSeg $l ((Format-ConCell "$($s.Publisher)/$($s.PubDb)" $wDb) + ' ') 'White'
        $latTxt = ''
        if ($null -ne $x.lat) { $latTxt = "$(Format-ConNum $x.lat 1) s" }
        Add-ConSeg $l ((Format-ConCell $latTxt 7 -Right) + ' ') (Get-ConNumColor $x.lat 30 300)
        Add-ConSeg $l ((Get-ConSpark $x.lh 8) + ' ') 'DarkCyan'
        Add-ConSeg $l ((Format-ConCell (Format-ConNum $x.rt 1) 7 -Right) + ' ')
        Add-ConSeg $l ((Format-ConCell (Format-ConNum $x['cmds']) 10 -Right) + ' ')
        Add-ConSeg $l ((Format-ConCell (Format-ConAge $x.age) 8 -Right) + ' ') 'DarkGray'
        if ($x.blk) { Add-ConSeg $l (Format-ConCell $x.blk $wProb) 'Magenta' }
        elseif ($x.p) { Add-ConSeg $l (Format-ConCell $x.p $wProb) $conLevelColor[$x.h] }
        else { Add-ConSeg $l (Format-ConCell ((@($x['ag'], $x.msg) | Where-Object { $_ }) -join ' | ') $wProb) 'DarkGray' }
        Add-ConItem $items $s.Key @($l)
    }
    return @{ Header = $hd; Items = $items; Count = $rows.Count }
}

function Get-ConWaitItems([int]$W) {
    $items = New-Object System.Collections.Generic.List[object]
    $blk = @($mon.Out.Blocking | Where-Object { Test-ConText "$($_.lbl) $($_.srv) $($_.w) $($_.hProg) $($_.hHost) $($_.hLogin) $($_.hSql) $($_.res)" } | Sort-Object { -[double]("0$($_.ms)") })
    Add-ConHeader $items "Blocking ($($blk.Count))" $W
    if (-not $blk.Count) { $l = New-ConLine; Add-ConSeg $l '  No replication agent waits for a lock right now.' 'DarkGray'; Add-ConItem $items '' @($l) }
    foreach ($b in $blk) {
        $l1 = New-ConLine; $l2 = New-ConLine; $l3 = New-ConLine
        $secs = [math]::Round([double]("0$($b.ms)") / 1000, 1)
        Add-ConSeg $l1 '  '
        Add-ConSeg $l1 ((Format-ConCell "$secs s" 8 -Right) + '  ') (Get-ConNumColor $secs 5 60)
        if ($b.agentBlocks) {
            Add-ConSeg $l1 'agent blocks ' 'Magenta'; Add-ConSeg $l1 "$($b.lbl) on $($b.srv), session $($b.spid) | $($b.w)"
            Add-ConSeg $l2 "            blocked by $($b.byLbl) (session $($b.by))" 'DarkGray'
        } else {
            Add-ConSeg $l1 $b.lbl 'White'; Add-ConSeg $l1 "  $($b.srv) session $($b.spid) | $($b.w) | $($b.res)"
            $head = @($b.byLbl, $b.hJob, $b.hProg) | Where-Object { $_ } | Select-Object -First 1
            $tran = ''
            if ($b.hTran) { $tran = " | open transactions $($b.hTran)" }
            Add-ConSeg $l2 '            head blocker: ' 'DarkGray'; Add-ConSeg $l2 "$head" 'Magenta'
            Add-ConSeg $l2 " ($(@($b.hHost, $b.hLogin, $b.hDb, $b.hSt) -join ', ')$tran) | chain $($b.chain)" 'DarkGray'
        }
        Add-ConSeg $l3 ('            ' + $b.hSql) 'DarkGray'
        Add-ConItem $items $b.k @($l1, $l2, $l3)
    }
    $ses = @($mon.Out.Sessions | Where-Object { Test-ConText "$($_.lbl) $($_.srv) $($_.w) $($_.sql) $($_.db)" } | Sort-Object { -[double]("0$($_.ms)") })
    Add-ConHeader $items "Agent sessions ($($ses.Count))" $W
    foreach ($x in $ses) {
        $l = New-ConLine
        Add-ConSeg $l ('  ' + (Format-ConCell "$($x.srv) #$($x.spid)" 14) + ' ')
        Add-ConSeg $l ((Format-ConCell "$($x.lbl) ($($x.side))" ([math]::Max(20, [int]($W * 0.38)))) + ' ') 'White'
        $state = $x.st
        if ($x.req) { $state = "$($x.req) $($x.cmd)" }
        Add-ConSeg $l ((Format-ConCell $state 18) + ' ')
        if ($x.blk -and [int]$x.blk -gt 0) { Add-ConSeg $l ((Format-ConCell "$($x.w) $(Format-ConNum ([double]$x.ms / 1000) 1) s blocked by $($x.blk)" 34) + ' ') 'Magenta' }
        elseif ($x.w) { Add-ConSeg $l ((Format-ConCell "$($x.w) $(Format-ConNum ([double]$x.ms / 1000) 1) s" 34) + ' ') }
        else { Add-ConSeg $l ((Format-ConCell '' 34) + ' ') }
        Add-ConSeg $l "cpu $(Format-ConNum $x.cpu) | r/w $(Format-ConNum $x.rd)/$(Format-ConNum $x.wr) | tran $($x.tran)" 'DarkGray'
        Add-ConItem $items $x.k @($l)
    }
    Add-ConHeader $items 'Server waits in the last interval (ms of waiting per second)' $W
    foreach ($sw in @($mon.Waits.Values | Sort-Object { $_.srv })) {
        $l = New-ConLine
        Add-ConSeg $l ('  ' + (Format-ConCell $sw.srv 14) + ' ') 'White'
        $sec = [math]::Max(1, [double]$sw.sec)
        Add-ConSeg $l ((@($sw.top | Select-Object -First 6 | ForEach-Object { "$($_.w) $(Format-ConNum ($_.ms / $sec) 1)" }) -join ' | '))
        Add-ConItem $items '' @($l)
    }
    Add-ConHeader $items 'Waits of agent sessions since the monitor started (last interval)' $W
    foreach ($k in @($mon.AgentWaits.Keys)) {
        $aw = $mon.AgentWaits[$k]
        if (-not $aw.total.Count) { continue }
        $lbl = $k
        if ($mon.SubByKey.ContainsKey($k)) { $lbl = $mon.SubByKey[$k].Label } elseif ($mon.LrByKey.ContainsKey($k)) { $lbl = $mon.LrByKey[$k].Label }
        if (-not (Test-ConText $lbl)) { continue }
        $top = @($aw.total.Keys | Sort-Object { $aw.total[$_] } -Descending | Select-Object -First 4 | ForEach-Object {
            $last = 0
            if ($aw.last.ContainsKey($_)) { $last = $aw.last[$_] }
            "$_ $(Format-ConWait $aw.total[$_]) ($(Format-ConWait $last))"
        })
        $l = New-ConLine
        Add-ConSeg $l ('  ' + (Format-ConCell $lbl ([math]::Max(20, [int]($W * 0.4)))) + ' ') 'White'
        Add-ConSeg $l ($top -join ' | ')
        Add-ConItem $items $k @($l)
    }
    return @{ Header = $null; Items = $items; Count = $blk.Count }
}
function Format-ConWait($Ms) {
    $Ms = [double]$Ms
    if ($Ms -ge 60000) { return "$(Format-ConNum ($Ms / 60000) 1) min" }
    if ($Ms -ge 1000) { return "$(Format-ConNum ($Ms / 1000) 1) s" }
    return "$(Format-ConNum $Ms) ms"
}

function Get-ConAgItems([int]$W) {
    $items = New-Object System.Collections.Generic.List[object]
    $hd = New-ConLine 'DarkGray'
    Add-ConSeg $hd ('  ' + (Format-ConCell 'Health' 8) + (Format-ConCell 'AG / database' 26) + (Format-ConCell 'Replica (role)' 26) + (Format-ConCell 'Mode' 13) + (Format-ConCell 'Synchronization' 18) +
                    (Format-ConCell 'Send MB' 9 -Right) + (Format-ConCell 'Redo MB' 9 -Right) + (Format-ConCell 'Lag' 8 -Right) + '  Problems') 'White'
    $rows = @($mon.Out.Ag | Where-Object { Test-ConText "$($_.ag) $($_.db) $($_.replica) $($_.role) $($_.sync) $($_.p)" })
    foreach ($a in $rows) {
        $l = New-ConLine
        Add-ConSeg $l '  '; Add-ConSeg $l '■ ' $conLevelColor[$a.h]; Add-ConSeg $l (Format-ConCell $a.h 6) $conLevelColor[$a.h]
        Add-ConSeg $l (Format-ConCell "$($a.ag) / $($a.db)" 26) 'White'
        Add-ConSeg $l (Format-ConCell "$($a.replica) ($($a.role))" 26)
        Add-ConSeg $l (Format-ConCell (([string]$a.mode).Replace('_COMMIT', '').ToLowerInvariant()) 13)
        $syncColor = $null
        if ($a.conn -and $a.conn -ne 'CONNECTED') { $syncColor = 'Red' }
        Add-ConSeg $l (Format-ConCell "$($a.sync) $(if ($a.conn -and $a.conn -ne 'CONNECTED') { $a.conn })" 18) $syncColor
        $send = ''; $redo = ''
        if ($null -ne $a.sendKb) { $send = Format-ConNum ($a.sendKb / 1024) 1 }
        if ($null -ne $a.redoKb) { $redo = Format-ConNum ($a.redoKb / 1024) 1 }
        Add-ConSeg $l (Format-ConCell $send 9 -Right); Add-ConSeg $l (Format-ConCell $redo 9 -Right)
        $lag = ''
        if ($null -ne $a.lag) { $lag = "$($a.lag) s" }
        Add-ConSeg $l (Format-ConCell $lag 8 -Right) (Get-ConNumColor $a.lag 30 300)
        Add-ConSeg $l "  $($a.p)" $conLevelColor[$a.h]
        Add-ConItem $items '' @($l)
    }
    if (-not $rows.Count) { $l = New-ConLine; Add-ConSeg $l '  No availability group data (no AG, or the login lacks VIEW SERVER STATE).' 'DarkGray'; Add-ConItem $items '' @($l) }
    return @{ Header = $hd; Items = $items; Count = $rows.Count }
}

function Get-ConErrorItems([int]$W) {
    $items = New-Object System.Collections.Generic.List[object]
    $list = @($mon.Errors | Where-Object { Test-ConText "$($_.lbl) $($_.m) $($_.code) $($_.srv) $($_.more -join ' ')" })
    $groups = Get-ConErrors $list
    $con.ErrGroups = $groups
    $i = 0
    foreach ($g in $groups) {
        $e = $g.E
        $c = Get-ConCause $e
        $l = New-ConLine
        Add-ConSeg $l ('  ' + ([string]$e.t).Substring([math]::Min(5, ([string]$e.t).Length)) + '  ') 'DarkGray'
        Add-ConSeg $l ((Format-ConCell $e.lbl ([math]::Max(20, [int]($W * 0.3)))) + ' ') 'White'
        $codeTxt = "$($e.code)"
        if ("$($c[0])" -ne "$($e.code)") { $codeTxt = "$($e.code)>$($c[0])" }
        Add-ConSeg $l ((Format-ConCell $codeTxt 12) + ' ') 'Red'
        Add-ConSeg $l $c[1]
        $lines = @($l)
        if ($g.N -gt 1) { $l2 = New-ConLine; Add-ConSeg $l2 "                 repeated $($g.N) times since $($g.First)" 'Yellow'; $lines += $l2 }
        Add-ConItem $items "err:$i" $lines
        $i++
    }
    if (-not $groups.Count) { $l = New-ConLine; Add-ConSeg $l '  No replication errors.' 'DarkGray'; Add-ConItem $items '' @($l) }
    return @{ Header = $null; Items = $items; Count = $groups.Count }
}

function Get-ConEventItems([int]$W) {
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($e in $mon.Events) {
        if ($items.Count -ge 200) { break }   # the newest 200 (the web page shows all 500)
        if (-not (Test-ConText $e.x)) { continue }
        $l = New-ConLine
        Add-ConSeg $l ('  ' + $e.t + ' ') 'DarkGray'; Add-ConSeg $l '■ ' $conLevelColor[$e.l]; Add-ConSeg $l $e.x
        Add-ConItem $items $e.k @($l)
    }
    return @{ Header = $null; Items = $items; Count = $mon.Events.Count }
}
function Get-ConServerItems([int]$W) {
    $items = New-Object System.Collections.Generic.List[object]
    $hd = New-ConLine 'DarkGray'
    Add-ConSeg $hd ('  ' + (Format-ConCell 'Server' 22) + (Format-ConCell 'State' 40) + (Format-ConCell 'Query' 8 -Right) + '  ' + (Format-ConCell 'At' 9) + 'Connected as') 'White'
    foreach ($t in $mon.Targets.Values) {
        $l = New-ConLine
        Add-ConSeg $l ('  ' + (Format-ConCell $t.Name 22)) 'White'
        if ($t.Ok -eq $false) { Add-ConSeg $l (Format-ConCell $t.Err 40) 'Red' }
        elseif ($t.Ok) { Add-ConSeg $l (Format-ConCell 'OK' 40) 'Green' }
        else { Add-ConSeg $l (Format-ConCell 'waiting for the first answer' 40) 'DarkGray' }
        $took = ''
        if ($null -ne $t.Took) { $took = "$($t.Took) s" }
        if ($t.PS) { $took = "$([int]((Get-Date) - $t.Started).TotalSeconds) s.." }
        Add-ConSeg $l ((Format-ConCell $took 8 -Right) + '  ' + (Format-ConCell $t.At 9))
        Add-ConSeg $l $t.Target 'DarkGray'
        $lines = @($l)
        foreach ($n in @($t.Notes)) { foreach ($part in (Split-ConText $n ($W - 8))) { $ln = New-ConLine; Add-ConSeg $ln "      $part" 'Yellow'; $lines += $ln } }
        Add-ConItem $items '' $lines
    }
    return @{ Header = $hd; Items = $items; Count = $mon.Targets.Count }
}
function Get-ConFindingItems([int]$W) {
    $items = New-Object System.Collections.Generic.List[object]
    $sev = @{ error = 0; warn = 1; info = 2 }
    $i = 0
    $con.FindList = @($findings | Sort-Object { $sev[$_.Severity] }, Category, Server)
    foreach ($f in $con.FindList) {
        if (Test-ConText "$($f.Severity) $($f.Category) $($f.Server) $($f.Object) $($f.Finding)") {
            $l = New-ConLine
            Add-ConSeg $l '  '; Add-ConSeg $l (Format-ConCell $f.Severity 6) $conLevelColor[$f.Severity]
            Add-ConSeg $l ((Format-ConCell $f.Category 12) + ' ') 'White'
            Add-ConSeg $l ((Format-ConCell "$($f.Server) $($f.Object)" ([math]::Max(16, [int]($W * 0.25)))) + ' ')
            Add-ConSeg $l $f.Finding 'Gray'
            Add-ConItem $items "find:$i" @($l)
        }
        $i++
    }
    return @{ Header = $null; Items = $items; Count = $con.FindList.Count }
}

# --- detail views (scrollable lines) ---
function Format-ConTime($T) { $s = [string]$T; if ($s.Length -ge 19) { return $s.Substring(5) } return $s }
function Add-ConKv($Lines, [string]$Name, $Value, $Fg = $null, [int]$W = 100) {
    $first = $true
    foreach ($part in (Split-ConText $Value ($W - 18))) {
        $l = New-ConLine
        if ($first) { Add-ConSeg $l (' ' + (Format-ConCell $Name 16) + ' ') 'DarkGray' } else { Add-ConSeg $l (' ' * 18) }
        Add-ConSeg $l $part $Fg
        $Lines.Add($l)
        $first = $false
    }
}
function Add-ConTitle($Lines, [string]$Text, [int]$W) {
    $Lines.Add((New-ConLine))
    $l = New-ConLine
    Add-ConSeg $l (" $Text ".PadRight($W, '-')) 'Cyan'
    $Lines.Add($l)
}
function Add-ConWrapped($Lines, $Text, [int]$Indent, [int]$W, $Fg = $null) {
    foreach ($part in (Split-ConText $Text ($W - $Indent - 1))) { $l = New-ConLine; Add-ConSeg $l ((' ' * $Indent) + $part) $Fg; $Lines.Add($l) }
}
function Get-ConStrip($Values, [int]$Len, [switch]$Status) {
    $n = @($Values).Count
    if (-not $n) { return @() }
    $segs = New-Object System.Collections.Generic.List[object]
    $max = 0
    foreach ($v in $Values) { if ($null -ne $v -and [double]$v -gt $max) { $max = [double]$v } }
    $sev = @{ 0 = 0; 1 = 1; 4 = 2; 3 = 3; 2 = 4; 5 = 5; 6 = 6 }
    for ($i = 0; $i -lt $Len; $i++) {
        $a = [int][math]::Floor($i * $n / $Len); $b = [int][math]::Max($a + 1, [math]::Floor(($i + 1) * $n / $Len))
        $best = $null
        for ($j = $a; $j -lt $b -and $j -lt $n; $j++) {
            $v = $Values[$j]
            if ($null -eq $v) { continue }
            if ($Status) { if ($null -eq $best -or $sev[[int]$v] -gt $sev[[int]$best]) { $best = [int]$v } }
            elseif ($null -eq $best -or [double]$v -gt $best) { $best = [double]$v }
        }
        if ($Status) {
            $map = @{ 3 = @('█', 'Green'); 4 = @('░', 'Cyan'); 1 = @('▒', 'Green'); 2 = @('░', 'DarkGray'); 5 = @('▓', 'Yellow'); 6 = @('█', 'Red') }
            if ($null -ne $best -and $map.ContainsKey($best)) { $segs.Add($map[$best]) } else { $segs.Add(@(' ', $null)) }
        } else {
            $ch = ' '
            if ($null -ne $best -and $max -gt 0) { $ch = ' ░▒▓█'[[int][math]::Ceiling(4 * $best / $max)] }
            $segs.Add(@($ch, 'DarkCyan'))
        }
    }
    return , $segs
}
function Add-ConStripLine($Lines, [string]$Name, [string]$Value, $Segs) {
    $l = New-ConLine
    Add-ConSeg $l (' ' + (Format-ConCell $Name 16) + ' ') 'DarkGray'
    Add-ConSeg $l ((Format-ConCell $Value 12) + ' ')
    foreach ($s in $Segs) { Add-ConSeg $l $s[0] $s[1] }
    $Lines.Add($l)
}
function Get-ConStatsLines($Lines, $Msgs, [bool]$IsLr, [int]$W) {
    $m = $null
    foreach ($x in $Msgs) { if ([string]$x.m -match '^\s*<stats') { $m = $x; break } }
    if (-not $m) { return }
    try { $doc = [xml]([string]$m.m) } catch { return }
    $st = $doc.stats
    if (-not $st) { return }
    $since = $null
    if ($st.PSObject.Properties['sincelaststats']) { $since = $st.sincelaststats }
    $src = $st
    if ($since) { $src = $since }
    $r = $null; $wr = $null
    if ($src.PSObject.Properties['reader']) { $r = $src.reader }
    if ($src.PSObject.Properties['writer']) { $wr = $src.writer }
    $elapsed = ''
    if ($since) { $elapsed = ", last $(Format-ConAge $since.elapsedtime)" }
    Add-ConTitle $Lines "Agent statistics ($($m.t)$elapsed)" $W
    $rd = 'reader (distribution database)'; $wn = 'writer (subscriber)'
    if ($IsLr) { $rd = 'reader (transaction log)'; $wn = 'writer (distribution database)' }
    if ($since) { Add-ConKv $Lines 'Commands' "$(Format-ConNum $since.cmds) ($(Format-ConNum $since.cmdspersec 1) cmd/s while working)" $null $W }
    if ($r) { Add-ConKv $Lines 'Reader' "$rd - fetching $($r.fetch) s, waiting for the writer $($r.wait) s" $null $W }
    if ($wr) { Add-ConKv $Lines 'Writer' "$wn - writing $($wr.write) s, waiting for the reader $($wr.wait) s (waiting is normal when there is nothing to do)" $null $W }
    $state = [int]("0$($st.state)")
    $verdict = ''
    if ($state -eq 2) { if ($IsLr) { $verdict = 'The reader waits for the writer: writing to the distribution database is the bottleneck.' } else { $verdict = 'The reader waits for the writer: applying the commands at the subscriber is the bottleneck (load or blocking at the subscriber, triggers, indexes, storage).' } }
    elseif ($state -eq 3) { if ($IsLr) { $verdict = 'The writer waits for the reader: reading the transaction log is the bottleneck (large transactions, slow log storage, AG secondary not hardened).' } else { $verdict = 'The writer waits for the reader: reading the commands from the distribution database is the bottleneck (distributor load, large MSrepl_commands, cleanup job, network).' } }
    if ($verdict) { Add-ConKv $Lines 'Verdict' $verdict 'Yellow' $W }
}


# Repairs in the console: a numbered list in the detail, the chosen one in its own view (x runs it, w saves it)
function Add-ConRepairLines($Lines, $Acts, [int]$W) {
    if (-not $Acts -or $Acts.Count -eq 0) { return }
    Add-ConTitle $Lines 'Repairs (press the number to see one)' $W
    $col = @{ safe = 'Green'; full = 'Yellow'; script = 'Cyan' }
    $how = @{ safe = 'safe'; full = 'changes data/settings'; script = 'script only' }
    $i = 0
    foreach ($a in $Acts) {
        if (++$i -gt 9) { break }
        $note = ''
        if ($a.level -eq 'full' -and $repairMode -ne 'all') { $note = '  (runs here with -AllowAllRepair)' }
        elseif ($a.level -eq 'safe' -and $repairMode -eq 'none') { $note = '  (runs here with -AllowRepair)' }
        Add-ConKv $Lines "  $i" "[$($how[$a.level])] $($a.title)$note" $col[$a.level] $W
    }
}
function Invoke-ConRepair($D, [string]$Phrase) {
    $why = Start-MonRepair $null $D.ItemKey ([int]$D.FindId) $D.Action.id $Phrase
    if ($why) { Set-ConMsg $why } else { Set-ConMsg "Running: $($D.Action.title) ..." }
}
function Get-ConDetailLines([int]$W) {
    $d = $con.Detail
    $lines = New-Object System.Collections.Generic.List[object]
    if ($d.Kind -eq 'text') {
        foreach ($p in $d.Parts) { Add-ConKv $lines $p[0] $p[1] $p[2] $W }
        if ($null -ne $d['FindId'] -and $d.FindId -ge 0) { $d.Acts = Get-FindingRepairs $findings[$d.FindId]; Add-ConRepairLines $lines $d.Acts $W }
        return , $lines
    }
    if ($d.Kind -eq 'repair') {
        $a = $d.Action
        $lvl = @{ safe = 'safe - runs here with -AllowRepair'; full = 'changes data or settings - runs here with -AllowAllRepair'; script = 'script only - needs a password or a decision: save it (w) and run it in SSMS' }
        Add-ConKv $lines 'Level' $lvl[$a.level] (@{ safe = 'Green'; full = 'Yellow'; script = 'Cyan' }[$a.level]) $W
        Add-ConKv $lines 'For' $d.Label 'White' $W
        Add-ConKv $lines 'Why' $a.why $null $W
        Add-ConKv $lines 'Risk' $a.risk 'Yellow' $W
        Add-ConKv $lines 'Undo' $a.undo $null $W
        Add-ConKv $lines 'Check' $a.check $null $W
        $keys = 'w save it as a .sql file'
        if ($a.level -ne 'script' -and (Test-RepairAllowed $a)) { $keys = 'x run it   w save it as a .sql file' }
        if ($a.level -eq 'full' -and (Test-RepairAllowed $a)) { $keys += "   (x asks you to type $($a.confirm))" }
        Add-ConKv $lines 'Keys' $keys 'Cyan' $W
        Add-ConTitle $lines 'T-SQL (SSMS: Query > SQLCMD Mode)' $W
        foreach ($ln in ((Format-RepairScript $d.Label $a) -split "`r?`n")) { $l = New-ConLine; Add-ConSeg $l (' ' + $ln) 'Gray'; $lines.Add($l) }
        return , $lines
    }
    if ($d.Kind -eq 'err') {
        $e = $d.Err; $c = Get-ConCause $e
        Add-ConKv $lines 'Time' $e.t $null $W
        Add-ConKv $lines 'Agent' $e.lbl 'White' $W
        Add-ConKv $lines 'Distributor' "$($e.srv) / $($e.db)" $null $W
        Add-ConKv $lines 'Error' "$($e.code)" 'Red' $W
        Add-ConKv $lines 'Message' $e.m $null $W
        if ("$($c[0])" -ne "$($e.code)") { Add-ConKv $lines 'Cause' "$($c[0]): $($c[1])" 'Red' $W }
        if ($d.N -gt 1) { Add-ConKv $lines 'Repeated' "$($d.N) times since $($d.First)" 'Yellow' $W }
        if ($monHints.Contains("$($c[0])")) { Add-ConKv $lines 'What to do' $monHints["$($c[0])"] 'Cyan' $W }
        foreach ($m in $e.more) { Add-ConKv $lines 'Details' $m 'DarkGray' $W }
        Add-ConCommandLines $lines $e.srv $e.db $e.seq $e.cmd $e['agent'] $W
        return , $lines
    }
    $isSub = ($d.Kind -eq 'sub')
    $idx = @{}
    if ($isSub) { foreach ($x in $mon.Out.Subs) { $idx[$x.k] = $x } } else { foreach ($x in $mon.Out.Lrs) { $idx[$x.k] = $x } }
    $x = Get-ConLive $d.Key $idx
    Add-ConKv $lines 'Health' ("$($x.h)  " + $x.p) $conLevelColor[$x.h] $W
    $job = ''
    if ($x.job) { $job = " | agent job $($x.job)" }
    $stc = $null
    if ($conStatusColor.ContainsKey([string]$x.st)) { $stc = $conStatusColor[[string]$x.st] }
    Add-ConKv $lines 'Status' ("$($x.st)$job" -replace '^ \| ', '') $stc $W
    $lat = ''
    if ($null -ne $x.lat) { $lat = "$(Format-ConNum $x.lat 1) s   trend $(Get-ConSpark $x.lh 20)" }
    Add-ConKv $lines 'Latency' $lat (Get-ConNumColor $x.lat 30 300) $W
    if ($isSub) {
        $pd = ''
        if ($null -ne $x['pd']) {
            $pd = Format-ConNum $x['pd']
            if ($null -ne $x['eta']) { $pd += " | about $(Format-ConAge $x['eta']) of agent work" }
            if ($null -ne $x['old']) { $pd += " | oldest undelivered transaction $(Format-ConAge $x['old']) old" }
        }
        Add-ConKv $lines 'Pending commands' $pd (Get-ConNumColor $x['pd'] $PendingWarn ($PendingWarn * 10)) $W
    }
    $rt = ''
    if ($null -ne $x.rt) { $rt = "$(Format-ConNum $x.rt 1) cmd/s   trend $(Get-ConSpark $x.rh 20)" }
    Add-ConKv $lines 'Flow' $rt $null $W
    $last = ''
    if ($x['last']) { $last = "$($x['last'])" }
    if ($null -ne $x.age) { $last += " | last agent entry $(Format-ConAge $x.age) ago" }
    Add-ConKv $lines 'Last activity' ($last -replace '^ \| ', '') $null $W
    Add-ConKv $lines 'Last message' $x.msg 'Gray' $W
    if ($x.blk) { Add-ConKv $lines 'Blocking' $x.blk 'Magenta' $W }
    if ($isSub) {
        $s = $mon.SubByKey[$d.Key]; $e = $s.Edge
        $tables = ''
        if ($e.Tables) { $tables = " | $($e.Tables) tables" }
        Add-ConKv $lines 'Type' "$($e.PubType) | $($e.SubType)$tables" $null $W
        foreach ($f in (Get-PubFilters $e.PubServer $e.PubDb $e.Publication)) {
            $t = "$($f.Article):"
            if ($f.Rows) { $t += " rows WHERE $($f.Rows)" }
            if ($f.Excluded) { $t += " columns not published: $($f.Excluded)" }
            Add-ConKv $lines 'Filter' $t 'Cyan' $W
        }
        Add-ConKv $lines 'Distributor' "$($e.Distributor) / $($e.DistributionDb) | agent id $($s.AgentId)" $null $W
        if ($s.Notes) { Add-ConKv $lines 'Notes (scan)' $s.Notes 'DarkYellow' $W }
        if ($s.LrKey) {
            $lx = $null
            foreach ($y in $mon.Out.Lrs) { if ($y.k -eq $s.LrKey) { $lx = $y } }
            if ($lx) { Add-ConKv $lines 'Log Reader' "$($lx.h) | $($lx.st) | latency $($lx.lat) s $($lx.p)" $conLevelColor[$lx.h] $W }
        }
    } else {
        $l = $mon.LrByKey[$d.Key]
        Add-ConKv $lines 'Commands (session)' (Format-ConNum $x['cmds']) $null $W
        Add-ConKv $lines 'Availability group' $x['ag'] $null $W
        Add-ConKv $lines 'Distributor' "$($l.DistInst) / $($l.DistDb) | agent id $($l.AgentId)" $null $W
    }
    if (@($x.ses).Count) {
        Add-ConTitle $lines 'Agent sessions now' $W
        foreach ($e in $x.ses) {
            $l = New-ConLine
            $state = $e.st
            if ($e.req) { $state = "$($e.req) $($e.cmd)" }
            Add-ConSeg $l ("  $($e.srv) #$($e.spid) $($e.side) | $state")
            if ($e.blk -and [int]$e.blk -gt 0) { Add-ConSeg $l " | $($e.w) $(Format-ConNum ([double]$e.ms / 1000) 1) s blocked by $($e.blk)" 'Magenta' }
            elseif ($e.w) { Add-ConSeg $l " | $($e.w) $(Format-ConNum ([double]$e.ms / 1000) 1) s" }
            Add-ConSeg $l " | cpu $(Format-ConNum $e.cpu) | open tran $($e.tran)" 'DarkGray'
            $lines.Add($l)
            if ($e.sql) { $l2 = New-ConLine; Add-ConSeg $l2 ('     ' + (Format-ConCell $e.sql ($W - 6))) 'DarkGray'; $lines.Add($l2) }
        }
    }
    foreach ($b in @($mon.Out.Blocking | Where-Object { $_.k -eq $d.Key -and -not $_.agentBlocks })) {
        Add-ConTitle $lines 'Blocked by' $W
        $head = @($b.byLbl, $b.hJob, $b.hProg) | Where-Object { $_ } | Select-Object -First 1
        Add-ConKv $lines 'Head blocker' "$head (session $($b.by)) | $(@($b.hHost, $b.hLogin, $b.hDb, $b.hSt) -join ', ') | open transactions $($b.hTran) | chain $($b.chain)" 'Magenta' $W
        Add-ConKv $lines 'Waiting' "$($b.w) $(Format-ConNum ([double]$b.ms / 1000) 1) s on $($b.res)" $null $W
        if ($b.hSql) { Add-ConKv $lines 'SQL' $b.hSql 'DarkGray' $W }
    }
    if ($mon.AgentWaits.ContainsKey($d.Key) -and $mon.AgentWaits[$d.Key].total.Count) {
        $aw = $mon.AgentWaits[$d.Key]
        Add-ConTitle $lines 'Waits of the agent sessions since the monitor started (last interval)' $W
        foreach ($k in @($aw.total.Keys | Sort-Object { $aw.total[$_] } -Descending | Select-Object -First 8)) {
            $last = 0
            if ($aw.last.ContainsKey($k)) { $last = $aw.last[$k] }
            Add-ConKv $lines $k "$(Format-ConWait $aw.total[$k]) ($(Format-ConWait $last))" $null $W
        }
    }
    $d.Acts = Get-MonRepairs $d.Key
    Add-ConRepairLines $lines $d.Acts $W
    # Detail queried in the background: history, pending per article, errors, statistics, tracer tokens
    Add-ConTitle $lines "History, last $($d.Hours) h" $W
    if ($d.Loading) { $l = New-ConLine; Add-ConSeg $l '  loading...' 'DarkGray'; $lines.Add($l) }
    if ($d.ErrText) { Add-ConKv $lines 'Error' $d.ErrText 'Red' $W }
    $data = $d.Data
    if (-not $data) { return , $lines }
    foreach ($n in $data.Notes) { Add-ConKv $lines 'Note' $n 'Yellow' $W }
    $ch = $data.Chart
    if ($ch) {
        $len = [math]::Max(20, $W - 34)
        $latMax = 0
        foreach ($v in $ch.Lat) { if ($null -ne $v -and [double]$v -gt $latMax) { $latMax = [double]$v } }
        $perSec = @(foreach ($v in $ch.Cmds) { [double]$v / [double]$ch.Size })
        $rateMax = 0
        foreach ($v in $perSec) { if ($v -gt $rateMax) { $rateMax = $v } }
        Add-ConStripLine $lines 'Latency' "max $(Format-ConNum $latMax 1) s" (Get-ConStrip $ch.Lat $len)
        Add-ConStripLine $lines 'Commands/s' "max $(Format-ConNum $rateMax 1)" (Get-ConStrip $perSec $len)
        Add-ConStripLine $lines 'Status' '' (Get-ConStrip $ch.St $len -Status)
        $l = New-ConLine
        Add-ConSeg $l ((' ' * 31) + "from $($ch.Start) | █ running ░ idle ▓ retrying ") 'DarkGray'; Add-ConSeg $l '█' 'Red'; Add-ConSeg $l ' failed  ░ stopped' 'DarkGray'
        $lines.Add($l)
    }
    if ($isSub -and $data.Articles.Count) {
        $total = 0
        foreach ($a in $data.Articles) { $total += $a.n }
        $at = ''
        if ([string]$data.Now -match '\d\d:\d\d:\d\d$') { $at = " (read $($Matches[0]))" }   # the header counts at its own refresh
        Add-ConTitle $lines "Pending commands per article: $(Format-ConNum $total) in $(Format-ConNum $data.Transactions) transactions$at" $W
        $max = [math]::Max(1, ($data.Articles | ForEach-Object { $_.n } | Measure-Object -Maximum).Maximum)
        $barW = [math]::Max(10, $W - 60)
        foreach ($a in @($data.Articles | Select-Object -First 15)) {
            $l = New-ConLine
            $name = $a.a
            if ($a.src -and $a.src -ne $a.a) { $name += " ($($a.src))" }
            Add-ConSeg $l ('  ' + (Format-ConCell $name 40) + ' ')
            Add-ConSeg $l (('█' * [math]::Max(1, [int]($barW * $a.n / $max))).PadRight($barW)) 'Cyan'
            Add-ConSeg $l (' ' + (Format-ConNum $a.n))
            $lines.Add($l)
        }
        if ($data.TopTx.Count) {
            Add-ConTitle $lines 'Largest pending transactions (one big transaction delays everything behind it)' $W
            foreach ($t in $data.TopTx) { Add-ConKv $lines (Format-ConTime $t.t) "$(Format-ConNum $t.n) commands | transaction $($t.seq)" $null $W }
        }
    }
    $errs = Get-ConErrors $data.Errors
    Add-ConTitle $lines "Errors in this period ($($data.Errors.Count))" $W
    if (-not $errs.Count) { $l = New-ConLine; Add-ConSeg $l '  none' 'DarkGray'; $lines.Add($l) }
    $srv = ''; $db = ''; $agent = ''
    if ($isSub) { $s = $mon.SubByKey[$d.Key]; $srv = $s.DistInst; $db = $s.DistDb; $agent = $s.AgentId } else { $l0 = $mon.LrByKey[$d.Key]; $srv = $l0.DistInst; $db = $l0.DistDb }
    $d.CmdErr = $null
    foreach ($g in @($errs | Select-Object -First 10)) {
        $e = $g.E; $c = Get-ConCause $e
        $txt = "$($e.code)"
        if ("$($c[0])" -ne "$($e.code)") { $txt += " > $($c[0])" }
        Add-ConKv $lines (Format-ConTime $e.t) "$txt $($c[1])" 'Red' $W
        if ($g.N -gt 1) { Add-ConKv $lines '' "repeated $($g.N) times since $($g.First)" 'Yellow' $W }
        if ($monHints.Contains("$($c[0])")) { Add-ConKv $lines '' $monHints["$($c[0])"] 'Cyan' $W }
        if ($e.seq -and $e.cmd -and -not $d.CmdErr) { $d.CmdErr = @($srv, $db, $e.seq, $e.cmd, $agent); Add-ConCommandLines $lines $srv $db $e.seq $e.cmd $agent $W }
    }
    Get-ConStatsLines $lines $data.Msgs (-not $isSub) $W
    if ($isSub -and $data.Tracer.Count) {
        Add-ConTitle $lines 'Tracer tokens' $W
        foreach ($t in $data.Tracer) {
            $a = 'pending'; $b = 'pending'; $tot = ''
            if ($null -ne $t.toDist) { $a = "$($t.toDist) s" }
            if ($null -ne $t.toSub) { $b = "$($t.toSub) s" }
            if ($null -ne $t.total) { $tot = " | total $($t.total) s" }
            Add-ConKv $lines (Format-ConTime $t.t) "publisher -> distributor $a | distributor -> subscriber $b$tot" $null $W
        }
    }
    if ($data.Msgs.Count) {
        Add-ConTitle $lines 'Agent messages (changes only, newest first)' $W
        $stName = @{ 1 = 'started'; 2 = 'stopped'; 3 = 'running'; 4 = 'idle'; 5 = 'retrying'; 6 = 'failed' }
        foreach ($m in @($data.Msgs | Where-Object { [string]$_.m -notmatch '^\s*<stats' } | Select-Object -First 60)) {
            $n = ''
            if ($null -ne $m.st -and $stName.ContainsKey([int]$m.st)) { $n = $stName[[int]$m.st] }
            $fg = $null
            if ($n -eq 'failed') { $fg = 'Red' } elseif ($n -eq 'retrying') { $fg = 'Yellow' }
            Add-ConKv $lines (Format-ConTime $m.t) "$n  $($m.m)" $fg $W
        }
    }
    return , $lines
}
function Add-ConCommandLines($Lines, $Srv, $Db, $Seq, $Cmd, $Agent, [int]$W) {
    if (-not $Seq -or -not $Cmd) { return }
    $key = "$Srv|$Db|$Seq|$Cmd"
    if ($con.CmdCache.ContainsKey($key)) { Add-ConKv $Lines 'Command' $con.CmdCache[$key] 'White' $W }
    else { Add-ConKv $Lines 'Command' "transaction $Seq, command $Cmd - press c to show the replicated command" 'DarkGray' $W }
}

# --- one frame ---
function Show-ConFrame {
    $W = [Console]::WindowWidth - 1; $H = [Console]::WindowHeight
    if ($W -lt 40 -or $H -lt 10) {
        # too small to draw anything useful; wait for the window to grow
        if ($con.W -ne $W -or $con.H -ne $H) { $con.W = $W; $con.H = $H; $con.Prev = @{}; try { [Console]::Clear() } catch { } }
        if ($W -ge 1 -and $H -ge 1) { [Console]::SetCursorPosition(0, 0); [Console]::Write('Window too small'.Substring(0, [math]::Min(16, $W))) }
        return
    }
    $lines = New-Object System.Collections.Generic.List[object]
    if ($con.SumSeq -ne $mon.Seq) { $con.Sum = Get-MonSummary; $con.SumSeq = $mon.Seq }
    $s = $con.Sum
    # 1: title bar
    $t = New-ConLine 'DarkCyan'
    $state = 'live'
    if ($mon.Paused) { $state = 'PAUSED' }
    $left = " Replication Monitor $scriptVersion | $authText | every $($mon.Interval) s | $((Get-Date).ToString('HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)) $state"
    $right = 'Space pause  r refresh  +/- interval  q quit '
    Add-ConSeg $t ($left + (' ' * [math]::Max(1, $W - $left.Length - $right.Length)) + $right) 'White'
    $lines.Add($t)
    # 2: summary
    $l = New-ConLine
    Add-ConSeg $l ' Subscriptions '; Add-ConSeg $l "$($s.subs.ok) ok " 'Green'
    if ($s.subs.warn) { Add-ConSeg $l "$($s.subs.warn) warn " 'Yellow' }
    if ($s.subs.error) { Add-ConSeg $l "$($s.subs.error) error " 'Red' }
    if ($s.subs.unknown) { Add-ConSeg $l "$($s.subs.unknown) no data " 'DarkGray' }
    Add-ConSeg $l '| Log Readers '; Add-ConSeg $l "$($s.lrs.ok) ok " 'Green'
    if ($s.lrs.warn) { Add-ConSeg $l "$($s.lrs.warn) warn " 'Yellow' }
    if ($s.lrs.error) { Add-ConSeg $l "$($s.lrs.error) error " 'Red' }
    Add-ConSeg $l '| Blocked '; $c = $null; if ($s.blocked) { $c = 'Magenta' }; Add-ConSeg $l "$($s.blocked) " $c
    Add-ConSeg $l '| Errors 1 h '; $c = $null; if ($s.errHour) { $c = 'Red' }; Add-ConSeg $l "$($s.errHour) " $c
    if ($null -ne $s.maxLat) { Add-ConSeg $l '| Max latency '; Add-ConSeg $l "$($s.maxLat) s " (Get-ConNumColor $s.maxLat 30 300) }
    if ($null -ne $s.pending) { Add-ConSeg $l '| Pending '; Add-ConSeg $l "$(Format-ConNum $s.pending) " (Get-ConNumColor $s.pending $PendingWarn ($PendingWarn * 10)) }
    if ($null -ne $s.rate) { Add-ConSeg $l "| Flow $(Format-ConNum $s.rate 1) cmd/s " }
    if ($s.agBad) { Add-ConSeg $l '| AG issues '; Add-ConSeg $l "$($s.agBad) " 'Yellow' }
    if ($s.down) { Add-ConSeg $l '| Servers down '; Add-ConSeg $l "$($s.down) " 'Red' }
    $lines.Add($l)
    # 3: views and filter
    $l = New-ConLine
    for ($i = 0; $i -lt $conViews.Count; $i++) {
        $v = $conViews[$i]
        $txt = " $($i + 1) $($v[1]) "
        if ($con.View -eq $v[0] -and -not $con.Detail) { Add-ConSeg $l $txt 'Black' 'Gray' } else { Add-ConSeg $l $txt 'Gray' }
    }
    $info = ''
    if ($con.Filter) { $info += "  filter: $($con.Filter)" }
    if ($con.Quick) { $info += "  quick: $($conQuick[$con.Quick])" }
    if ($con.View -in 'subs', 'lrs') { $info += "  sort: $($conSorts[$con.View][$con.Sort[$con.View]])" }
    Add-ConSeg $l $info 'Cyan'
    $lines.Add($l)
    # body
    $bottom = 1
    $evRows = 0
    if (-not $con.Detail -and $con.View -in 'subs', 'lrs' -and $H -ge 28) { $evRows = [math]::Min(4, $mon.Events.Count); if ($evRows) { $bottom += $evRows + 1 } }
    $bodyH = [math]::Max(3, $H - $lines.Count - $bottom)
    if ($con.Detail) {
        $d = $con.Detail
        $hd = New-ConLine 'DarkGray'
        $keys = 'Esc back  Up/Down/PgUp/PgDn scroll'
        if ($d.Kind -in 'sub', 'lr') { $keys += "  h history ($($d.Hours) h)  r reload" }
        if ($d.Kind -eq 'sub' -and $AllowTracerTokens) { $keys += '  t tracer token' }
        if ($d.Kind -in 'sub', 'err') { $keys += '  c command' }
        if ($d.Kind -in 'sub', 'lr') { $keys += '  a AI report' }
        if ($d['Acts'] -and $d.Acts.Count) { $keys += '  1-9 repairs' }
        if ($d.Kind -eq 'repair') { $keys = 'Esc back  Up/Down scroll  w save'; if ($d.Action.level -ne 'script' -and (Test-RepairAllowed $d.Action)) { $keys += '  x run' } }
        Add-ConSeg $hd ((Format-ConCell " $($d.Title)" ([math]::Max(10, $W - $keys.Length - 2))) + '  ' + $keys) 'White'
        $lines.Add($hd)
        $dk = "$($d.Kind)|$($d.Key)|$($mon.Seq)|$($d['Loading'])|$($d['Hours'])|$($con.DetailVer)|$($con.CmdCache.Count)|$W"
        if ($con.DetailKey -ne $dk -or -not $con.DetailLines) { $con.DetailLines = Get-ConDetailLines $W; $con.DetailKey = $dk }
        $dl = $con.DetailLines
        $max = [math]::Max(0, $dl.Count - ($bodyH - 1))
        if ($d.Scroll -gt $max) { $d.Scroll = $max }
        if ($d.Scroll -lt 0) { $d.Scroll = 0 }
        $con.PageH = $bodyH - 1
        for ($i = $d.Scroll; $i -lt $dl.Count -and $lines.Count -lt 3 + $bodyH; $i++) { $lines.Add($dl[$i]) }
    } else {
        $base = "$($con.View)|$($con.Filter)|$($con.Quick)|$($con.Sort['subs'])|$($con.Sort['lrs'])|$W"
        $ck = "$base|$($mon.Seq)"
        if ($con.View -eq 'servers') { $ck += "|$((Get-Date).Second)" }   # running query times tick
        # while keys are being pressed, new data waits a moment (at most until the next second's redraw)
        $busy = ($con.CacheBase -eq $base -and $con.Cache -and ((Get-Date) - $con.LastKey).TotalMilliseconds -lt 400)
        if (($con.CacheKey -ne $ck -or -not $con.Cache) -and -not $busy) {
            $con.Cache = switch ($con.View) {
                'subs' { Get-ConSubItems $W } 'lrs' { Get-ConLrItems $W } 'waits' { Get-ConWaitItems $W } 'ag' { Get-ConAgItems $W }
                'errors' { Get-ConErrorItems $W } 'events' { Get-ConEventItems $W } 'servers' { Get-ConServerItems $W } 'findings' { Get-ConFindingItems $W }
            }
            $con.CacheKey = $ck; $con.CacheBase = $base
        }
        $view = $con.Cache
        $avail = $bodyH
        if ($view.Header) { $lines.Add($view.Header); $avail-- }
        $con.PageH = $avail
        # selection by key (stable while the list re-sorts), scrolled into view
        $items = $view.Items
        $con.Items = $items
        $selKey = $con.Sel[$con.View]
        if (-not $con.UserSel.ContainsKey($con.View)) { $selKey = $null }   # follow the top of the list until the user moves
        $selIdx = -1
        for ($i = 0; $i -lt $items.Count; $i++) { if ($items[$i].Key -and $items[$i].Key -eq $selKey) { $selIdx = $i; break } }
        if ($selIdx -lt 0) { for ($i = 0; $i -lt $items.Count; $i++) { if ($items[$i].Key) { $selIdx = $i; $con.Sel[$con.View] = $items[$i].Key; break } } }
        $flat = New-Object System.Collections.Generic.List[object]
        $selFirst = -1; $selLast = -1
        for ($i = 0; $i -lt $items.Count; $i++) {
            if ($i -eq $selIdx) { $selFirst = $flat.Count }
            $firstLine = $true
            foreach ($ln in $items[$i].Lines) {
                if ($i -eq $selIdx) {
                    $cp = @{ Segs = (New-Object System.Collections.Generic.List[object]); Bg = 'DarkBlue' }
                    foreach ($sg in $ln.Segs) { $cp.Segs.Add($sg) }
                    if ($firstLine -and $cp.Segs.Count) { $s0 = [string]$cp.Segs[0][0]; $cp.Segs[0] = @(('>' + $s0.Substring([math]::Min(1, $s0.Length))), 'White', $null) }
                    $flat.Add($cp)
                } else { $flat.Add($ln) }
                $firstLine = $false
            }
            if ($i -eq $selIdx) { $selLast = $flat.Count - 1 }
        }
        $top = 0
        if ($con.Top.ContainsKey($con.View)) { $top = $con.Top[$con.View] }
        if ($selFirst -ge 0) {
            if ($selFirst -lt $top) { $top = $selFirst }
            if ($selLast -ge $top + $avail) { $top = $selLast - $avail + 1 }
        }
        $top = [math]::Max(0, [math]::Min($top, $flat.Count - $avail))
        $con.Top[$con.View] = $top
        for ($i = $top; $i -lt $flat.Count -and $i -lt $top + $avail; $i++) { $lines.Add($flat[$i]) }
        if (-not $flat.Count) {
            $l = New-ConLine
            if ($con.Filter -or $con.Quick) { Add-ConSeg $l '  Nothing matches the filter (Esc clears it).' 'DarkGray' } else { Add-ConSeg $l '  Nothing to show.' 'DarkGray' }
            $lines.Add($l)
        }
    }
    while ($lines.Count -lt $H - $bottom) { $lines.Add((New-ConLine)) }
    if ($evRows) {
        $l = New-ConLine 'DarkGray'; Add-ConSeg $l ' Events'.PadRight($W) 'White'; $lines.Add($l)
        for ($i = 0; $i -lt $evRows; $i++) {
            $e = $mon.Events[$i]
            $l = New-ConLine
            $tt = [string]$e.t
            if ($tt.Length -ge 19) { $tt = $tt.Substring(11) }
            Add-ConSeg $l " $tt " 'DarkGray'; Add-ConSeg $l '■ ' $conLevelColor[$e.l]; Add-ConSeg $l $e.x
            $lines.Add($l)
        }
    }
    # last line: input, message or keys
    $l = New-ConLine 'DarkCyan'
    if ($con.Typing) { Add-ConSeg $l " Filter: $($con.Filter)_   (Enter keeps it, Esc cancels; all words must match)" 'White' }
    elseif ($con.Ask -and $con.Ask.Mode -eq 'yn') { Add-ConSeg $l " Run '$($con.Ask.D.Action.title)'?  y = yes, any other key = no" 'Yellow' }
    elseif ($con.Ask) { Add-ConSeg $l " Type $($con.Ask.Need) and Enter to run '$($con.Ask.D.Action.title)' (Esc cancels): $($con.Ask.Text)_" 'Yellow' }
    elseif ($con.Msg -and ((Get-Date) - $con.MsgAt).TotalSeconds -lt 6) { Add-ConSeg $l " $($con.Msg)" 'White' }
    elseif ($con.Detail) { Add-ConSeg $l ' Esc back | Up/Down scroll | Space pause | q quit' 'White' }
    else { Add-ConSeg $l ' Up/Down select | Enter detail | / filter | p quick filter | s sort | 1-8 views | Esc clear filter | Space pause | r refresh | q quit' 'White' }
    $lines.Add($l)
    Write-ConFrame $lines $W $H
}

# --- keys ---
function Move-ConSel([int]$Delta) {
    $items = $con.Items
    if (-not $items) { return }
    $sel = @(for ($i = 0; $i -lt $items.Count; $i++) { if ($items[$i].Key) { $i } })
    if (-not $sel.Count) { return }
    $cur = [array]::IndexOf(@($sel | ForEach-Object { $items[$_].Key }), [string]$con.Sel[$con.View])
    if ($cur -lt 0) { $cur = 0 }
    $n = [math]::Max(0, [math]::Min($sel.Count - 1, $cur + $Delta))
    $con.Sel[$con.View] = $items[$sel[$n]].Key
    $con.UserSel[$con.View] = $true
}
function Open-ConDetail {
    $k = [string]$con.Sel[$con.View]
    if (-not $k) { return }
    if ($k -like 'err:*') {
        $g = $con.ErrGroups[[int]$k.Substring(4)]
        $con.Detail = @{ Kind = 'err'; Key = $k; Title = "Error $($g.E.code) - $($g.E.lbl)"; Err = $g.E; N = $g.N; First = $g.First; Scroll = 0 }
        return
    }
    if ($k -like 'find:*') {
        $f = $con.FindList[[int]$k.Substring(5)]
        $con.Detail = @{ Kind = 'text'; Key = $k; Title = "Finding: $($f.Category)"; Scroll = 0; FindId = $findings.IndexOf($f); Acts = $null
                         Parts = @(@('Severity', $f.Severity, $conLevelColor[$f.Severity]), @('Category', $f.Category, $null), @('Server', $f.Server, $null), @('Object', $f.Object, 'White'),
                                   @('Finding', $f.Finding, $null), @('Recommendation', $f.Recommendation, 'Cyan')) }
        return
    }
    if ($mon.SubByKey.ContainsKey($k)) { $kind = 'sub'; $title = $mon.SubByKey[$k].Label }
    elseif ($mon.LrByKey.ContainsKey($k)) { $kind = 'lr'; $title = $mon.LrByKey[$k].Label }
    else { return }
    $con.Detail = @{ Kind = $kind; Key = $k; Title = $title; Hours = 6; Data = $null; Loading = $false; ErrText = ''; Scroll = 0; CmdErr = $null }
    Start-ConDetail
}
function Start-ConDetail {
    $d = $con.Detail
    $d.Loading = $true; $d.ErrText = ''; $con.DetailVer++
    $why = Start-MonDetail $null $d.Key $d.Hours
    if ($why) { $d.Loading = $false; $d.ErrText = $why }
}
function Invoke-ConKey($K) {
    $key = [string]$K.Key; $ch = [string]$K.KeyChar
    if ($con.Typing) {
        if ($key -eq 'Enter') { $con.Typing = $false }
        elseif ($key -eq 'Escape') { $con.Filter = $con.FilterBefore; $con.Typing = $false }
        elseif ($key -eq 'Backspace') { if ($con.Filter.Length) { $con.Filter = $con.Filter.Substring(0, $con.Filter.Length - 1) } }
        elseif ([int]$K.KeyChar -ge 32) { $con.Filter += $ch }
        $con.Top[$con.View] = 0
        return
    }
    if ($con.Ask) {
        $q = $con.Ask
        if ($key -eq 'Escape') { $con.Ask = $null; Set-ConMsg 'Cancelled - nothing was run.'; return }
        if ($q.Mode -eq 'yn') {
            $con.Ask = $null
            if ($ch -eq 'y' -or $ch -eq 'Y') { Invoke-ConRepair $q.D 'yes' } else { Set-ConMsg 'Cancelled - nothing was run.' }
            return
        }
        if ($key -eq 'Enter') {
            $con.Ask = $null
            if ($q.Text -ceq $q.Need) { Invoke-ConRepair $q.D $q.Text } else { Set-ConMsg 'Not confirmed - nothing was run.' }
            return
        }
        if ($key -eq 'Backspace') { if ($q.Text.Length) { $q.Text = $q.Text.Substring(0, $q.Text.Length - 1) } }
        elseif ([int]$K.KeyChar -ge 32) { $q.Text += $ch }
        $con.Dirty = $true
        return
    }
    # keys that work everywhere
    if ($ch -eq ' ') { if ($mon.Paused) { [void](Invoke-MonControl 'resume') } else { [void](Invoke-MonControl 'pause') }; return }
    if ($ch -eq 'q' -or $ch -eq 'Q') { [void](Invoke-MonControl 'stop'); return }
    if ($ch -eq '+' -or $ch -eq '-') {
        $steps = @(5, 10, 15, 30, 60, 120, 300)
        $i = [array]::IndexOf($steps, [int]$mon.Interval)
        if ($i -lt 0) { $i = 1 }
        if ($ch -eq '+') { $i = [math]::Min($steps.Count - 1, $i + 1) } else { $i = [math]::Max(0, $i - 1) }
        [void](Invoke-MonControl 'interval' $steps[$i]); Set-ConMsg "Refresh every $($steps[$i]) s"
        return
    }
    if ($con.Detail) {
        $d = $con.Detail; $page = [math]::Max(1, $con.PageH - 1)
        switch ($key) {
            'Escape' { if ($d.Kind -eq 'repair') { $con.Detail = $d.Parent } else { $con.Detail = $null }; return }
            'Backspace' { if ($d.Kind -eq 'repair') { $con.Detail = $d.Parent } else { $con.Detail = $null }; return }
            'UpArrow' { $d.Scroll--; return }
            'DownArrow' { $d.Scroll++; return }
            'PageUp' { $d.Scroll -= $page; return }
            'PageDown' { $d.Scroll += $page; return }
            'Home' { $d.Scroll = 0; return }
            'End' { $d.Scroll = 100000; return }
        }
        if ($ch -match '^[1-9]$' -and $d.Kind -ne 'repair' -and $d['Acts'] -and [int]$ch -le $d.Acts.Count) {
            $a = $d.Acts[[int]$ch - 1]
            $rv = @{ Kind = 'repair'; Key = "rep|$($d.Key)|$($a.id)"; Title = "Repair: $($a.title)"; Action = $a; Parent = $d; ItemKey = ''; FindId = -1; Label = $d.Title; Scroll = 0 }
            if ($d.Kind -in 'sub', 'lr') { $rv.ItemKey = $d.Key }
            elseif ($null -ne $d['FindId']) { $rv.FindId = $d.FindId; $f = $findings[$d.FindId]; $rv.Label = "$($f.Server) $($f.Object)" }
            $con.Detail = $rv
            return
        }
        if ($d.Kind -eq 'repair') {
            if ($ch -eq 'w') {
                try {
                    if (-not (Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
                    $file = Join-Path $OutputDir ("repair-$($d.Action.id)-$((Get-Date).ToString('yyyyMMdd-HHmmss')).sql")
                    [System.IO.File]::WriteAllText($file, (Format-RepairScript $d.Label $d.Action), (New-Object System.Text.UTF8Encoding $true))
                    Set-ConMsg "Saved: $file"
                } catch { Set-ConMsg "Cannot save the script: $($_.Exception.Message)" }
            } elseif ($ch -eq 'x') {
                $a = $d.Action
                if ($a.level -eq 'script') { Set-ConMsg 'This repair is a script only - save it with w and run it in SSMS.' }
                elseif (-not (Test-RepairAllowed $a)) { if ($a.level -eq 'full') { Set-ConMsg 'This repair needs the monitor started with -AllowAllRepair.' } else { Set-ConMsg 'Repairs need the monitor started with -AllowRepair.' } }
                elseif ($mon.Repair) { Set-ConMsg 'Another repair is running - wait until it ends.' }
                elseif ($a.level -eq 'full') { $con.Ask = @{ Mode = 'text'; Need = $a.confirm; Text = ''; D = $d } }
                else { $con.Ask = @{ Mode = 'yn'; D = $d } }
                $con.Dirty = $true
            }
            return
        }
        if ($ch -eq 'a' -and $d.Kind -in 'sub', 'lr') {
            try {
                $r = New-MonAiReport $d.Key
                if ($r.PSObject.Properties['Error']) { Set-ConMsg $r.Error }
                else {
                    $t = "Report for AI saved: $($r.File)"
                    if ($r.Map) { $t += " - names masked, tokens in $(Split-Path $r.Map -Leaf) (keep it, do not paste it)" } else { $t += ' - NOT masked (-NoMask)' }
                    Set-ConMsg $t
                }
            } catch { Set-ConMsg "Report for AI: $($_.Exception.Message)" }
            return
        }
        if ($ch -eq 'h' -and $d.Kind -in 'sub', 'lr') {
            $hs = @(1, 6, 24, 72, 168, 720)
            $i = [array]::IndexOf($hs, [int]$d.Hours)
            $d.Hours = $hs[($i + 1) % $hs.Count]; Start-ConDetail
        } elseif ($ch -eq 'r' -and $d.Kind -in 'sub', 'lr') { Start-ConDetail; Set-ConMsg 'Reloading the detail...' }
        elseif ($ch -eq 't' -and $d.Kind -eq 'sub') {
            $why = Start-MonTracer $null $d.Key
            if ($why) { Set-ConMsg $why } else { Set-ConMsg 'Posting a tracer token...' }
        } elseif ($ch -eq 'c') {
            $c = $null
            if ($d.Kind -eq 'err') { $c = @($d.Err.srv, $d.Err.db, $d.Err.seq, $d.Err.cmd, $d.Err['agent']) }
            elseif ($d.Kind -eq 'sub') { $c = $d.CmdErr }
            if (-not $c -or -not $c[2] -or -not $c[3]) {
                if ($d.Kind -eq 'sub') { Set-ConMsg 'No error in this period points to a replicated command.' } else { Set-ConMsg 'This error does not point to a replicated command.' }
                return
            }
            $ck = "$($c[0])|$($c[1])|$($c[2])|$($c[3])"
            $why = Start-MonCommand $null $c[0] $c[1] $c[2] $c[3] $c[4]
            if ($why) { Set-ConMsg $why } else { $con.CmdCache[$ck] = 'reading the command...' }
        }
        return
    }
    switch ($key) {
        'UpArrow' { Move-ConSel -1; return }
        'DownArrow' { Move-ConSel 1; return }
        'PageUp' { Move-ConSel (-[math]::Max(1, $con.PageH - 1)); return }
        'PageDown' { Move-ConSel ([math]::Max(1, $con.PageH - 1)); return }
        'Home' { Move-ConSel -100000; return }
        'End' { Move-ConSel 100000; return }
        'Enter' { Open-ConDetail; return }
        'Escape' { $con.Filter = ''; $con.Quick = 0; return }
    }
    if ($ch -match '^[1-8]$') { $con.View = $conViews[[int]$ch - 1][0]; return }
    switch ($ch) {
        '/' { $con.FilterBefore = $con.Filter; $con.Typing = $true }
        'p' { $con.Quick = ($con.Quick + 1) % $conQuick.Count; $con.Top[$con.View] = 0 }
        's' { if ($con.View -in 'subs', 'lrs') { $con.Sort[$con.View] = ($con.Sort[$con.View] + 1) % $conSorts[$con.View].Count } }
        'r' { [void](Invoke-MonControl 'refresh'); Set-ConMsg 'Querying all servers now (pending commands too)...' }
    }
}
# Answers of background queries started from the console
function Complete-ConQuery($D, $X, [string]$Err) {
    $con.DetailVer++
    switch ($D.Kind) {
        'detail' {
            if ($con.Detail -and $con.Detail.Key -eq $D.Extra) { $con.Detail.Loading = $false; $con.Detail.ErrText = $Err; if (-not $Err) { $con.Detail.Data = $X } }
        }
        'cmd' {
            if ($Err) { $con.CmdCache[$D.Extra] = "cannot read the command: $Err" }
            elseif ($X.Cmd) { $con.CmdCache[$D.Extra] = $X.Cmd }
            else { $con.CmdCache[$D.Extra] = 'The command is no longer in the distribution database.' }
        }
        'post' {
            if ($Err) { Set-ConMsg "Tracer token: $Err" }
            elseif ($null -ne $X.TracerId) { Set-ConMsg "Tracer token $($X.TracerId) posted - the times appear when it reaches the subscribers"; $con.Reload = @((Get-Date).AddSeconds(6), (Get-Date).AddSeconds(25)) }
        }
    }
    $con.Dirty = $true
}
function Step-ConUi {
    $did = $false
    while ([Console]::KeyAvailable) {
        $k = [Console]::ReadKey($true)
        try { Invoke-ConKey $k } catch { Set-ConMsg "Key error: $($_.Exception.Message)" }
        $did = $true; $con.Dirty = $true; $con.LastKey = Get-Date
    }
    if ($con.Reload.Count -and $con.Detail -and $con.Detail.Kind -eq 'sub' -and (Get-Date) -ge $con.Reload[0]) {
        $con.Reload = @($con.Reload | Select-Object -Skip 1)
        Start-ConDetail
    }
    $now = Get-Date
    if ($con.Dirty -or $con.LastSeq -ne $mon.Seq -or ($now - $con.LastDraw).TotalMilliseconds -ge 1000 -or ([Console]::WindowWidth - 1) -ne $con.W -or [Console]::WindowHeight -ne $con.H) {
        try { Show-ConFrame }
        catch {
            # never stop on a drawing problem: show it in the bottom line and draw everything again
            $con.Prev = @{}
            try { [Console]::SetCursorPosition(0, [math]::Max(0, [Console]::WindowHeight - 1)); [Console]::Write(("Display error: $($_.Exception.Message)").PadRight([math]::Max(1, [Console]::WindowWidth - 1)).Substring(0, [math]::Max(1, [Console]::WindowWidth - 1))) } catch { }
        }
        $con.Dirty = $false; $con.LastSeq = $mon.Seq; $con.LastDraw = $now; $did = $true
    }
    return $did
}

# Web mode: listener on -ListenAddress/-Port (next free port when taken), access key, page
function Start-MonWeb {
    $ip = [Net.IPAddress]::Loopback
    if ($ListenAddress -and $ListenAddress -ne 'localhost') {
        $parsed = $null
        if (-not [Net.IPAddress]::TryParse($ListenAddress, [ref]$parsed)) { throw "-ListenAddress '$ListenAddress' is not an IP address. Use 127.0.0.1 (this computer only), 0.0.0.0 (all addresses) or an IP address of this computer." }
        $ip = $parsed
    }
    $listener = $null; $tryPort = $Port; $lastErr = ''
    for ($i = 0; $i -lt 10 -and -not $listener; $i++) {
        try {
            $l = New-Object System.Net.Sockets.TcpListener($ip, $tryPort)
            $l.Start(); $listener = $l
        } catch { $lastErr = $_.Exception.Message; $tryPort++ }
    }
    if (-not $listener) { throw "Cannot listen on $ListenAddress ports $Port-$($tryPort - 1): $lastErr. Use -Port." }
    $mon.Token = [guid]::NewGuid().ToString('N')
    $hostName = 'localhost'
    if ($ip.Equals([Net.IPAddress]::Any)) { $hostName = [Net.Dns]::GetHostName() } elseif (-not $ip.Equals([Net.IPAddress]::Loopback)) { $hostName = $ip.ToString() }
    $mon.Url = "http://${hostName}:$tryPort/?t=$($mon.Token)"
    $mon.Lib = $null
    if ($MermaidJs -and (Test-Path -LiteralPath $MermaidJs -PathType Leaf)) { $mon.Lib = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $MermaidJs).ProviderPath) }
    else { Write-Warning "$MermaidJs not found - the monitor works without the diagram." }
    $mon.Page = Get-MonPage
    return $listener
}
# Live queries (each server on its own schedule) and finished on-demand queries
function Step-MonQueries {
    $did = $false
    foreach ($t in $mon.Targets.Values) {
        if ($t.PS) {
            if ($t.Handle.IsCompleted) {
                $r = Complete-MonJob $t.PS $t.Handle
                $t.PS = $null
                $t.Took = [math]::Round(((Get-Date) - $t.Started).TotalSeconds, 1)
                try {
                    $null = Add-LiveResult $t $r
                    $null = Update-MonModel $t.Name
                } catch {
                    # a bug or unexpected data must not stop the monitor; it is reported once per message
                    $m = "Monitor could not process the answer of $($t.Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
                    if ($m -ne $mon.LastFault) { $mon.LastFault = $m; Add-MonEvent 'error' $m }
                }
                $did = $true
            }
        } elseif (-not $mon.Paused -and (Get-Date) -ge $t.Next) { $null = Start-LiveJob $t; $did = $true }
    }
    for ($i = $mon.Deferred.Count - 1; $i -ge 0; $i--) {
        $d = $mon.Deferred[$i]
        if ($d.Handle.IsCompleted) {
            $mon.Deferred.RemoveAt($i); $did = $true
            try { $null = Complete-MonQuery $d }
            catch {
                # an on-demand answer that cannot be processed must not stop the monitor either
                $m = "Monitor could not process the $($d.Kind) answer: $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
                Add-MonEvent 'error' $m
                if ($d.Kind -eq 'repair') { Write-RepairLog "  FAILED: $m"; $mon.Repair = $null }
                if ($d.C) { try { Send-MonJson $d.C ([ordered]@{ error = $m }) } catch { } } else { Set-ConMsg $m }
            }
        }
    }
    return $did
}
# Web requests: read without blocking, answer, close
function Step-MonWeb($Listener, $Clients) {
    $did = $false
    while ($Listener.Pending()) {
        $c = $Listener.AcceptTcpClient()
        $c.SendTimeout = 15000
        $Clients.Add(@{ C = $c; M = (New-Object IO.MemoryStream); T = Get-Date })
        $did = $true
    }
    for ($i = $Clients.Count - 1; $i -ge 0; $i--) {
        $cl = $Clients[$i]
        $req = $null
        try { $req = Receive-MonRequest $cl } catch { $Clients.RemoveAt($i); try { $cl.C.Close() } catch { }; continue }
        if ($req) {
            $Clients.RemoveAt($i)
            try { $null = Invoke-MonRequest $cl.C $req } catch { Write-Warning "HTTP $($req.Path): $($_.Exception.Message)"; Send-MonResponse $cl.C 500 'text/plain' $_.Exception.Message }
            $did = $true
        } elseif (((Get-Date) - $cl.T).TotalSeconds -gt 15) { $Clients.RemoveAt($i); try { $cl.C.Close() } catch { } }
    }
    return $did
}

# -Monitor (web page) or -Console (console view; line mode where the window cannot draw it)
function Start-ReplMonitor {
    New-MonModel
    if ($mon.Targets.Count -eq 0) { throw 'Nothing to monitor: no server was reached.' }
    $mon.Ui = 'web'
    if ($Console) {
        $mon.Ui = 'lines'
        if (Test-ConUi) { $mon.Ui = 'console' }
        else { Write-Warning 'This window cannot draw the console monitor (PowerShell ISE, a remote session, redirected output or a window smaller than 70x16) - changes are printed line by line instead.' }
    }
    $listener = $null
    if ($mon.Ui -eq 'web') { $listener = Start-MonWeb }
    $mon.Pool = [runspacefactory]::CreateRunspacePool(1, [Math]::Max(3, [Math]::Min(16, $mon.Targets.Count + 2)))
    $mon.Pool.Open()
    Write-Host ''
    if ($listener) { Write-Host "Replication monitor: $($mon.Url)" -ForegroundColor Green }
    if ($repairMode -eq 'all') { Write-Warning 'Repairs are switched on in full (-AllowAllRepair): also skipping transactions, reinitializing, sp_repldone - each one after typing its confirmation. Log: repairs.log' }
    elseif ($repairMode -eq 'safe') { Write-Host 'Safe repairs are switched on (-AllowRepair): starting agent and clean up jobs, snapshots - after a confirmation. Log: repairs.log' -ForegroundColor Yellow }
    $stopHow = 'Ctrl+C'
    if ($listener) { $stopHow = 'Ctrl+C or the Stop button' } elseif ($mon.Ui -eq 'console') { $stopHow = 'q or Ctrl+C' }
    Write-Host ("Servers: {0} · subscriptions: {1} · Log Readers: {2} · refresh every {3} s (pending commands every {4}. refresh) · stop with {5}" -f `
        $mon.Targets.Count, $mon.Subs.Count, $mon.Lrs.Count, $RefreshSeconds, $PendingEvery, $stopHow) -ForegroundColor DarkGray
    if ($listener -and $ListenAddress -ne '127.0.0.1' -and $ListenAddress -ne 'localhost') { Write-Warning 'The monitor is reachable from other computers (-ListenAddress). Anyone with the address above (it contains the key) can see it.' }
    Add-MonEvent 'info' "Monitor started ($authText)"
    if ($listener -and -not $NoOpen) { try { Start-Process $mon.Url } catch { Write-Warning "Cannot open the browser: $($_.Exception.Message)" } }
    if ($mon.Ui -eq 'console') { Initialize-ConUi }
    $clients = New-MonList
    try {
        while (-not $mon.Stop) {
            $did = Step-MonQueries
            if ($listener -and (Step-MonWeb $listener $clients)) { $did = $true }
            if ($mon.Ui -eq 'console' -and (Step-ConUi)) { $did = $true }
            if (-not $did) { Start-Sleep -Milliseconds 40 }
        }
    } finally {
        if ($mon.Ui -eq 'console') { Close-ConUi }
        if ($listener) { try { $listener.Stop() } catch { } }
        foreach ($cl in $clients) { try { $cl.C.Close() } catch { } }
        foreach ($d in $mon.Deferred) { if ($d.C) { try { $d.C.Close() } catch { } } }
        foreach ($t in $mon.Targets.Values) { if ($t.PS) { try { [void]$t.PS.BeginStop($null, $null) } catch { } } }
        try { $mon.Pool.Close(); $mon.Pool.Dispose() } catch { }
        if ($mon.Ui -eq 'console') { $mon.Ui = 'lines'; Write-MonLine -Force }
        Write-Host 'Replication monitor stopped.' -ForegroundColor Cyan
    }
}

function Get-MonPage {
    $sev = @{ error = 0; warn = 1; info = 2 }
    $static = [ordered]@{
        version = $scriptVersion; auth = $authText; started = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture); interval = $RefreshSeconds
        pendingWarn = $PendingWarn; pendingEvery = $PendingEvery; tracer = [bool]$AllowTracerTokens; repair = $repairMode; masked = (-not $NoMask); lib = ($null -ne $mon.Lib); hints = $monHints
        graph = [ordered]@{
            direction = $Direction
            servers = @($gServers.Values | ForEach-Object { [ordered]@{ name = $_.name; title = $_.mmdTitle; css = $_.css } })
            nodes = @($gNodes.Values | ForEach-Object { [ordered]@{ id = $_.id; srv = $_.srv; db = $_.db; kind = $_.kind; mmd = $_.mmd; s = $_.s } })
            links = @($gLinks | ForEach-Object { [ordered]@{ kind = $_.kind; a = $_.a; b = $_.b; mmd = $_.mmdLive; css = $_.css; keys = @($_.keys) } })
        }
        subs = @($mon.Subs | ForEach-Object {
            $e = $_.Edge
            $srv = @(@($e.PubServer, $e.SubServer, $e.Distributor, $e.PubInstance, $e.SubInstance, $e.DistributorInstance) + @(Get-Instances $e.PubServer) + $_.SubInsts |
                     Where-Object { $_ } | Select-Object -Unique)
            [ordered]@{ k = $_.Key; pub = $e.Publication; type = $e.PubType; subType = $e.SubType; publisher = $e.PubServer; pubDb = $e.PubDb
                        subscriber = $e.SubServer; subDb = $e.SubDb; dist = $e.Distributor; distInst = $_.DistInst; distDb = $e.DistributionDb
                        lr = $_.LrKey; notes = $_.Notes; tables = $e.Tables; label = $_.Label; srv = $srv
                        filters = @(Get-PubFilters $e.PubServer $e.PubDb $e.Publication | ForEach-Object { [ordered]@{ a = $_.Article; rows = $_.Rows; cols = $_.Excluded } })
                        s = "$($e.PubServer) $($e.PubInstance) $($e.PubDb) $($e.Publication) $($e.PubType) $($e.SubServer) $($e.SubInstance) $($e.SubDb) $($e.SubType) $($e.Distributor) $($_.Notes) $($e.ArticleNames)".ToLowerInvariant() }
        })
        lrs = @($mon.Lrs | ForEach-Object {
            [ordered]@{ k = $_.Key; publisher = $_.Publisher; pubDb = $_.PubDb; dist = $_.DistInst; distInst = $_.DistInst; distDb = $_.DistDb; ag = $_.Ag; label = $_.Label
                        srv = @(@($_.Publisher, $_.DistInst) + $_.PubInsts | Where-Object { $_ } | Select-Object -Unique)
                        s = "$($_.Publisher) $($_.PubDb) $($_.DistInst) $($_.Ag) log reader".ToLowerInvariant() }
        })
        findings = @($findings | Sort-Object { $sev[$_.Severity] }, Category, Server | ForEach-Object {
            [ordered]@{ id = $findings.IndexOf($_); sev = $_.Severity; cat = $_.Category; srv = $_.Server; obj = $_.Object; txt = $_.Finding; fix = $_.Recommendation
                        rep = (ConvertTo-RepairJson "$($_.Server) $($_.Object)" (Get-FindingRepairs $_)) } })
        servers = @(@($mon.Targets.Keys) + @($gServers.Keys) | Where-Object { $_ } | Select-Object -Unique | Sort-Object)
    }
    return $monitorHtml.Replace('{{TOKEN}}', $mon.Token).Replace('{{STATIC}}', (ConvertTo-FastJson $static -Html))
}

$monitorHtml = @'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Replication Monitor</title>
<style>
:root{--bg:#f5f6f8;--fg:#1c1e21;--mut:#6b7280;--line:#e3e6ea;--card:#fff;--hov:#f2f5f9;--ok:#2e7d32;--warn:#d97706;--err:#c62828;--unk:#8a8f98;--acc:#1e5aa8;--blk:#7c3aed;--code:#f4f4f5;--bar:#5b8def}
@media (prefers-color-scheme:dark){:root{--bg:#121417;--fg:#e5e7eb;--mut:#9aa1ab;--line:#2a2e35;--card:#1a1d21;--hov:#22262c;--acc:#8ab4f8;--code:#23272e;--bar:#6f9cf2}}
*{box-sizing:border-box}
body{margin:0;font:13px/1.45 "Segoe UI",system-ui,sans-serif;background:var(--bg);color:var(--fg)}
header{position:sticky;top:0;z-index:5;background:var(--card);border-bottom:1px solid var(--line)}
.top{display:flex;align-items:center;gap:12px;padding:8px 16px;flex-wrap:wrap}
.brand{font-size:16px;font-weight:600;white-space:nowrap}
.brand small{font-weight:400;color:var(--mut);margin-left:6px;font-size:12px}
.chips{display:flex;gap:6px;flex-wrap:wrap;flex:1}
.chip{border:1px solid var(--line);border-radius:14px;padding:2px 10px;background:var(--card);cursor:pointer;white-space:nowrap}
.chip:hover{background:var(--hov)}
.chip b{font-weight:600;margin-left:3px}
.c-ok{color:var(--ok)}.c-warn{color:var(--warn);font-weight:600}.c-error{color:var(--err);font-weight:600}.c-blk{color:var(--blk);font-weight:600}.mut{color:var(--mut)}
.ctl{display:flex;align-items:center;gap:6px;flex-wrap:wrap}
button,select,input{font:inherit;color:inherit;background:var(--card);border:1px solid var(--line);border-radius:6px;padding:4px 9px}
button{cursor:pointer}button:hover{background:var(--hov)}button:disabled{opacity:.5;cursor:default}
button.danger{color:var(--err)}
.conn{display:inline-flex;align-items:center;gap:6px;color:var(--mut);white-space:nowrap}
.conn i{width:9px;height:9px;border-radius:50%;background:var(--ok);display:inline-block}
.conn.live i{animation:pulse 2s infinite}.conn.paused i{background:var(--warn)}.conn.down i{background:var(--err)}
@keyframes pulse{50%{opacity:.3}}
.bar{display:flex;gap:8px;align-items:center;padding:0 16px 8px;flex-wrap:wrap}
.bar input[type=search]{flex:1 1 300px;max-width:520px}
.quick{display:flex;gap:4px;flex-wrap:wrap}
.quick button{border-radius:14px;padding:2px 10px}
.quick button.on{background:var(--acc);color:#fff;border-color:var(--acc)}
.quick button span{opacity:.75;margin-left:4px}
nav.tabs{display:flex;gap:2px;padding:0 10px;overflow-x:auto}
nav.tabs a{padding:7px 12px;border-bottom:2px solid transparent;color:var(--mut);text-decoration:none;white-space:nowrap;cursor:pointer}
nav.tabs a.on{color:var(--fg);border-bottom-color:var(--acc);font-weight:600}
nav.tabs a .n{background:var(--line);color:var(--fg);border-radius:9px;padding:0 6px;margin-left:5px;font-size:11px;font-weight:400}
nav.tabs a .n.error{background:var(--err);color:#fff}nav.tabs a .n.warn{background:var(--warn);color:#fff}
#banner{display:none;background:var(--err);color:#fff;padding:6px 16px}
main{padding:12px 16px 40px}
section.tab{display:none}section.tab.on{display:block}
.card{background:var(--card);border:1px solid var(--line);border-radius:8px}
.tw{overflow:auto;max-height:calc(100vh - 200px)}
table{border-collapse:collapse;width:100%}
th,td{padding:4px 7px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}
th{position:sticky;top:0;background:var(--card);font-weight:600;white-space:nowrap;cursor:pointer;user-select:none;z-index:1}
th.sorted::after{content:" \25BE"}th.sorted.asc::after{content:" \25B4"}
tbody tr.click{cursor:pointer}tbody tr:hover{background:var(--hov)}
tr.lv-error>td:first-child{box-shadow:inset 3px 0 var(--err)}tr.lv-warn>td:first-child{box-shadow:inset 3px 0 var(--warn)}
td.num{text-align:right;white-space:nowrap;font-variant-numeric:tabular-nums}
td.nw{white-space:nowrap}
td.msg{max-width:380px}
.clip{display:block;max-width:380px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.sql{font:11.5px Consolas,monospace;color:var(--mut)}
td.empty{color:var(--mut);padding:14px;text-align:center}
.dot{display:inline-block;width:9px;height:9px;border-radius:50%;margin-right:5px;vertical-align:middle;background:var(--unk)}
.dot.ok{background:var(--ok)}.dot.warn{background:var(--warn)}.dot.error{background:var(--err)}
.pill{display:inline-block;padding:0 7px;border-radius:9px;font-size:11.5px;background:var(--line);white-space:nowrap}
.pill.run{background:#d9f2df;color:#14532d}.pill.idle{background:#dcebfb;color:#0c3d6e}.pill.retry{background:#fdecc8;color:#7a3e05}
.pill.fail{background:#fbd5d5;color:#7f1d1d}.pill.stop{background:#e5e7eb;color:#374151}
svg.sp{width:64px;height:16px;vertical-align:middle;margin-left:6px}
.ov{display:grid;grid-template-columns:minmax(0,1fr) 360px;gap:12px}
@media (max-width:1100px){.ov{grid-template-columns:1fr}}
.dtool{display:flex;gap:6px;align-items:center;padding:6px 8px;border-bottom:1px solid var(--line);flex-wrap:wrap}
#dwrap{height:calc(100vh - 250px);min-height:320px;overflow:auto;background:#fff;border-radius:0 0 8px 8px}
#diagram{transform-origin:0 0;padding:12px;display:inline-block;color:#1c1e21}
#diagram g.node,#diagram g.cluster{cursor:pointer}
#diagram path.hit{stroke:transparent;stroke-width:14px;fill:none;cursor:pointer;pointer-events:stroke}
#diagram path.flow{stroke-dasharray:10 6;animation:flow var(--spd,1.2s) linear infinite}
#diagram path.blocked{stroke-dasharray:3 4;animation:none}
@keyframes flow{to{stroke-dashoffset:-16}}
.legend{padding:6px 10px;color:var(--mut);font-size:12px;border-top:1px solid var(--line)}
.sw{display:inline-block;width:20px;border-top:3px solid;vertical-align:middle;margin:0 3px 0 8px}
.side h3{margin:0;padding:8px 10px;font-size:13px;border-bottom:1px solid var(--line)}
.att{padding:6px 10px;border-bottom:1px solid var(--line);cursor:pointer}
.att:hover{background:var(--hov)}
.att .p{color:var(--mut);font-size:12px}
.att.lv-error{box-shadow:inset 3px 0 var(--err)}.att.lv-warn{box-shadow:inset 3px 0 var(--warn)}
.srvs td{font-size:12px}
.grid2{display:grid;grid-template-columns:repeat(auto-fill,minmax(420px,1fr));gap:12px}
.box{padding:8px 10px}
.box h3{margin:0 0 6px;font-size:13px}
h2{font-size:14px;margin:16px 0 8px}
h2:first-child{margin-top:0}
.br{display:grid;grid-template-columns:minmax(110px,40%) 1fr 92px;gap:8px;align-items:center;margin:2px 0;font-size:12px}
.br .bl{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.br .bb{background:var(--line);height:9px;border-radius:5px;overflow:hidden}
.br .bb i{display:block;height:100%;background:var(--bar)}
.br .bv{text-align:right;font-variant-numeric:tabular-nums}
#drawer{position:fixed;top:0;right:0;bottom:0;width:min(780px,97vw);background:var(--card);border-left:1px solid var(--line);box-shadow:-8px 0 24px rgba(0,0,0,.14);z-index:10;overflow:auto;transform:translateX(102%);transition:transform .18s}
#drawer.on{transform:none}
.dh{position:sticky;top:0;background:var(--card);border-bottom:1px solid var(--line);padding:10px 14px;display:flex;gap:10px;align-items:flex-start;z-index:2}
.dh h2{margin:0;font-size:15px;flex:1}
.db{padding:10px 14px 30px}
.facts{display:grid;grid-template-columns:150px 1fr;gap:3px 12px}
.facts>div:nth-child(odd){color:var(--mut)}
.db h3{font-size:13px;margin:16px 0 6px;border-bottom:1px solid var(--line);padding-bottom:3px}
svg.chart{width:100%;height:auto;display:block}
svg.chart text{fill:var(--mut);font-size:10px}
pre{background:var(--code);padding:8px;border-radius:6px;white-space:pre-wrap;word-break:break-word;max-height:260px;overflow:auto;font:12px Consolas,monospace;margin:4px 0}
.err{border:1px solid var(--line);border-radius:6px;padding:6px 8px;margin:6px 0}
.m{white-space:pre-wrap;overflow-wrap:anywhere}
.rep{border-left:3px solid #9e9e9e;padding:4px 8px;margin:6px 0}.rep button{margin-top:4px}.rsql{max-height:320px}
details summary{cursor:pointer;color:var(--acc)}
#toast{position:fixed;bottom:18px;left:50%;transform:translateX(-50%);background:#333;color:#fff;padding:8px 14px;border-radius:6px;display:none;z-index:20;max-width:80vw}
.ev{display:grid;grid-template-columns:150px 18px 1fr;gap:6px;padding:4px 8px;border-bottom:1px solid var(--line)}
.ev.click{cursor:pointer}.ev:hover{background:var(--hov)}
.hint{color:var(--mut);font-size:12px;margin:4px 0 8px}
</style>
</head>
<body>
<header>
  <div class="top">
    <div class="brand">Replication Monitor <small id="ver"></small></div>
    <div class="chips" id="chips"></div>
    <div class="ctl">
      <span class="conn" id="conn"><i></i><span id="connText">connecting...</span></span>
      <label class="mut">every <select id="intv"><option>5</option><option>10</option><option>15</option><option>30</option><option>60</option><option>120</option></select> s</label>
      <button id="bPause">Pause</button>
      <button id="bNow" title="Query all servers now, including pending commands">Refresh now</button>
      <button id="bStop" class="danger" title="Stop the monitor (the PowerShell script ends)">Stop</button>
    </div>
  </div>
  <div class="bar">
    <input id="q" type="search" placeholder="Filter: server, database, publication, table, error, wait type...   ( / )" autocomplete="off">
    <div class="quick" id="quick"></div>
    <select id="srv"><option value="">All servers</option></select>
  </div>
  <nav class="tabs" id="tabs"></nav>
</header>
<div id="banner"></div>
<main>
  <section class="tab" id="tab-overview">
    <div class="ov">
      <div class="card">
        <div class="dtool">
          <button data-z="1.25">Zoom +</button><button data-z="0.8">Zoom -</button><button data-z="0">100%</button><button data-z="-1">Fit</button>
          <button id="bDir">Vertical</button>
          <span class="mut" id="dinfo"></span>
        </div>
        <div id="dwrap"><div id="diagram">Loading the diagram...</div></div>
        <div class="legend">Line color = worst health of the subscriptions on it:<span class="sw" style="border-color:#2e7d32"></span>OK<span class="sw" style="border-color:#d97706"></span>warning<span class="sw" style="border-color:#c62828"></span>error<span class="sw" style="border-color:#7c3aed;border-top-style:dotted"></span>blocked<span class="sw" style="border-color:#8a8f98"></span>no data ·
          moving dashes = commands are being delivered (faster and thicker = more) · database border = Log Reader health · click a line for details, a database or a server to filter</div>
      </div>
      <div>
        <div class="card side"><h3>Needs attention</h3><div id="attention"></div></div>
        <div class="card side" style="margin-top:12px"><h3>Servers queried</h3><div class="tw" style="max-height:340px"><table class="srvs" id="tSrv"></table></div></div>
      </div>
    </div>
  </section>
  <section class="tab" id="tab-subs"><div class="card tw"><table id="tSubs"></table></div></section>
  <section class="tab" id="tab-lrs"><div class="card tw"><table id="tLrs"></table></div></section>
  <section class="tab" id="tab-waits">
    <h2>Blocking</h2>
    <div class="hint">Replication agent sessions that wait for a lock, with the head of the blocking chain (often a sleeping session with an open transaction), and sessions an agent blocks.</div>
    <div class="card tw" style="max-height:40vh"><table id="tBlk"></table></div>
    <h2>Agent sessions</h2>
    <div class="card tw" style="max-height:50vh"><table id="tSes"></table></div>
    <div class="grid2" style="margin-top:12px">
      <div class="card box"><h3>Waits of agent sessions (since the monitor started; last interval in brackets)</h3><div id="agentWaits"></div></div>
      <div class="card box"><h3>Server waits in the last interval (ms of waiting per second)</h3><div id="srvWaits"></div></div>
    </div>
  </section>
  <section class="tab" id="tab-ag"><div class="hint">Replicas of the availability groups seen by the monitor. A Log Reader reads only changes hardened on every synchronous secondary (unless trace flag 1448 is on) - a lagging or disconnected synchronous replica holds replication back.</div><div class="card tw"><table id="tAg"></table></div></section>
  <section class="tab" id="tab-errors"><div class="hint">Errors written by the replication agents to the distribution database (MSrepl_errors), newest first. "Command" shows the replicated command that failed (sp_browsereplcmds).</div><div class="card tw"><table id="tErr"></table></div></section>
  <section class="tab" id="tab-events"><div class="hint">What changed while the monitor was running: health of subscriptions and Log Readers, blocking, new errors, servers lost and back.</div><div class="card" id="events"></div></section>
  <section class="tab" id="tab-findings"><div class="hint">Findings of the topology scan made when the monitor started (configuration, versions, security, leftovers). They do not refresh.</div><div class="card tw"><table id="tFind"></table></div></section>
</main>
<aside id="drawer"><div class="dh"><h2 id="dTitle"></h2><button id="dClose">Close (Esc)</button></div><div class="db"><div id="dLive"></div><div id="dDetail"></div></div></aside>
<div id="toast"></div>
<script type="application/json" id="static">{{STATIC}}</script>
<script>
'use strict';
const T = '{{TOKEN}}';
const S = JSON.parse(document.getElementById('static').textContent);
const SUB = {}, LR = {}, GN = {};
S.subs.forEach(s => SUB[s.k] = s); S.lrs.forEach(l => LR[l.k] = l); S.graph.nodes.forEach(n => GN[n.id] = n);
const RANK = { '': 0, ok: 1, unknown: 2, warn: 3, error: 4 };
const COLOR = { ok: '#2e7d32', warn: '#d97706', error: '#c62828', unknown: '#8a8f98', '': '#8a8f98' };
const ST_COLOR = { 1: '#64b5f6', 2: '#9e9e9e', 3: '#2e7d32', 4: '#90caf9', 5: '#d97706', 6: '#c62828' };
const ST_NAME = { 1: 'started', 2: 'stopped', 3: 'running', 4: 'idle', 5: 'retrying', 6: 'failed' };
const LAT_W = 30, LAT_E = 300;
const TABS = [['overview', 'Overview'], ['subs', 'Subscriptions'], ['lrs', 'Log Readers'], ['waits', 'Sessions & waits'], ['ag', 'Availability groups'],
              ['errors', 'Errors'], ['events', 'Events'], ['findings', 'Findings']];
const QUICK = [['all', 'All'], ['problems', 'Problems'], ['errors', 'Errors'], ['blocked', 'Blocked'], ['pending', 'Pending'], ['notrunning', 'Not running'], ['latency', 'Latency >= ' + LAT_W + ' s']];
let L = null, LS = {}, LL = {}, drawer = null, stopped = false, pollTimer = null;
const ui = Object.assign({ tab: 'overview', q: '', quick: 'all', srv: '', sort: {} }, (() => { try { return JSON.parse(localStorage.getItem('replmon') || '{}'); } catch (e) { return {}; } })());
const save = () => { try { localStorage.setItem('replmon', JSON.stringify(ui)); } catch (e) { } };
const $ = id => document.getElementById(id);
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmtN = (n, d) => n == null || n === '' ? '' : Number(n).toLocaleString(undefined, { maximumFractionDigits: d || 0 });
function fmtAge(s) {
  if (s == null) return '';
  s = Math.round(s);
  if (s < 60) return s + ' s';
  if (s < 3600) return Math.floor(s / 60) + ' min';
  if (s < 86400) return Math.floor(s / 3600) + ' h ' + Math.floor(s % 3600 / 60) + ' min';
  return Math.floor(s / 86400) + ' d ' + Math.floor(s % 86400 / 3600) + ' h';
}
const lvOf = x => x ? x.h : 'unknown';
const api = (path, opt) => { opt = opt || {}; opt.headers = { 'X-Token': T }; opt.cache = 'no-store'; return fetch(path, opt); };
function toast(t) { const el = $('toast'); el.textContent = t; el.style.display = 'block'; clearTimeout(toast.t); toast.t = setTimeout(() => el.style.display = 'none', 4500); }
function stCls(st) { return { Running: 'run', Idle: 'idle', Started: 'run', Retrying: 'retry', Failed: 'fail', 'Not running': 'fail', Stopped: 'stop' }[st] || ''; }
const pill = st => st ? `<span class="pill ${stCls(st)}">${esc(st)}</span>` : '';
function numC(v, w, e, unit, d) {
  if (v == null) return '';
  const c = v >= e ? 'c-error' : v >= w ? 'c-warn' : '';
  return `<span class="${c}">${fmtN(v, d)}${unit || ''}</span>`;
}
function ageC(v, w, e) { return v == null ? '' : `<span class="${v >= e ? 'c-error' : v >= w ? 'c-warn' : ''}">${fmtAge(v)}</span>`; }
function spark(a, color) {
  if (!a || a.length < 2) return '';
  const v = a.map(x => x == null ? null : +x), nums = v.filter(x => x != null);
  if (nums.length < 2) return '';
  const max = Math.max(...nums), min = Math.min(0, ...nums), r = (max - min) || 1, n = v.length;
  let d = '', pen = false;
  v.forEach((x, i) => { if (x == null) { pen = false; return; } d += (pen ? 'L' : 'M') + (i * 62 / (n - 1) + 1).toFixed(1) + ' ' + (15 - (x - min) / r * 13).toFixed(1); pen = true; });
  return `<svg class="sp" viewBox="0 0 64 16"><path d="${d}" fill="none" stroke="${color}" stroke-width="1.4"/></svg>`;
}
function sessCell(x) {
  if (!x) return '';
  if (x.blk) return `<span class="c-blk" title="${esc(x.blk)}">${esc(x.wt || 'blocked')}</span>`;
  if (x.wt) return `<span title="current wait of the agent session">${esc(x.wt)}</span>`;
  return x.ses && x.ses.length ? `<span class="mut">${x.ses.length} session${x.ses.length > 1 ? 's' : ''}</span>` : '';
}
function probCell(x) {
  if (!x) return '<span class="mut">no data yet</span>';
  const p = x.p ? `<div class="${x.h === 'error' ? 'c-error' : x.h === 'warn' ? 'c-warn' : ''}">${esc(x.p)}</div>` : '';
  return p + `<span class="mut clip" title="${esc(x.msg)}">${esc(x.msg)}</span>`;
}

// ---------- filter ----------
function liveText(x) { return x ? [x.p, x.msg, x.wt, x.st, x.blk, x.h, x.job, x.ag || ''].join(' ').toLowerCase() : ''; }
function quickPass(x, f) {
  if (f === 'all') return true;
  if (!x) return false;
  switch (f) {
    case 'problems': return x.h === 'warn' || x.h === 'error';
    case 'errors': return x.h === 'error';
    case 'blocked': return !!x.blk || /blocked/.test(x.wt || '');
    case 'pending': return x.pd > 0;
    case 'notrunning': return ['Not running', 'Stopped', 'Failed', 'Retrying'].includes(x.st);
    case 'latency': return x.lat >= LAT_W;
  }
  return true;
}
function textPass(txt) {
  if (!ui.q) return true;
  return ui.q.toLowerCase().split(/\s+/).filter(w => w).every(w => txt.includes(w));
}
const passSrv = s => !ui.srv || s.srv.includes(ui.srv);
const passItem = (s, x, quick) => passSrv(s) && quickPass(x, quick === undefined ? ui.quick : quick) && textPass(s.s + ' ' + liveText(x));

// ---------- tables ----------
const tables = {};
function renderTable(id, cols, rows, def, rowAttr) {
  const st = ui.sort[id] || def, col = cols.find(c => c.k === st.k) || cols[0];
  rows.sort((a, b) => {
    let va = col.v(a), vb = col.v(b);
    const na = va == null || va === '', nb = vb == null || vb === '';
    if (na || nb) return na === nb ? 0 : na ? 1 : -1;
    const r = typeof va === 'number' && typeof vb === 'number' ? va - vb : String(va).localeCompare(String(vb), undefined, { numeric: true });
    return st.asc ? r : -r;
  });
  const th = cols.map(c => `<th data-k="${c.k}" class="${c.k === col.k ? 'sorted' + (st.asc ? ' asc' : '') : ''}" title="${esc(c.tip || '')}">${esc(c.t)}</th>`).join('');
  const tb = rows.map(r => `<tr ${rowAttr ? rowAttr(r) : ''}>${cols.map(c => `<td class="${c.cls || ''}">${c.f(r)}</td>`).join('')}</tr>`).join('');
  const el = $(id);
  el.innerHTML = `<thead><tr>${th}</tr></thead><tbody>${tb || `<tr><td colspan="${cols.length}" class="empty">${L ? 'Nothing matches the filter.' : 'Waiting for the first data...'}</td></tr>`}</tbody>`;
  if (!tables[id]) {
    tables[id] = true;
    el.addEventListener('click', ev => {
      const h = ev.target.closest('th');
      if (h) {
        const k = h.dataset.k, cur = ui.sort[id] || def;
        ui.sort[id] = { k: k, asc: cur.k === k ? !cur.asc : false }; save(); renderTab(); return;
      }
      if (ev.target.closest('button,a,summary')) return;
      const tr = ev.target.closest('tr[data-k]');
      if (tr) openItem(tr.dataset.k);
    });
  }
}
const subRows = () => S.subs.map(s => ({ s: s, x: LS[s.k] })).filter(r => passItem(r.s, r.x));
const lrRows = () => S.lrs.map(s => ({ s: s, x: LL[s.k] })).filter(r => passItem(r.s, r.x));
const rowAttr = r => `class="click lv-${lvOf(r.x)}" data-k="${esc(r.s.k)}"`;

function renderSubs() {
  renderTable('tSubs', [
    { k: 'h', t: 'Health', cls: 'nw', v: r => RANK[lvOf(r.x)] * 1e7 + (r.x && r.x.lat || 0), f: r => `<span class="dot ${lvOf(r.x)}"></span>${esc(lvOf(r.x))}` },
    { k: 'st', t: 'Status', v: r => r.x && r.x.st, f: r => pill(r.x && r.x.st) + (r.x && r.x.job && r.x.job !== 'running' ? ` <span class="mut">job ${esc(r.x.job)}</span>` : '') },
    { k: 'pub', t: 'Publication', v: r => r.s.pub, f: r => `<b>${esc(r.s.pub)}</b> <span class="mut">${esc(r.s.type)}</span>` },
    { k: 'from', t: 'Publisher / database', v: r => r.s.publisher + '/' + r.s.pubDb, f: r => esc(r.s.publisher + ' / ' + r.s.pubDb) },
    { k: 'to', t: 'Subscriber / database', v: r => r.s.subscriber + '/' + r.s.subDb, f: r => esc(r.s.subscriber + ' / ' + r.s.subDb) + ` <span class="mut">${esc(r.s.subType)}</span>` },
    { k: 'lat', t: 'Latency', tip: 'Seconds from the publisher commit to the subscriber (Replication Monitor)', cls: 'num', v: r => r.x && r.x.lat, f: r => r.x ? numC(r.x.lat, LAT_W, LAT_E, ' s', 1) + spark(r.x.lh, '#1e88e5') : '' },
    { k: 'pd', t: 'Pending', tip: 'Commands in the distribution database not delivered yet (counted every ' + S.pendingEvery + '. refresh)', cls: 'num', v: r => r.x && r.x.pd,
      f: r => r.x ? `<span title="${r.x.eta != null ? 'about ' + esc(fmtAge(r.x.eta)) + ' of agent work at its average speed (as Replication Monitor estimates it)' : ''}">${numC(r.x.pd, S.pendingWarn, S.pendingWarn * 10)}</span>` + spark(r.x.ph, '#8e24aa') : '' },
    { k: 'old', t: 'Oldest pending', tip: 'Age of the oldest undelivered transaction - the real delay when an agent is stuck', cls: 'num', v: r => r.x && r.x.old, f: r => r.x ? ageC(r.x.old, LAT_W * 2, LAT_E * 2) : '' },
    { k: 'rt', t: 'cmd/s', tip: 'Commands per second delivered since the previous agent history entry', cls: 'num', v: r => r.x && r.x.rt, f: r => r.x ? fmtN(r.x.rt, 1) + spark(r.x.rh, '#2e7d32') : '' },
    { k: 'age', t: 'Last activity', tip: 'Time since the last agent history entry', cls: 'num', v: r => r.x && r.x.age, f: r => r.x ? (['Running', 'Idle', 'Started'].includes(r.x.st) ? ageC(r.x.age, 600, 1800) : esc(fmtAge(r.x.age))) : '' },
    { k: 'wt', t: 'Session / wait', v: r => r.x && (r.x.blk ? 'zz' + r.x.blk : r.x.wt), f: r => sessCell(r.x) },
    { k: 'p', t: 'Problems / last message', cls: 'msg', v: r => r.x && (r.x.p || r.x.msg), f: r => probCell(r.x) },
    { k: 'notes', t: 'Notes (scan)', cls: 'msg', tip: 'Found by the topology scan at start, not refreshed', v: r => r.s.notes, f: r => `<span class="mut clip" title="${esc(r.s.notes)}">${esc(r.s.notes)}</span>` },
    { k: 'dist', t: 'Distributor', v: r => r.s.dist, f: r => esc(r.s.dist + ' / ' + r.s.distDb) }
  ], subRows(), { k: 'h', asc: false }, rowAttr);
}
function renderLrs() {
  renderTable('tLrs', [
    { k: 'h', t: 'Health', cls: 'nw', v: r => RANK[lvOf(r.x)] * 1e7 + (r.x && r.x.lat || 0), f: r => `<span class="dot ${lvOf(r.x)}"></span>${esc(lvOf(r.x))}` },
    { k: 'st', t: 'Status', v: r => r.x && r.x.st, f: r => pill(r.x && r.x.st) + (r.x && r.x.job && r.x.job !== 'running' ? ` <span class="mut">job ${esc(r.x.job)}</span>` : '') },
    { k: 'pub', t: 'Published database', v: r => r.s.publisher + '/' + r.s.pubDb, f: r => `<b>${esc(r.s.publisher + ' / ' + r.s.pubDb)}</b>` },
    { k: 'lat', t: 'Latency', tip: 'Seconds from the commit at the publisher to the distribution database', cls: 'num', v: r => r.x && r.x.lat, f: r => r.x ? numC(r.x.lat, LAT_W, LAT_E, ' s', 1) + spark(r.x.lh, '#1e88e5') : '' },
    { k: 'rt', t: 'cmd/s', tip: 'Commands per second read from the log', cls: 'num', v: r => r.x && r.x.rt, f: r => r.x ? fmtN(r.x.rt, 1) + spark(r.x.rh, '#2e7d32') : '' },
    { k: 'cmds', t: 'Commands (session)', cls: 'num', v: r => r.x && r.x.cmds, f: r => r.x ? fmtN(r.x.cmds) : '' },
    { k: 'age', t: 'Last activity', cls: 'num', v: r => r.x && r.x.age, f: r => r.x ? fmtAge(r.x.age) : '' },
    { k: 'wt', t: 'Session / wait', v: r => r.x && r.x.wt, f: r => sessCell(r.x) },
    { k: 'ag', t: 'Availability group', v: r => r.x && r.x.ag, f: r => esc(r.x ? r.x.ag : r.s.ag) },
    { k: 'p', t: 'Problems / last message', cls: 'msg', v: r => r.x && (r.x.p || r.x.msg), f: r => probCell(r.x) },
    { k: 'dist', t: 'Distributor', v: r => r.s.dist, f: r => esc(r.s.dist + ' / ' + r.s.distDb) }
  ], lrRows(), { k: 'h', asc: false }, rowAttr);
}
function itemOfKey(k) { return SUB[k] || LR[k]; }
function renderWaits() {
  const pass = x => (!ui.srv || x.srv === ui.srv || (x.k && itemOfKey(x.k) && passSrv(itemOfKey(x.k)))) &&
                    textPass([x.lbl, x.srv, x.w, x.hProg, x.hHost, x.hLogin, x.hSql, x.sql, x.db].join(' ').toLowerCase());
  const blk = (L ? L.blocking : []).filter(pass).map(b => ({ s: { k: b.k || '' }, x: null, b: b }));
  renderTable('tBlk', [
    { k: 'ms', t: 'Waiting', cls: 'num', v: r => r.b.ms, f: r => numC((r.b.ms || 0) / 1000, 5, 60, ' s', 1) },
    { k: 'lbl', t: 'Blocked session', v: r => r.b.lbl, f: r => (r.b.agentBlocks ? '<span class="c-blk">blocked by an agent: </span>' : '') + `<b>${esc(r.b.lbl)}</b><div class="mut">${esc(r.b.srv)} · session ${r.b.spid}</div>` },
    { k: 'w', t: 'Wait / resource', v: r => r.b.w, f: r => esc(r.b.w) + `<div class="mut">${esc(r.b.res)}</div>` },
    { k: 'by', t: 'Blocked by (chain)', v: r => r.b.by, f: r => r.b.agentBlocks ? esc(r.b.byLbl || ('session ' + r.b.by)) : `session ${r.b.by}<div class="mut">${esc(r.b.chain)}</div>` },
    { k: 'head', t: 'Head blocker', v: r => r.b.hProg, f: r => r.b.agentBlocks ? '' : `<b>${esc(r.b.byLbl || r.b.hJob || r.b.hProg)}</b><div class="mut">${esc([r.b.hHost, r.b.hLogin, r.b.hDb, r.b.hSt, r.b.hCmd].filter(x => x).join(' · '))}${r.b.hTran ? ' · open transactions: ' + r.b.hTran : ''}</div>` },
    { k: 'sql', t: 'SQL of the head blocker', cls: 'msg', v: r => r.b.hSql, f: r => `<span class="sql">${esc((r.b.hSql || '').slice(0, 400))}</span>` }
  ], blk, { k: 'ms', asc: false }, r => `class="${r.b.k ? 'click' : ''} lv-${r.b.agentBlocks ? 'warn' : 'error'}" data-k="${esc(r.b.k)}"`);
  const ses = (L ? L.sessions : []).filter(pass).map(x => ({ s: { k: x.k }, x: null, e: x }));
  renderTable('tSes', [
    { k: 'srv', t: 'Server', v: r => r.e.srv, f: r => esc(r.e.srv) + `<div class="mut">session ${r.e.spid}</div>` },
    { k: 'lbl', t: 'Agent', v: r => r.e.lbl, f: r => `<b>${esc(r.e.lbl)}</b><div class="mut">${esc(r.e.side)} side · ${esc(r.e.db)}</div>` },
    { k: 'st', t: 'State', v: r => r.e.req || r.e.st, f: r => esc(r.e.req || r.e.st) + (r.e.cmd ? `<div class="mut">${esc(r.e.cmd)}</div>` : '') },
    { k: 'w', t: 'Wait', v: r => r.e.w, f: r => r.e.blk > 0 ? `<span class="c-blk">${esc(r.e.w)} - blocked by ${r.e.blk}</span>` : esc(r.e.w) },
    { k: 'ms', t: 'Wait time', cls: 'num', v: r => r.e.ms, f: r => r.e.ms != null ? fmtN(r.e.ms / 1000, 1) + ' s' : '' },
    { k: 'cpu', t: 'CPU ms', cls: 'num', v: r => r.e.cpu, f: r => fmtN(r.e.cpu) },
    { k: 'rd', t: 'Reads / writes', cls: 'num', v: r => r.e.rd, f: r => fmtN(r.e.rd) + ' / ' + fmtN(r.e.wr) },
    { k: 'tran', t: 'Open tran', cls: 'num', v: r => r.e.tran, f: r => fmtN(r.e.tran) },
    { k: 'last', t: 'Last request', cls: 'nw', v: r => r.e.last, f: r => esc((r.e.last || '').slice(11)) },
    { k: 'sql', t: 'SQL', cls: 'msg', v: r => r.e.sql, f: r => `<span class="sql clip" title="${esc(r.e.sql)}">${esc((r.e.sql || '').slice(0, 300))}</span>` }
  ], ses, { k: 'ms', asc: false }, r => `class="${r.e.k ? 'click' : ''}" data-k="${esc(r.e.k)}"`);
  const aw = (L ? L.agentWaits : []).filter(a => !itemOfKey(a.k) || passItem(itemOfKey(a.k), (SUB[a.k] ? LS : LL)[a.k], 'all'));
  $('agentWaits').innerHTML = aw.length ? aw.map(a => `<div style="margin:8px 0 2px"><b>${esc(a.lbl)}</b></div>` +
    bars(a.top, w => w.w, w => w.ms, (v, w) => fmtWait(v) + (w.last ? ` (${fmtWait(w.last)})` : ''))).join('') :
    '<div class="mut">No data yet (needs SQL Server 2016 or newer and two samples).</div>';
  const sw = (L ? L.waits : []).filter(w => !ui.srv || w.srv === ui.srv);
  $('srvWaits').innerHTML = sw.length ? sw.map(w => `<div style="margin:8px 0 2px"><b>${esc(w.srv)}</b> <span class="mut">${w.sec} s</span></div>` +
    bars(w.top, x => x.w, x => x.ms / Math.max(1, w.sec), v => fmtN(v, 1) + ' ms/s')).join('') : '<div class="mut">No data yet (two samples are needed).</div>';
}
function fmtWait(ms) { return ms >= 60000 ? fmtN(ms / 60000, 1) + ' min' : ms >= 1000 ? fmtN(ms / 1000, 1) + ' s' : fmtN(ms) + ' ms'; }
function bars(items, label, value, fmt) {
  if (!items || !items.length) return '<div class="mut">-</div>';
  const max = Math.max(1e-9, ...items.map(value));
  return items.map(it => `<div class="br"><span class="bl" title="${esc(label(it))}">${esc(label(it))}</span><span class="bb"><i style="width:${(100 * value(it) / max).toFixed(1)}%"></i></span><span class="bv">${fmt(value(it), it)}</span></div>`).join('');
}
function renderAg() {
  const rows = (L ? L.ag : []).filter(a => (!ui.srv || a.replica === ui.srv || S.lrs.some(l => l.ag === a.ag && passSrv(l))) && textPass([a.ag, a.db, a.replica, a.role, a.sync, a.p].join(' ').toLowerCase()))
    .map(a => ({ s: { k: '' }, x: null, a: a }));
  renderTable('tAg', [
    { k: 'h', t: 'Health', cls: 'nw', v: r => RANK[r.a.h], f: r => `<span class="dot ${r.a.h}"></span>${esc(r.a.h)}` },
    { k: 'ag', t: 'Availability group / database', v: r => r.a.ag + r.a.db, f: r => `<b>${esc(r.a.ag)}</b> / ${esc(r.a.db)}` },
    { k: 'replica', t: 'Replica', v: r => r.a.replica, f: r => esc(r.a.replica) + ` <span class="mut">${esc(r.a.role)}</span>` },
    { k: 'mode', t: 'Mode', v: r => r.a.mode, f: r => esc((r.a.mode || '').replace('_COMMIT', '').toLowerCase()) },
    { k: 'sync', t: 'Synchronization', v: r => r.a.sync, f: r => esc(r.a.sync) + (r.a.conn && r.a.conn !== 'CONNECTED' ? ` <span class="c-error">${esc(r.a.conn)}</span>` : '') },
    { k: 'sendKb', t: 'Send queue', cls: 'num', v: r => r.a.sendKb, f: r => r.a.sendKb != null ? fmtN(r.a.sendKb / 1024, 1) + ' MB' : '' },
    { k: 'redoKb', t: 'Redo queue', cls: 'num', v: r => r.a.redoKb, f: r => r.a.redoKb != null ? fmtN(r.a.redoKb / 1024, 1) + ' MB' : '' },
    { k: 'lag', t: 'Lag', tip: 'Last commit on the primary minus last commit on this replica', cls: 'num', v: r => r.a.lag, f: r => numC(r.a.lag, 30, 300, ' s') },
    { k: 'p', t: 'Problems', v: r => r.a.p, f: r => `<span class="${r.a.h === 'error' ? 'c-error' : 'c-warn'}">${esc(r.a.p)}</span>` },
    { k: 'last', t: 'Last commit', cls: 'nw', v: r => r.a.last, f: r => esc(r.a.last) }
  ], rows, { k: 'h', asc: false }, r => `class="lv-${r.a.h}"`);
}
function renderErrors() {
  const rows = collapseErrors((L ? L.errors : []).filter(e => (!e.k || !itemOfKey(e.k) || passSrv(itemOfKey(e.k))) && textPass([e.lbl, e.m, e.code, e.srv].concat(e.more || []).join(' ').toLowerCase())))
    .map(e => ({ s: { k: e.k || '' }, x: null, e: e }));
  renderTable('tErr', [
    { k: 't', t: 'Time', cls: 'nw', v: r => r.e.t, f: r => esc(r.e.t) },
    { k: 'lbl', t: 'Agent', v: r => r.e.lbl, f: r => `<b>${esc(r.e.lbl)}</b>` },
    { k: 'code', t: 'Error', cls: 'num', v: r => r.e.code, f: r => esc(r.e.code) },
    { k: 'm', t: 'Message', cls: 'msg', v: r => r.e.m, f: r => errHtml(r.e, r.e.srv, r.e.db, r.e.agent) },
    { k: 'srv', t: 'Distributor', v: r => r.e.srv, f: r => esc(r.e.srv + ' / ' + r.e.db) }
  ], rows, { k: 't', asc: false }, r => `class="${r.e.k ? 'click' : ''}" data-k="${esc(r.e.k)}"`);
}
const HINTS = S.hints;
// Consecutive identical errors (same agent, code and text) become one entry with a count
function collapseErrors(list) {
  const out = [];
  (list || []).forEach(e => {
    const p = out[out.length - 1], sig = (e.k || e.lbl || '') + '|' + e.code + '|' + e.m + '|' + (e.more || []).join('|');
    if (p && p.sig === sig) { p.n++; p.first = e.t; return; }
    out.push(Object.assign({}, e, { sig: sig, n: 1, first: e.t }));
  });
  return out;
}
function errHtml(e, srv, db, agent) {
  let code = e.code;
  const first = (e.more || []).find(x => /^-?\d+: /.test(x));
  const cause = e.code == 14151 && first ? /^(-?\d+): ([\s\S]*)$/.exec(first) : null;
  if (cause) code = +cause[1];
  const hint = HINTS[code] ? `<div class="mut">${esc(HINTS[code])}</div>` : '';
  const rpt = e.n > 1 ? `<div class="c-warn">repeated ${e.n} times since ${esc(e.first)}</div>` : '';
  const more = e.more && e.more.length ? `<details><summary>${e.more.length} more message${e.more.length > 1 ? 's' : ''}</summary><pre>${esc(e.more.join('\n'))}</pre></details>` : '';
  const ck = [srv, db, e.seq, e.cmd, agent || ''].join('|');
  const cmd = e.seq && e.cmd ? `<div><button data-cmd="${esc(ck)}">Command</button> <span class="mut">transaction ${esc(e.seq)}, command ${e.cmd}</span><div class="cmdout">${cmdCache[ck] || ''}</div></div>` :
    e.seq ? `<div class="mut">transaction ${esc(e.seq)}</div>` : '';
  // Snapshot/agent errors often carry a .NET stack trace: keep the message short, the stack folded
  const sx = /\s(Stack:\s+at\s|at Microsoft\.SqlServer\.)/.exec(e.m || ''), msg = sx ? e.m.slice(0, sx.index) : e.m;
  const stack = sx ? `<details><summary>.NET stack</summary><pre>${esc(e.m.slice(sx.index + 1).replace(/\s+at\s/g, '\n   at '))}</pre></details>` : '';
  return `<div class="m">${esc(msg)}</div>${stack}${cause ? `<div class="m"><b>${esc(cause[1])}: ${esc(cause[2])}</b></div>` : ''}${rpt}${hint}${more}${cmd}`;
}
const cmdCache = {};   // command texts already read, so a table refresh keeps them
document.addEventListener('click', async ev => {
  const b = ev.target.closest('button[data-cmd]');
  if (!b) return;
  ev.stopPropagation();
  const ck = b.dataset.cmd, [srv, db, seq, cmd, agent] = ck.split('|'), out = b.parentNode.querySelector('.cmdout');
  b.disabled = true; out.innerHTML = '<span class="mut">reading the command...</span>';
  try {
    const r = await api(`/api/command?srv=${encodeURIComponent(srv)}&db=${encodeURIComponent(db)}&seq=${encodeURIComponent(seq)}&cmd=${encodeURIComponent(cmd)}&agent=${encodeURIComponent(agent)}`);
    const x = await r.json();
    out.innerHTML = x.error ? `<span class="c-error">${esc(x.error)}</span>` : x.cmd ? `<pre>${esc(x.cmd)}</pre>` : `<span class="mut">The command is no longer in the distribution database. ${esc((x.notes || []).join(' '))}</span>`;
    if (!x.error) cmdCache[ck] = out.innerHTML;
  } catch (e) { out.innerHTML = `<span class="c-error">${esc(e)}</span>`; }
  b.disabled = false;
}, true);
function renderEvents() {
  const ev = (L ? L.events : []).filter(e => textPass((e.x || '').toLowerCase()) && (!ui.srv || !e.k || (itemOfKey(e.k) && passSrv(itemOfKey(e.k)))));
  $('events').innerHTML = ev.length ? ev.map(e => `<div class="ev ${e.k ? 'click' : ''}" data-k="${esc(e.k)}"><span class="mut">${esc(e.t)}</span><span class="dot ${e.l === 'info' ? '' : e.l}"></span><span>${esc(e.x)}</span></div>`).join('') : '<div class="ev"><span></span><span></span><span class="mut">No events yet.</span></div>';
}
$('events').addEventListener('click', ev => { const d = ev.target.closest('[data-k]'); if (d && d.dataset.k && itemOfKey(d.dataset.k)) openItem(d.dataset.k); });
function renderFindings() {
  const rows = S.findings.filter(f => (!ui.srv || f.srv === ui.srv) && textPass([f.sev, f.cat, f.srv, f.obj, f.txt, f.fix].join(' ').toLowerCase())).map(f => ({ s: { k: '' }, x: null, f: f }));
  renderTable('tFind', [
    { k: 'sev', t: 'Severity', v: r => ({ error: 3, warn: 2, info: 1 })[r.f.sev], f: r => `<span class="dot ${r.f.sev === 'info' ? '' : r.f.sev}"></span>${esc(r.f.sev)}` },
    { k: 'cat', t: 'Category', v: r => r.f.cat, f: r => esc(r.f.cat) },
    { k: 'srv', t: 'Server', v: r => r.f.srv, f: r => esc(r.f.srv) },
    { k: 'obj', t: 'Object', v: r => r.f.obj, f: r => esc(r.f.obj) },
    { k: 'txt', t: 'Finding', cls: 'msg', v: r => r.f.txt, f: r => esc(r.f.txt) },
    { k: 'fix', t: 'Recommendation', cls: 'msg', v: r => r.f.fix, f: r => esc(r.f.fix) },
    { k: 'rep', t: 'Repair', v: r => (r.f.rep || []).length, f: r => (r.f.rep || []).length ? repairsHtml('f', r.f.id, r.f.rep, true) : '' }
  ], rows, { k: 'sev', asc: false }, r => `class="lv-${r.f.sev}"`);
}
function renderOverview() {
  const items = [];
  if (L) {
    L.servers.filter(s => s.ok === false).forEach(s => items.push({ h: 'error', k: '', t: 'No answer from ' + s.n, p: s.err }));
    S.lrs.forEach(s => { const x = LL[s.k]; if (x && (x.h === 'error' || x.h === 'warn') && passItem(s, x, 'all')) items.push({ h: x.h, k: s.k, t: s.label, p: x.p }); });
    S.subs.forEach(s => { const x = LS[s.k]; if (x && (x.h === 'error' || x.h === 'warn') && passItem(s, x, 'all')) items.push({ h: x.h, k: s.k, t: s.label, p: x.p }); });
    L.blocking.filter(b => b.agentBlocks).forEach(b => items.push({ h: 'warn', k: '', t: 'An agent blocks ' + b.lbl, p: b.srv + ', session ' + b.spid + ', ' + fmtN(b.ms / 1000, 1) + ' s' }));
    L.ag.filter(a => a.h !== 'ok').forEach(a => items.push({ h: a.h, k: '', t: 'AG ' + a.ag + ' / ' + a.db + ' on ' + a.replica, p: a.p }));
  }
  items.sort((a, b) => RANK[b.h] - RANK[a.h]);
  $('attention').innerHTML = !L ? '<div class="att mut">Waiting for the first data...</div>' : items.length ?
    items.slice(0, 60).map(i => `<div class="att lv-${i.h}" data-k="${esc(i.k)}"><span class="dot ${i.h}"></span>${esc(i.t)}<div class="p">${esc(i.p)}</div></div>`).join('') :
    '<div class="att"><span class="dot ok"></span>All good - nothing needs attention.</div>';
  $('tSrv').innerHTML = '<thead><tr><th>Server</th><th>State</th><th class="num">Query</th><th>At</th></tr></thead><tbody>' + (L ? L.servers.map(s =>
    `<tr><td>${esc(s.n)}${(s.notes || []).length ? `<div class="mut">${esc(s.notes.join(' | '))}</div>` : ''}</td><td>${s.ok === false ? `<span class="c-error">${esc(s.err)}</span>` : s.ok ? '<span class="c-ok">OK</span>' : '<span class="mut">waiting</span>'}${s.running != null && s.running > 5 ? ` <span class="mut">(query running ${s.running} s)</span>` : ''}</td><td class="num">${s.took != null ? fmtN(s.took, 1) + ' s' : ''}</td><td>${esc(s.at)}</td></tr>`).join('') : '') + '</tbody>';
  drawDiagram(false);
}
$('attention').addEventListener('click', ev => { const d = ev.target.closest('[data-k]'); if (d && d.dataset.k) openItem(d.dataset.k); });

// ---------- header, tabs, quick filters ----------
function renderHead() {
  $('ver').textContent = 'v' + S.version + ' · ' + S.auth + ' · since ' + S.started.slice(11, 16);
  if (!L) return;
  const s = L.sum, c = [];
  const tri = o => `<b class="c-ok">${o.ok}</b>${o.warn ? `<b class="c-warn">${o.warn}</b>` : ''}${o.error ? `<b class="c-error">${o.error}</b>` : ''}${o.unknown ? `<b class="mut">${o.unknown}?</b>` : ''}`;
  c.push(`<span class="chip" data-go="subs" title="OK / warning / error / no data">Subscriptions ${tri(s.subs)}</span>`);
  c.push(`<span class="chip" data-go="lrs">Log Readers ${tri(s.lrs)}</span>`);
  c.push(`<span class="chip" data-go="waits" title="Agent sessions waiting for a lock">Blocked <b class="${s.blocked ? 'c-blk' : ''}">${s.blocked}</b></span>`);
  c.push(`<span class="chip" data-go="errors">Errors 1 h <b class="${s.errHour ? 'c-error' : ''}">${s.errHour}</b></span>`);
  if (s.maxLat != null) c.push(`<span class="chip" data-go="subs" data-sort="lat">Max latency <b>${numC(s.maxLat, LAT_W, LAT_E, ' s', 1)}</b></span>`);
  if (s.pending != null) c.push(`<span class="chip" data-go="subs" data-sort="pd">Pending <b>${numC(s.pending, S.pendingWarn, S.pendingWarn * 10)}</b></span>`);
  if (s.rate != null) c.push(`<span class="chip" title="Commands per second, Log Readers + Distribution Agents">Flow <b>${fmtN(s.rate, 1)}</b> cmd/s</span>`);
  if (s.agBad) c.push(`<span class="chip" data-go="ag">AG issues <b class="c-warn">${s.agBad}</b></span>`);
  if (s.down) c.push(`<span class="chip" data-go="overview">Servers down <b class="c-error">${s.down}</b></span>`);
  $('chips').innerHTML = c.join('');
  $('bPause').textContent = L.paused ? 'Resume' : 'Pause';
  if (document.activeElement !== $('intv')) $('intv').value = String(L.interval);
}
$('chips').addEventListener('click', ev => {
  const c = ev.target.closest('[data-go]'); if (!c) return;
  if (c.dataset.sort) ui.sort[c.dataset.go === 'subs' ? 'tSubs' : 'tLrs'] = { k: c.dataset.sort, asc: false };
  setTab(c.dataset.go);
});
function counts() {
  const n = { subs: 0, lrs: 0 };
  S.subs.forEach(s => { if (passItem(s, LS[s.k])) n.subs++; });
  S.lrs.forEach(s => { if (passItem(s, LL[s.k])) n.lrs++; });
  return n;
}
function renderTabs() {
  const n = counts(), s = L ? L.sum : null;
  const badge = (v, cls) => v ? `<span class="n ${cls || ''}">${v}</span>` : '';
  const sev = o => o.error ? 'error' : o.warn ? 'warn' : '';
  const b = {
    subs: badge(n.subs + (n.subs !== S.subs.length ? '/' + S.subs.length : ''), s ? sev(s.subs) : ''),
    lrs: badge(n.lrs + (n.lrs !== S.lrs.length ? '/' + S.lrs.length : ''), s ? sev(s.lrs) : ''),
    waits: s ? badge(s.blocked + s.agentBlocks, 'warn') : '', ag: s ? badge(s.agBad, 'warn') : '',
    errors: s ? badge(s.errHour, 'error') : '', events: L ? badge(L.events.length) : '',
    findings: badge(S.findings.filter(f => f.sev !== 'info').length)
  };
  $('tabs').innerHTML = TABS.map(t => `<a data-t="${t[0]}" class="${ui.tab === t[0] ? 'on' : ''}">${t[1]}${b[t[0]] || ''}</a>`).join('');
}
$('tabs').addEventListener('click', ev => { const a = ev.target.closest('[data-t]'); if (a) setTab(a.dataset.t); });
function renderQuick() {
  const pool = S.subs.map(s => [s, LS[s.k]]).concat(S.lrs.map(s => [s, LL[s.k]]));
  $('quick').innerHTML = QUICK.map(q => {
    const n = q[0] === 'all' ? '' : pool.filter(p => passSrv(p[0]) && quickPass(p[1], q[0]) && textPass(p[0].s + ' ' + liveText(p[1]))).length;
    return `<button data-q="${q[0]}" class="${ui.quick === q[0] ? 'on' : ''}">${esc(q[1])}${n !== '' ? `<span>${n}</span>` : ''}</button>`;
  }).join('');
}
$('quick').addEventListener('click', ev => { const b = ev.target.closest('[data-q]'); if (!b) return; ui.quick = b.dataset.q; save(); renderAll(); });
function setTab(t) {
  ui.tab = t; save();
  document.querySelectorAll('section.tab').forEach(s => s.classList.toggle('on', s.id === 'tab-' + t));
  renderAll();
}
function renderTab() {
  switch (ui.tab) {
    case 'overview': renderOverview(); break;
    case 'subs': renderSubs(); break;
    case 'lrs': renderLrs(); break;
    case 'waits': renderWaits(); break;
    case 'ag': renderAg(); break;
    case 'errors': renderErrors(); break;
    case 'events': renderEvents(); break;
    case 'findings': renderFindings(); break;
  }
}
function renderAll() { renderHead(); renderTabs(); renderQuick(); renderTab(); if (drawer) renderDrawerLive(); }

// ---------- diagram (Mermaid, drawn once per filter; colors and flow follow the live state) ----------
let mermaidOk = false, dsel = null, dsig = '', dseq = 0, dir = S.graph.direction, scale = 1, drawing = false, dframes = [];
function diagramSelection() {
  const filtered = !!(ui.q || ui.srv || ui.quick !== 'all');
  const inc = {}, links = [];
  S.graph.links.forEach(l => {
    if (l.kind !== 'repl') return;
    if (filtered && !l.keys.some(k => SUB[k] && passItem(SUB[k], LS[k]))) return;
    links.push(l); inc[l.a] = inc[l.b] = true;
  });
  S.graph.links.forEach(l => { if (l.kind === 'dist' && inc[l.a]) { links.push(l); inc[l.b] = true; } });
  if (!filtered) S.graph.nodes.forEach(n => { if (n.kind !== 'dist') inc[n.id] = true; });
  return { nodes: S.graph.nodes.filter(n => inc[n.id]), links: links };
}
function buildMmd(sel) {
  const out = ['flowchart ' + dir], styles = [], byCss = {}, order = [];
  let si = 0;
  dframes = [];
  S.graph.servers.forEach(s => {
    const ns = sel.nodes.filter(n => n.srv === s.name);
    if (!ns.length) return;
    si++; dframes[si] = s.name;
    out.push('  subgraph s' + si + '["' + s.title + '"]', '    w' + si + '["' + s.title + '"]:::sp');
    ns.forEach(n => out.push('    ' + n.mmd));
    out.push('  end');
    if (s.css) styles.push('  style s' + si + ' ' + s.css);
  });
  sel.links.forEach((l, i) => { out.push('  ' + l.mmd); if (!byCss[l.css]) { byCss[l.css] = []; order.push(l.css); } byCss[l.css].push(i); });
  return out.concat(styles, order.map(c => '  linkStyle ' + byCss[c].join(',') + ' ' + c), ['  classDef sp fill:none,stroke:none,color:transparent']).join('\n');
}
async function drawDiagram(force) {
  if (!mermaidOk || ui.tab !== 'overview' || drawing) return;
  const sel = diagramSelection();
  const sig = dir + '|' + sel.nodes.map(n => n.id).join(',') + '|' + sel.links.map(l => l.a + '>' + l.b).join(',');
  if (!force && sig === dsig) { paintDiagram(); return; }
  const el = $('diagram');
  if (!sel.nodes.length) { el.innerHTML = '<p class="mut">Nothing matches the filter.</p>'; dsig = sig; dsel = null; return; }
  drawing = true;
  try {
    const r = await mermaid.render('mm' + (++dseq), buildMmd(sel));
    const first = !dsel;
    el.innerHTML = r.svg; dsig = sig; dsel = sel;
    attachDiagram(el); paintDiagram();
    if (first) { scale = 1; zoom(-1); if (scale > 1) zoom(0); }
    $('dinfo').textContent = sel.links.filter(l => l.kind === 'repl').length + ' replication links' + (ui.q || ui.srv || ui.quick !== 'all' ? ' (filtered)' : '');
  } catch (e) { el.textContent = 'Could not draw the diagram: ' + e; }
  drawing = false;
}
function linkOfPath(p, byPair) {
  const m = /L[_-](n\d+)[_-](n\d+)[_-](\d+)/.exec(p.id || '');
  if (!m) return null;
  const list = byPair[m[1] + '>' + m[2]] || [];
  return list[+m[3]] || list[0] || null;
}
function pairs() { const b = {}; (dsel ? dsel.links : []).forEach(l => (b[l.a + '>' + l.b] = b[l.a + '>' + l.b] || []).push(l)); return b; }
function attachDiagram(el) {
  const byPair = pairs();
  el.querySelectorAll('path[id]').forEach(p => {
    const l = linkOfPath(p, byPair);
    if (!l || l.kind !== 'repl' || p.classList.contains('hit')) return;
    const h = p.cloneNode(false);
    h.removeAttribute('id'); h.removeAttribute('marker-end'); h.removeAttribute('marker-start'); h.removeAttribute('style');
    h.setAttribute('class', 'hit');
    h.addEventListener('click', () => openLink(l));
    p.parentNode.insertBefore(h, p.nextSibling);
  });
  el.querySelectorAll('g.node').forEach(g => {
    const m = /flowchart-(n\d+)-/.exec(g.id || '');
    if (m && GN[m[1]]) g.addEventListener('click', ev => { ev.stopPropagation(); const n = GN[m[1]]; $('q').value = ui.q = n.kind === 'dist' ? n.srv : n.db; save(); renderAll(); });
  });
  el.querySelectorAll('g.cluster').forEach(g => {
    const m = /(?:^|-)s(\d+)$/.exec(g.id || '');
    if (m && dframes[+m[1]]) g.addEventListener('click', () => { const v = dframes[+m[1]]; if (S.servers.includes(v)) { ui.srv = v; $('srv').value = v; } else { ui.q = v.toLowerCase(); $('q').value = ui.q; } save(); renderAll(); });
  });
}
function paintDiagram() {
  const svg = $('diagram').querySelector('svg');
  if (!svg || !dsel || !L) return;
  const byPair = pairs();
  svg.querySelectorAll('path[id]').forEach(p => {
    const l = linkOfPath(p, byPair);
    if (!l || l.kind !== 'repl') return;
    let lvl = '', rate = 0, pend = 0, blk = false, lat = null;
    const lines = [];
    l.keys.forEach(k => {
      const x = LS[k], s = SUB[k];
      if (!x) return;
      if (RANK[x.h] > RANK[lvl]) lvl = x.h;
      rate += x.rt || 0; pend += x.pd || 0; blk = blk || !!x.blk;
      if (x.lat != null) lat = Math.max(lat || 0, x.lat);
      lines.push(`${s.pub} -> ${s.subscriber}/${s.subDb}: ${x.h}${x.st ? ', ' + x.st : ''}${x.lat != null ? ', latency ' + x.lat + ' s' : ''}${x.pd != null ? ', pending ' + fmtN(x.pd) : ''}${x.rt ? ', ' + fmtN(x.rt, 1) + ' cmd/s' : ''}${x.p ? ' - ' + x.p : ''}`);
    });
    p.style.stroke = blk ? '#7c3aed' : COLOR[lvl || 'unknown'];
    p.style.strokeWidth = (rate > 0 ? Math.min(7, 2.5 + Math.log10(1 + rate) * 1.5) : 2) + 'px';
    p.classList.toggle('flow', rate > 0 && !blk);
    p.classList.toggle('blocked', blk);
    p.style.setProperty('--spd', (rate > 0 ? Math.max(0.3, 1.6 - Math.log10(1 + rate) * 0.45) : 2) + 's');
    const h = p.nextSibling && p.nextSibling.classList && p.nextSibling.classList.contains('hit') ? p.nextSibling : p;
    let t = h.querySelector('title');
    if (!t) { t = document.createElementNS('http://www.w3.org/2000/svg', 'title'); h.appendChild(t); }
    t.textContent = lines.join('\n') + '\n(click for details)';
  });
  svg.querySelectorAll('g.node').forEach(g => {
    const m = /flowchart-(n\d+)-/.exec(g.id || '');
    const n = m && GN[m[1]];
    if (!n || n.kind !== 'db') return;
    const lr = S.lrs.find(l => l.publisher === n.srv && l.pubDb === n.db);
    const x = lr && LL[lr.k];
    const shape = g.querySelector('path, rect, polygon');
    if (shape && x) { shape.style.stroke = COLOR[x.h]; shape.style.strokeWidth = x.h === 'ok' ? '1.5px' : '3px'; }
  });
}
function openLink(l) {
  const keys = l.keys.filter(k => SUB[k]);
  if (keys.length === 1) { openItem(keys[0]); return; }
  drawer = { k: '', list: keys, hours: 6, data: null };
  $('drawer').classList.add('on');
  $('dTitle').textContent = keys.length + ' subscriptions on this line';
  $('dDetail').innerHTML = '';
  renderDrawerLive();
}
function zoom(f) {
  const svg = $('diagram').querySelector('svg'), w = $('dwrap');
  if (f === -1 && svg) { const r = svg.getBoundingClientRect(), k = scale; scale = Math.min(1.5, (w.clientWidth - 30) / (r.width / k), (w.clientHeight - 30) / (r.height / k)); }
  else scale = f === 0 ? 1 : scale * f;
  $('diagram').style.transform = 'scale(' + scale + ')';
}
document.querySelectorAll('[data-z]').forEach(b => b.addEventListener('click', () => zoom(+b.dataset.z)));
$('bDir').addEventListener('click', () => { dir = dir === 'LR' ? 'TB' : 'LR'; $('bDir').textContent = dir === 'LR' ? 'Vertical' : 'Horizontal'; drawDiagram(true); });
function loadMermaid() {
  if (!S.lib) { $('diagram').innerHTML = '<p class="mut" style="padding:20px">mermaid.min.js was not found next to the script - the diagram is not available. All tables work.</p>'; return; }
  const sc = document.createElement('script');
  sc.src = '/mermaid.min.js?t=' + T;
  sc.onload = () => {
    mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', maxTextSize: 5000000, maxEdges: 20000, flowchart: { htmlLabels: true, useMaxWidth: false, curve: 'basis' } });
    mermaidOk = true; drawDiagram(true);
  };
  sc.onerror = () => { $('diagram').textContent = 'The diagram library could not be loaded.'; };
  document.head.appendChild(sc);
}

// ---------- detail drawer ----------
function openItem(k) {
  if (!itemOfKey(k)) return;
  const hours = drawer && drawer.hours || 6;
  drawer = { k: k, list: null, hours: hours, data: null, loading: false };
  $('drawer').classList.add('on');
  const s = SUB[k], l = LR[k];
  $('dTitle').textContent = s ? `${s.pub}: ${s.publisher}/${s.pubDb} → ${s.subscriber}/${s.subDb}` : `Log Reader ${l.publisher}/${l.pubDb}`;
  renderDrawerLive(); loadDetail();
}
function closeDrawer() { drawer = null; $('drawer').classList.remove('on'); }
$('dClose').addEventListener('click', closeDrawer);
async function loadDetail() {
  const d = drawer;
  if (!d || !d.k) return;
  d.loading = true; renderDetail();
  try {
    const r = await api(`/api/detail?k=${encodeURIComponent(d.k)}&h=${d.hours}`);
    const x = await r.json();
    if (drawer !== d) return;
    d.data = x;
  } catch (e) { if (drawer === d) d.data = { error: 'The monitor did not answer: ' + e }; }
  if (drawer !== d) return;
  d.loading = false; renderDetail();
}
function fact(name, value) { return value === '' || value == null ? '' : `<div>${esc(name)}</div><div>${value}</div>`; }
function renderDrawerLive() {
  const d = drawer;
  if (!d) return;
  if (d.list) {
    $('dLive').innerHTML = d.list.map(k => { const s = SUB[k], x = LS[k]; return `<div class="att lv-${lvOf(x)}" data-k="${esc(k)}"><span class="dot ${lvOf(x)}"></span><b>${esc(s.pub)}</b> → ${esc(s.subscriber + ' / ' + s.subDb)}<div class="p">${esc(x ? [x.st, x.lat != null ? 'latency ' + x.lat + ' s' : '', x.pd != null ? 'pending ' + fmtN(x.pd) : '', x.p].filter(v => v).join(' · ') : 'no data')}</div></div>`; }).join('');
    return;
  }
  const s = SUB[d.k], l = LR[d.k], x = s ? LS[d.k] : LL[d.k];
  let h = '<div class="facts">';
  h += fact('Health', `<span class="dot ${lvOf(x)}"></span>${esc(lvOf(x))}${x && x.p ? ` - <span class="${x.h === 'error' ? 'c-error' : 'c-warn'}">${esc(x.p)}</span>` : ''}`);
  if (x) {
    h += fact('Status', pill(x.st) + (x.job ? ` <span class="mut">agent job ${esc(x.job)}</span>` : ''));
    h += fact('Latency', x.lat != null ? numC(x.lat, LAT_W, LAT_E, ' s', 1) + spark(x.lh, '#1e88e5') : '');
    if (s) {
      h += fact('Pending commands', x.pd != null ? numC(x.pd, S.pendingWarn, S.pendingWarn * 10) + spark(x.ph, '#8e24aa') + (x.eta != null ? ` <span class="mut">about ${esc(fmtAge(x.eta))} of agent work</span>` : '') : '');
      h += fact('Oldest pending', x.old != null ? esc(fmtAge(x.old)) + ' <span class="mut">(age of the oldest undelivered transaction)</span>' : '');
    }
    h += fact('Throughput', x.rt != null ? fmtN(x.rt, 1) + ' cmd/s' + spark(x.rh, '#2e7d32') : '');
    if (s) h += fact('Last synchronization', esc(x.last));
    h += fact('Last agent entry', x.age != null ? esc(fmtAge(x.age)) + ' ago' : '');
    h += fact('Last message', esc(x.msg));
    if (l) h += fact('Commands (session)', fmtN(x.cmds));
    if (l) h += fact('Availability group', esc(x.ag));
    h += fact('Blocking', x.blk ? `<span class="c-blk">${esc(x.blk)}</span>` : '');
  }
  if (s) {
    h += fact('Type', esc(s.type + ' · ' + s.subType + (s.tables ? ' · ' + s.tables + ' tables' : '')));
    if ((s.filters || []).length) h += fact('Filters', s.filters.map(f => `<b>${esc(f.a)}</b>${f.rows ? ' rows WHERE ' + esc(f.rows) : ''}${f.cols ? (f.rows ? ';' : '') + ' columns not published: ' + esc(f.cols) : ''}`).join('<br>'));
    h += fact('Distributor', esc(s.dist + ' / ' + s.distDb) + (x && x.agent ? ` <span class="mut">agent id ${esc(x.agent)}</span>` : ''));
    h += fact('Notes (scan)', esc(s.notes));
    if (s.lr && LL[s.lr]) h += fact('Log Reader', `<span class="dot ${lvOf(LL[s.lr])}"></span>${esc(LL[s.lr].st || '')} ${LL[s.lr].lat != null ? '· latency ' + LL[s.lr].lat + ' s' : ''} ${esc(LL[s.lr].p)}`);
  } else h += fact('Distributor', esc(l.dist + ' / ' + l.distDb));
  h += '</div>';
  if (x && x.ses && x.ses.length) {
    h += '<h3>Agent sessions now</h3><table><thead><tr><th>Server</th><th>Side</th><th>State</th><th>Wait</th><th class="num">CPU ms</th><th>SQL</th></tr></thead><tbody>' +
      x.ses.map(e => `<tr><td class="nw">${esc(e.srv)} <span class="mut">#${e.spid}</span></td><td>${esc(e.side)}</td><td>${esc(e.req || e.st)}${e.tran ? ` <span class="mut">open tran ${e.tran}</span>` : ''}</td><td>${e.blk > 0 ? `<span class="c-blk">${esc(e.w)} ${fmtN(e.ms / 1000, 1)} s - blocked by ${e.blk}</span>` : esc(e.w ? e.w + ' ' + fmtN(e.ms / 1000, 1) + ' s' : '')}</td><td class="num">${fmtN(e.cpu)}</td><td class="msg"><span class="sql clip" title="${esc(e.sql)}">${esc((e.sql || '').slice(0, 300))}</span></td></tr>`).join('') + '</tbody></table>';
  }
  const bl = L ? L.blocking.filter(b => b.k === d.k && !b.agentBlocks) : [];
  if (bl.length) h += '<h3>Blocked by</h3>' + bl.map(b => `<div class="err"><b>${esc(b.byLbl || b.hJob || b.hProg || 'session ' + b.by)}</b> <span class="mut">${esc([b.srv, 'chain ' + b.chain, b.hHost, b.hLogin, b.hDb, b.hSt].filter(v => v).join(' · '))}${b.hTran ? ' · open transactions ' + b.hTran : ''}</span><div class="mut">${esc(b.w)} ${fmtN(b.ms / 1000, 1)} s on ${esc(b.res)}</div>${b.hSql ? `<pre>${esc(b.hSql)}</pre>` : ''}</div>`).join('');
  const aw = L ? L.agentWaits.find(a => a.k === d.k) : null;
  if (aw && aw.top.length) h += '<h3>Waits of the agent sessions (since the monitor started)</h3>' + bars(aw.top, w => w.w, w => w.ms, (v, w) => fmtWait(v) + (w.last ? ` (${fmtWait(w.last)})` : ''));
  $('dLive').innerHTML = h;
}
$('dLive').addEventListener('click', ev => { const a = ev.target.closest('[data-k]'); if (a && a.dataset.k) openItem(a.dataset.k); });
function bucketTime(c, i) {
  const t0 = new Date(c.Start.replace(' ', 'T')).getTime(), a = new Date(t0 + i * c.Size * 1000), b = new Date(t0 + (i + 1) * c.Size * 1000);
  const f = x => x.toTimeString().slice(0, 5);
  return (c.Size >= 86400 / 4 ? a.toLocaleDateString() + ' ' : '') + f(a) + '-' + f(b);
}
function chart(c, vals, color, unit, bars, status) {
  const n = vals.length, W = 720, H = 120, top = 14, bot = 22, bw = W / n;
  const nums = vals.filter(v => v != null);
  const max = Math.max(bars ? 1 : 0.1, ...nums);
  const y = v => top + (H - top - bot) * (1 - v / max);
  let g = `<line x1="0" y1="${top}" x2="${W}" y2="${top}" stroke="var(--line)"/><line x1="0" y1="${H - bot}" x2="${W}" y2="${H - bot}" stroke="var(--line)"/>`;
  if (bars) vals.forEach((v, i) => { if (v > 0) g += `<rect x="${(i * bw + 0.3).toFixed(1)}" y="${y(v).toFixed(1)}" width="${Math.max(1, bw - 0.6).toFixed(1)}" height="${(H - bot - y(v)).toFixed(1)}" fill="${color}"/>`; });
  else {
    let d = '', pen = false;
    vals.forEach((v, i) => { if (v == null) { pen = false; return; } d += (pen ? 'L' : 'M') + (i * bw + bw / 2).toFixed(1) + ' ' + y(v).toFixed(1); pen = true; });
    g += `<path d="${d}" fill="none" stroke="${color}" stroke-width="1.8"/>`;
  }
  if (status) c.St.forEach((s, i) => { if (ST_COLOR[s]) g += `<rect x="${(i * bw).toFixed(1)}" y="${H - bot + 3}" width="${(bw + 0.5).toFixed(1)}" height="5" fill="${ST_COLOR[s]}"/>`; });
  vals.forEach((v, i) => { g += `<rect x="${(i * bw).toFixed(1)}" y="0" width="${bw.toFixed(1)}" height="${H}" fill="transparent"><title>${esc(bucketTime(c, i))}: ${v == null ? 'no data' : fmtN(v, 1) + unit}${status ? ' · ' + (ST_NAME[c.St[i]] || 'no history') : ''}</title></rect>`; });
  const endT = new Date(new Date(c.Start.replace(' ', 'T')).getTime() + n * c.Size * 1000);
  g += `<text x="2" y="10">${fmtN(max, 1)}${unit}</text><text x="2" y="${H - 2}">${esc(c.Start.slice(5, 16))}</text><text x="${W - 2}" y="${H - 2}" text-anchor="end">${esc(endT.toTimeString().slice(0, 5))}</text>`;
  return `<svg class="chart" viewBox="0 0 ${W} ${H}">${g}</svg>`;
}
// The agents write performance statistics every 5 minutes as XML in their history (<stats ...>)
function statsHtml(msgs, isLr) {
  const m = (msgs || []).find(x => /^\s*<stats/.test(x.m));
  if (!m) return '';
  let doc;
  try { doc = new DOMParser().parseFromString(m.m, 'application/xml'); } catch (e) { return ''; }
  const st = doc.querySelector('stats');
  if (!st || doc.querySelector('parsererror')) return '';
  const num = (el, a) => el && el.getAttribute(a) != null ? +el.getAttribute(a) : null;
  const since = st.querySelector('sincelaststats');
  const kid = (el, n) => el ? Array.from(el.children).find(c => c.tagName === n) : null;
  const msg = (st.querySelector('message') || {}).textContent || '';
  let h = `<h3>Agent statistics <span class="mut">(${esc(m.t)}${since ? ', last ' + esc(fmtAge(num(since, 'elapsedtime'))) : ''})</span></h3><div class="facts">`;
  const r = kid(since, 'reader') || kid(st, 'reader'), w = kid(since, 'writer') || kid(st, 'writer'), state = num(st, 'state');
  const rd = isLr ? 'Reader (transaction log)' : 'Reader (distribution database)', wr = isLr ? 'Writer (distribution database)' : 'Writer (subscriber)';
  h += fact('Commands', since ? fmtN(num(since, 'cmds')) + ' <span class="mut">(' + fmtN(num(since, 'cmdspersec'), 1) + ' cmd/s while working)</span>' : '');
  h += fact(rd, `fetching ${fmtN(num(r, 'fetch'))} s, waiting for the writer ${fmtN(num(r, 'wait'))} s`);
  h += fact(wr, `writing ${fmtN(num(w, 'write'))} s, waiting for the reader ${fmtN(num(w, 'wait'))} s <span class="mut">(waiting is normal when there is nothing to do)</span>`);
  h += fact('Since the agent started', `work ${fmtN(num(st, 'work'))} s, idle ${fmtN(num(st, 'idle'))} s`);
  // state 2/3: the agent itself saw one thread wait for the other longer than -MessageInterval
  let verdict = '';
  if (state === 2) verdict = isLr ? 'The reader waits for the writer: writing to the distribution database is the bottleneck (distributor log or disk, blocking in the distribution database).'
                                  : 'The reader waits for the writer: applying the commands at the subscriber is the bottleneck (load or blocking at the subscriber, triggers, missing indexes, slow storage).';
  else if (state === 3) verdict = isLr ? 'The writer waits for the reader: reading the transaction log is the bottleneck (large transactions, slow log storage, many VLFs, AG secondary not hardened).'
                                       : 'The writer waits for the reader: reading the commands from the distribution database is the bottleneck (distributor load, a large MSrepl_commands, cleanup job, network).';
  h += fact('Agent says', esc(msg)) + '</div>';
  if (verdict) h += `<div class="c-warn" style="margin-top:4px">${esc(verdict)}</div>`;
  return h;
}
function renderDetail() {
  const d = drawer;
  if (!d || !d.k) return;
  const s = SUB[d.k], x = d.data;
  let h = `<h3>History <select id="dHours">${[1, 6, 24, 72, 168, 720].map(v => `<option value="${v}" ${v === d.hours ? 'selected' : ''}>${v < 24 ? v + ' h' : v / 24 + ' d'}</option>`).join('')}</select>
    <button id="dReload">Reload</button>${s && s.type === 'Transactional' ? ` <button id="dTracer" ${S.tracer ? '' : 'disabled title="Start the monitor with -AllowTracerTokens"'}>Post tracer token</button>` : ''}
 <button id="dAi" title="Markdown file with this problem, names and values masked - for ChatGPT, Claude, Copilot...">Report for AI</button>
    ${d.loading ? '<span class="mut">loading...</span>' : ''}</h3>`;
  if (x && x.error) h += `<div class="c-error">${esc(x.error)}</div>`;
  if (x && !x.error) {
    if (x.notes && x.notes.length) h += `<div class="c-warn">${esc(x.notes.join(' | '))}</div>`;
    if ((x.repairs || []).length) h += repairsHtml('k', d.k, x.repairs, false);
    if (x.chart) {
      const perSec = x.chart.Cmds.map(v => v / x.chart.Size);
      h += `<div class="mut">Latency (highest per interval, s) and status: <span style="color:${ST_COLOR[3]}">■</span> running <span style="color:${ST_COLOR[4]}">■</span> idle <span style="color:${ST_COLOR[5]}">■</span> retrying <span style="color:${ST_COLOR[6]}">■</span> failed <span style="color:${ST_COLOR[2]}">■</span> stopped</div>` + chart(x.chart, x.chart.Lat, '#1e88e5', ' s', false, true);
      h += `<div class="mut">Commands ${s ? 'delivered' : 'read from the log'} (average per second in each interval of ${esc(fmtAge(x.chart.Size))})</div>` + chart(x.chart, perSec, '#2e7d32', ' cmd/s', true, false);
    }
    if (s && (x.articles || []).length) {
      const total = x.articles.reduce((a, b) => a + b.n, 0);
      h += `<h3>Pending commands per article: ${fmtN(total)} in ${fmtN(x.transactions)} transactions${x.now ? ` <span class="mut">(read ${esc(String(x.now).slice(11))})</span>` : ''}</h3>` + bars(x.articles.slice(0, 25), a => a.a + (a.src && a.src !== a.a ? ' (' + a.src + ')' : ''), a => a.n, v => fmtN(v));
      if ((x.topTx || []).length) h += '<div class="hint" style="margin-top:8px">Largest pending transactions - one big transaction (mass update/delete) delays everything behind it:</div><table><thead><tr><th>Transaction (xact_seqno)</th><th class="num">Commands</th><th>Entered the distributor</th></tr></thead><tbody>' +
        x.topTx.map(t => `<tr><td class="sql">${esc(t.seq)}</td><td class="num">${fmtN(t.n)}</td><td>${esc(t.t)}</td></tr>`).join('') + '</tbody></table>';
    } else if (s && LS[d.k] && LS[d.k].pd === 0) h += '<h3>Pending commands</h3><div class="mut">Nothing is waiting in the distribution database.</div>';
    if ((x.errors || []).length) {
      h += `<h3>Errors (${x.errors.length})</h3>` + collapseErrors(x.errors).slice(0, 40).map(e => `<div class="err"><span class="mut">${esc(e.t)} · error ${esc(e.code)}</span>${errHtml(e, s ? s.distInst : LR[d.k].distInst, s ? s.distDb : LR[d.k].distDb, s && LS[d.k] ? LS[d.k].agent : '')}</div>`).join('');
    } else if (x.now) h += '<h3>Errors</h3><div class="mut">No errors in this period.</div>';
    if (s && (x.tracer || []).length) h += '<h3>Tracer tokens</h3><table><thead><tr><th>Posted</th><th class="num">Publisher → distributor</th><th class="num">Distributor → subscriber</th><th class="num">Total</th></tr></thead><tbody>' +
      x.tracer.map(t => `<tr><td>${esc(t.t)}</td><td class="num">${t.toDist != null ? fmtN(t.toDist, 1) + ' s' : '<span class="mut">pending</span>'}</td><td class="num">${t.toSub != null ? fmtN(t.toSub, 1) + ' s' : '<span class="mut">pending</span>'}</td><td class="num">${t.total != null ? fmtN(t.total, 1) + ' s' : ''}</td></tr>`).join('') + '</tbody></table>';
    h += statsHtml(x.msgs, !s);
    if ((x.msgs || []).length) h += `<h3>Agent messages (changes only, newest first)</h3><table><tbody>` +
      x.msgs.filter(m => !/^\s*<stats/.test(m.m)).slice(0, 120).map(m => `<tr><td class="nw mut">${esc(m.t)}</td><td>${m.st ? `<span class="dot" style="background:${ST_COLOR[m.st] || ''}"></span>${esc(ST_NAME[m.st] || '')}` : ''}</td><td>${esc(m.m)}</td></tr>`).join('') + '</tbody></table>';
  }
  $('dDetail').innerHTML = h;
  $('dHours').onchange = e => { d.hours = +e.target.value; loadDetail(); };
  $('dReload').onclick = loadDetail;
  if ($('dTracer')) $('dTracer').onclick = postTracer;
  $('dAi').onclick = aiReport;
}

// ---------- repairs and the report for an AI assistant ----------
const REP = {};
const REP_LEVEL = { safe: 'safe - runs with -AllowRepair', full: 'changes data or settings - runs with -AllowAllRepair', script: 'script only - needs a password or a decision' };
function repairsHtml(kind, id, list, compact) {
  REP[kind + ':' + id] = list;
  return (compact ? '' : '<h3>Repairs</h3>') + list.map((a, i) => {
    const ref = `data-rk="${kind}" data-rid="${esc(String(id))}" data-ri="${i}"`;
    const run = a.run ? `<button data-rrun ${ref}>Run</button>` : (a.level === 'script' ? '' : `<span class="mut"> to run it here start the monitor with ${a.level === 'full' ? '-AllowAllRepair' : '-AllowRepair'}</span>`);
    return `<div class="rep"><b>${esc(a.title)}</b> <span class="mut">[${esc(REP_LEVEL[a.level] || a.level)}]</span>` +
      (compact ? '' : `<div class="mut">${esc(a.why)}</div><div class="mut">Risk: ${esc(a.risk)}</div>`) +
      `<div><button data-rsql ${ref}>T-SQL</button> <button data-rsave ${ref}>Save .sql</button> ${run}</div><pre class="rsql" style="display:none">${esc(a.sql)}</pre></div>`;
  }).join('');
}
function saveText(name, text) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([text], { type: 'text/plain;charset=utf-8' }));
  a.download = name; document.body.appendChild(a); a.click();
  setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
}
document.addEventListener('click', async ev => {
  const b = ev.target.closest('button[data-ri]');
  if (!b) return;
  ev.stopPropagation();
  const list = REP[b.dataset.rk + ':' + b.dataset.rid], a = list && list[+b.dataset.ri];
  if (!a) return;
  if (b.hasAttribute('data-rsql')) { const pre = b.closest('.rep').querySelector('pre'); pre.style.display = pre.style.display === 'none' ? 'block' : 'none'; return; }
  if (b.hasAttribute('data-rsave')) { saveText('repair-' + a.id + '.sql', a.sql); return; }
  let c = 'yes';
  if (a.level === 'full') {
    c = prompt(`${a.title}\n\nRisk: ${a.risk}\n\nType ${a.confirm} to run it:`);
    if (c === null) return;
    if (c.trim() !== a.confirm) { toast('Not confirmed - nothing was run.'); return; }
  } else if (!confirm(`Run: ${a.title}?\n\n${a.sql}`)) return;
  b.disabled = true; toast('Running the repair...');
  try {
    const q = (b.dataset.rk === 'f' ? 'f=' : 'k=') + encodeURIComponent(b.dataset.rid);
    const r = await api(`/api/repair?${q}&a=${encodeURIComponent(a.id)}&c=${encodeURIComponent(c)}`, { method: 'POST' });
    const x = await r.json();
    toast(x.error ? x.error : x.message);
    if (drawer && drawer.k) setTimeout(() => { if (drawer && drawer.k) loadDetail(); }, 4000);
  } catch (e) { toast('The monitor did not answer: ' + e); }
  b.disabled = false;
});
async function aiReport() {
  const d = drawer;
  if (!d || !d.k) return;
  try {
    const r = await api('/api/aireport?k=' + encodeURIComponent(d.k), { method: 'POST' });
    const x = await r.json();
    if (x.error) { toast(x.error); return; }
    saveText(x.file.split(/[\\/]/).pop(), x.md);
    toast('Report for AI saved: ' + x.file + (x.masked ? ' - names and values masked; the tokens are in ' + x.map + ' (keep it, do not paste it).' : ' - NOT masked (-NoMask).'));
  } catch (e) { toast('The monitor did not answer: ' + e); }
}
async function postTracer() {
  const d = drawer;
  try {
    const r = await api('/api/tracer?k=' + encodeURIComponent(d.k), { method: 'POST' });
    const x = await r.json();
    if (x.error) { toast(x.error); return; }
    toast('Tracer token ' + x.tracerId + ' posted - the times appear when it reaches the distributor and the subscribers.');
    setTimeout(() => { if (drawer === d) loadDetail(); }, 6000);
    setTimeout(() => { if (drawer === d) loadDetail(); }, 25000);
  } catch (e) { toast('The monitor did not answer: ' + e); }
}

// ---------- polling and controls ----------
function conn(ok, why) {
  const c = $('conn');
  c.className = 'conn ' + (!ok ? 'down' : L && L.paused ? 'paused' : 'live');
  $('connText').textContent = !ok ? 'no connection to the monitor' : L ? (L.paused ? 'paused · ' : 'live · ') + L.time.slice(11) : 'connected';
  $('banner').style.display = ok ? 'none' : 'block';
  if (!ok) $('banner').textContent = stopped ? 'The monitor was stopped. Run the script again to continue.' : 'The monitor does not answer (' + (why || 'stopped or unreachable') + '). The page reconnects by itself.';
}
async function poll() {
  clearTimeout(pollTimer);
  try {
    const r = await api('/api/state?since=' + (L ? L.seq : -1));
    if (r.status === 200) {
      L = await r.json(); LS = {}; LL = {};
      L.subs.forEach(x => LS[x.k] = x); L.lrs.forEach(x => LL[x.k] = x);
      renderAll(); conn(true);
    } else if (r.status === 204) conn(true);
    else conn(false, 'HTTP ' + r.status);
  } catch (e) { conn(false); }
  pollTimer = setTimeout(poll, 2000);
}
async function control(a, v) {
  try {
    const r = await api('/api/control?a=' + a + (v != null ? '&v=' + v : ''), { method: 'POST' });
    const x = await r.json();
    if (x.error) toast(x.error);
    poll();
    return x;
  } catch (e) { toast('The monitor did not answer.'); }
}
$('bPause').addEventListener('click', () => control(L && L.paused ? 'resume' : 'pause'));
$('bNow').addEventListener('click', () => { control('refresh'); toast('Querying all servers now (pending commands too)...'); });
$('intv').addEventListener('change', e => control('interval', e.target.value));
$('bStop').addEventListener('click', async () => {
  if (!confirm('Stop the monitor? The PowerShell script ends; nothing on the servers changes.')) return;
  stopped = true; await control('stop');
});
let qTimer = null;
$('q').value = ui.q;
$('q').addEventListener('input', () => { clearTimeout(qTimer); qTimer = setTimeout(() => { ui.q = $('q').value.trim(); save(); renderAll(); }, 250); });
$('srv').innerHTML += S.servers.map(s => `<option value="${esc(s)}">${esc(s)}</option>`).join('');
$('srv').value = S.servers.includes(ui.srv) ? ui.srv : (ui.srv = '');
$('srv').addEventListener('change', () => { ui.srv = $('srv').value; save(); renderAll(); });
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') { if (drawer) closeDrawer(); else if (document.activeElement === $('q')) $('q').blur(); }
  if (e.key === '/' && document.activeElement.tagName !== 'INPUT' && document.activeElement.tagName !== 'SELECT') { e.preventDefault(); $('q').focus(); }
});
setTab(TABS.some(t => t[0] === ui.tab) ? ui.tab : 'overview');
renderHead();
loadMermaid();
poll();
</script>
</body>
</html>
'@

if ($Monitor) { Start-ReplMonitor; return }

# ---------------------------------------------------------------------------
# 11. Files
# ---------------------------------------------------------------------------
$utf8 = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $OutputDir 'topology.mmd'), $mmdText, $utf8)
[IO.File]::WriteAllText((Join-Path $OutputDir 'topology.dot'), $dotText, $utf8)
Export-ReportCsv ($edges | Sort-Object PubServer, PubDb, Publication, SubServer, SubDb |
    Select-Object Distributor, DistributionDb, DistributorInstance, PubServer, PubInstance, PubDb, Publication, PubType, Tables, SubServer, SubInstance, SubDb, SubType,
                  Status, StatusText, Health, AgentStatus, Job, @{ n = 'LatencySec'; e = { $_.Latency } }, LastSync, @{ n = 'PendingCmds'; e = { $_.Pending } },
                  Fails, Retries, SkipErrors, Problem, RowDiff, Message, Change, ChangeText) 'edges.csv'
Export-ReportCsv ($articles | Sort-Object PubServer, PubDb, Publication, Article | Select-Object PubServer, PubDb, Publication, Article, Source, Destination, RowFilter, ExcludedColumns, Change) 'articles.csv'
Export-ReportCsv $findings 'findings.csv'

# Repairs for the problems of this run (repairs.sql, every block commented out) and the report for an AI assistant
$repProblems = New-Object System.Collections.Generic.List[object]
foreach ($e in ($liveSubs | Where-Object { $_.Health -in 'error', 'warn' })) {
    $P = New-Problem
    $P.Kind = 'sub'; $P.Label = "$($e.Publication): $($e.PubServer)/$($e.PubDb) -> $($e.SubServer)/$($e.SubDb)"; $P.Level = $e.Health; $P.Problem = [string]$e.Problem
    $P.Status = [string]$e.AgentStatus; $P.Msg = [string]$e.Message; $P.Text = "$($e.Problem) $($e.Message)"
    $P.PubServer = [string]$e.PubServer; $P.PubName = [string]$e.PubServerRaw; $P.PubDb = [string]$e.PubDb; $P.Publication = [string]$e.Publication; $P.PubType = [string]$e.PubType
    $P.SubServer = [string]$e.SubServer; $P.SubName = [string]$e.SubServerRaw; $P.SubDb = [string]$e.SubDb; $P.SubType = [string]$e.SubType
    $P.DistServer = [string]$e.Distributor; $P.DistDb = [string]$e.DistributionDb
    if ($e.JobKey) {
        $P.JobSrv = ($e.JobKey -split '\|')[0]; $P.JobId = ($e.JobKey -split '\|')[1]
        if ($jobIdx.ContainsKey($e.JobKey)) {
            $j = $jobIdx[$e.JobKey]; $P.JobName = [string]$j.name
            if (-not $j.enabled) { $P.Job = 'disabled' } elseif ($j.running) { $P.Job = 'running' } else { $P.Job = 'not running' }
        }
    }
    $repProblems.Add($P)
}
foreach ($l in ($logReaderRows | Where-Object { $_.Health -ne 'ok' })) {
    $P = New-Problem
    $P.Kind = 'lr'; $P.Label = "Log Reader $($l.Publisher)/$($l.PubDb)"; $P.Level = $l.Health; $P.Status = [string]$l.Status; $P.Msg = [string]$l.Message
    $P.Text = [string]$l.Message; $P.Job = Get-JobStateWord ([string]$l.Job); $P.PubServer = [string]$l.Publisher; $P.PubDb = [string]$l.PubDb; $P.DistServer = [string]$l.Distributor
    if ($l.JobKey) {
        $P.JobSrv = ($l.JobKey -split '\|')[0]; $P.JobId = ($l.JobKey -split '\|')[1]
        if ($jobIdx.ContainsKey($l.JobKey)) { $P.JobName = [string]$jobIdx[$l.JobKey].name }
    }
    $inst = Get-PrimaryInstance $l.Publisher
    if (-not $inst) { $inst = $l.Publisher }
    $dbU = ([string]$l.PubDb).ToUpperInvariant()
    if ($serverInfo.ContainsKey($inst) -and $serverInfo[$inst].Dbs.ContainsKey($dbU)) { $P.LogWait = [string]$serverInfo[$inst].Dbs[$dbU].log_reuse_wait_desc }
    $repProblems.Add($P)
}
$repBlocks = New-Object System.Collections.Generic.List[string]
foreach ($P in $repProblems) { foreach ($a in (Get-RepairActions $P)) { $repBlocks.Add((Format-RepairScript $P.Label $a)) } }
foreach ($f in $findings) { foreach ($a in (Get-FindingRepairs $f)) { $repBlocks.Add((Format-RepairScript "$($f.Server) $($f.Object)" $a)) } }
$repairsFile = ''
if ($repBlocks.Count) {
    $repairsFile = Join-Path $OutputDir 'repairs.sql'
    $head = @("-- Repairs for the problems found by Get-ReplTopology.ps1 $scriptVersion on $($generated.ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)).",
              '-- Every block is commented out, so running this whole file changes nothing. Copy one block, read it,',
              '-- run it in SSMS with Query > SQLCMD Mode (the :CONNECT lines). The monitor (-Monitor / -Console) can run them',
              '-- with -AllowRepair (safe ones) or -AllowAllRepair (all except the scripts that need a password).', '')
    Set-Content -LiteralPath $repairsFile -Value (($head -join "`r`n") + (($repBlocks | ForEach-Object { "/*`r`n$_`r`n*/" }) -join "`r`n`r`n")) -Encoding UTF8
}
if ($rowCountRows.Count -gt 0) { Export-ReportCsv $rowCountRows 'rowcounts.csv' }

$srvRows = @()
foreach ($i in ($serverInfo.Values | Sort-Object Server)) { $srvRows += $i }
foreach ($f in ($failed.Keys | Sort-Object)) {
    if (-not $serverInfo.ContainsKey($f)) {
        $srvRows += [pscustomobject]@{ Server = $f; ConnectedAs = $connectName[$f]; Version = ''; Edition = ''; Login = ''; Sysadmin = $null; Port = $null; Transport = ''
                                       AgentService = ''; DistributionDbs = ''; RemoteDistributor = ''; AgRole = ''; Aliases = ''; Publications = 0; Error = $failed[$f]
                                       Support = ''; UpgradeLimit = '' }
    }
}
Export-ReportCsv ($srvRows | Select-Object Server, ConnectedAs, Version, Edition, Login, Sysadmin, Port, AgentService, DistributionDbs, RemoteDistributor, AgRole, Aliases,
                                           Publications, Support, UpgradeLimit, Error) 'servers.csv'
if ($CompareTo) { Export-ReportCsv $changes 'changes.csv' }

# topology.json: input for -CompareTo next time
$jsonEdges = @($liveEdges | ForEach-Object {
    [ordered]@{ Key = $_.Key; PubKey = $_.PubKey; Distributor = $_.Distributor; DistributorInstance = $_.DistributorInstance; DistributionDb = $_.DistributionDb
                PubServer = $_.PubServer; PubInstance = $_.PubInstance; PubDb = $_.PubDb; Publication = $_.Publication; PubType = $_.PubType
                SubServer = $_.SubServer; SubInstance = $_.SubInstance; SubDb = $_.SubDb; SubType = $_.SubType; Status = $_.Status; StatusText = $_.StatusText
                Health = $_.Health; AgentStatus = $_.AgentStatus; Job = $_.Job; Latency = $_.Latency; LastSync = $_.LastSync; Pending = $_.Pending
                Fails = $_.Fails; Problem = $_.Problem; Message = $_.Message; Tables = $_.Tables }
})
$jsonArticles = @($articles | ForEach-Object { [ordered]@{ PubKey = $_.PubKey; PubServer = $_.PubServer; PubDb = $_.PubDb; Publication = $_.Publication; Article = $_.Article; Source = $_.Source; Destination = $_.Destination } })
$jsonServers = @($srvRows | ForEach-Object {
    [ordered]@{ Server = $_.Server; ConnectedAs = $_.ConnectedAs; Version = $_.Version; Edition = $_.Edition; DistributionDbs = $_.DistributionDbs
                RemoteDistributor = $_.RemoteDistributor; AgRole = $_.AgRole; Aliases = $_.Aliases; Publications = $_.Publications
                Error = $_.Error; Failed = $failed.ContainsKey($_.Server) }
})
$jsonAgs = @($ags.Values | ForEach-Object { [ordered]@{ Name = $_.Name; Listeners = @($_.Listeners); Replicas = $_.Replicas; Databases = $_.DbNames.ToArray(); Primary = $_.Primary } })
$topologyJson = ConvertTo-JsonText ([ordered]@{
    generated = $generated.ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture); version = $scriptVersion; servers = $jsonServers; edges = $jsonEdges
    articles = $jsonArticles; ags = $jsonAgs; findings = $findings.ToArray()
})
[IO.File]::WriteAllText((Join-Path $OutputDir 'topology.json'), $topologyJson, $utf8)

# --- HTML ---
function Get-Badge([string]$Level) {
    if (-not $Level) { return '' }
    return "<span class=""lv lv-$Level"">$Level</span>"
}
function Get-Td($Value, [string]$Class = '') {
    $c = ''
    if ($Class) { $c = " class=""$Class""" }
    return "<td$c>$(Enc-Html ([string]$Value))</td>"
}
function New-Tr([string[]]$Cells, [string]$Class, [string]$Search) {
    $c = ''
    if ($Class) { $c = " class=""$Class""" }
    return "<tr$c data-s=""$(Enc-Html $Search.ToLowerInvariant())"">$($Cells -join '')</tr>"
}
$tocItems = New-Object System.Collections.Generic.List[string]
function New-Section([string]$Id, [string]$Title, [string[]]$Headers, $Rows, [string]$Intro = '') {
    $th = (@($Headers | ForEach-Object { "<th>$(Enc-Html $_)</th>" }) -join '')
    $tocItems.Add("<a href=""#$Id"">$(Enc-Html $Title)</a>")
    return "<section id=""$Id""><h2>$(Enc-Html $Title)</h2>$Intro<div class=""tblwrap""><table><thead><tr>$th</tr></thead><tbody>`n$(@($Rows) -join "`n")`n</tbody></table></div></section>"
}
$sections = New-Object System.Collections.Generic.List[string]
$sevOrder = @{ error = 0; warn = 1; info = 2 }

$fRows = @(foreach ($f in ($findings | Sort-Object { $sevOrder[$_.Severity] }, Category, Server)) {
    New-Tr @("<td>$(Get-Badge $f.Severity)</td>", (Get-Td $f.Category), (Get-Td $f.Server), (Get-Td $f.Object), (Get-Td $f.Finding 'msg'), (Get-Td $f.Recommendation 'msg')) '' "$($f.Severity) $($f.Category) $($f.Server) $($f.Object) $($f.Finding)"
})
if (-not $fRows) { $fRows = @('<tr><td colspan="6">Nothing found.</td></tr>') }
$fCount = @{}
foreach ($s in 'error', 'warn', 'info') { $fCount[$s] = @($findings | Where-Object { $_.Severity -eq $s }).Count }
$sections.Add((New-Section 'findings' "Findings ($($fCount.error) errors, $($fCount.warn) warnings, $($fCount.info) info)" @('Severity', 'Category', 'Server', 'Object', 'Finding', 'Recommendation') $fRows))

if ($CompareTo) {
    $cRows = @(foreach ($c in $changes) { New-Tr @((Get-Td $c.Change), (Get-Td $c.Item), (Get-Td $c.Detail)) '' "$($c.Change) $($c.Item) $($c.Detail)" })
    if (-not $cRows) { $cRows = @('<tr><td colspan="3">No changes.</td></tr>') }
    $sections.Add((New-Section 'changes' "Changes since $prevGenerated ($($changes.Count))" @('Change', 'Item', 'Detail') $cRows))
}

$eRows = @(foreach ($e in ($edges | Sort-Object PubServer, PubDb, Publication, SubServer, SubDb)) {
    $cls = @{ error = 'bad'; warn = 'warnrow'; removed = 'gone' }[$e.Health]
    $sub = ''
    if ($e.SubServer) { $sub = "$($e.SubServer) / $($e.SubDb)" }
    $healthCell = "<td>$(Get-Badge $e.Health) $(Enc-Html $e.Problem)</td>"
    $fails = ''
    if ($null -ne $e.Fails -or $null -ne $e.Retries) { $fails = "$([int]$e.Fails) / $([int]$e.Retries)" }
    New-Tr @((Get-Td $e.Publication), (Get-Td $e.PubType), (Get-Td "$($e.PubServer) / $($e.PubDb)"), (Get-Td $sub), (Get-Td $e.SubType), (Get-Td $e.StatusText),
             $healthCell, (Get-Td $e.AgentStatus), (Get-Td $e.Job), (Get-Td $e.Latency 'num'), (Get-Td $e.LastSync), (Get-Td $e.Pending 'num'), (Get-Td $fails 'num'),
             (Get-Td $e.Tables 'num'), (Get-Td $e.Message 'msg'), (Get-Td "$($e.Distributor) / $($e.DistributionDb)"), (Get-Td $e.ChangeText)) $cls `
        "$($e.PubServer) $($e.PubInstance) $($e.PubDb) $($e.Publication) $($e.PubType) $($e.SubServer) $($e.SubInstance) $($e.SubDb) $($e.SubType) $($e.StatusText) $($e.Health) $($e.Problem) $($e.Message) $($e.Distributor) $($e.ArticleNames) $($e.ChangeText) $($e.Job)"
})
$sections.Add((New-Section 'subscriptions' "Publications and subscriptions ($(@($liveSubs).Count) subscriptions)" @('Publication', 'Type', 'Publisher / database', 'Subscriber / database', 'Subscription', 'Status', 'Health', 'Agent', 'Agent job', 'Latency (s)', 'Last sync', 'Pending', "Fails / retries ($HistoryHours h)", 'Tables', 'Last agent message', 'Distributor / database', 'Change') $eRows))

if ($rowCountRows.Count -gt 0) {
    $diffRows = @($rowCountRows | Where-Object { $_.Flag -or $_.Difference -ne 0 -or $null -eq $_.SubscriberRows })
    $rRows = @(foreach ($x in $diffRows) {
        $cls = ''
        if ($x.Flag) { $cls = 'warnrow' }
        New-Tr @((Get-Td $x.Publication), (Get-Td "$($x.Publisher) $($x.Source)"), (Get-Td $x.PublisherRows 'num'), (Get-Td "$($x.Subscriber) $($x.Destination)"), (Get-Td $x.SubscriberRows 'num'), (Get-Td $x.Difference 'num'), (Get-Td $x.Note)) $cls "$($x.Publication) $($x.Article) $($x.Publisher) $($x.Subscriber) $($x.Source) $($x.Destination)"
    })
    $same = $rowCountRows.Count - $diffRows.Count
    if (-not $rRows) { $rRows = @('<tr><td colspan="7">All compared tables have the same row count.</td></tr>') }
    $sections.Add((New-Section 'rowcounts' "Row counts publisher vs subscriber ($($diffRows.Count) different, $same equal)" @('Publication', 'Publisher table', 'Rows', 'Subscriber table', 'Rows', 'Difference', 'Note') $rRows '<p class="muted">From table metadata (sys.partitions), no data is read. Differences are flagged only when nothing is pending and the article is not filtered; all rows are in rowcounts.csv.</p>'))
}

if ($lineage.Count -gt 0) {
    $lRows = @(foreach ($x in ($lineage | Sort-Object Table, Path)) { New-Tr @((Get-Td $x.Table), (Get-Td $x.Hops 'num'), (Get-Td $x.Path 'msg')) '' "$($x.Path)" })
    $sections.Add((New-Section 'lineage' "Table lineage through republishing ($($lineage.Count))" @('Source table', 'Hops', 'Path') $lRows))
}

if ($logReaderRows.Count -gt 0) {
    $lrRows = @(foreach ($x in $logReaderRows) {
        $cls = @{ error = 'bad'; warn = 'warnrow' }[$x.Health]
        New-Tr @((Get-Td "$($x.Publisher) / $($x.PubDb)"), "<td>$(Get-Badge $x.Health)</td>", (Get-Td $x.Status), (Get-Td $x.Job), (Get-Td $x.LastRun), (Get-Td "$([int]$x.Fails) / $([int]$x.Retries)" 'num'), (Get-Td $x.MaxLatencySec 'num'), (Get-Td $x.Message 'msg'), (Get-Td $x.Distributor)) $cls "$($x.Publisher) $($x.PubDb) $($x.Status) $($x.Message)"
    })
    $sections.Add((New-Section 'logreaders' "Log Reader agents ($($logReaderRows.Count))" @('Published database', 'Health', 'Last status', 'Agent job', 'Last run', "Fails / retries ($HistoryHours h)", "Max latency (s, $HistoryHours h)", 'Last message', 'Distributor') $lrRows))
}

if ($distRows.Count -gt 0) {
    $dRows = @(foreach ($x in $distRows) {
        $logText = [string]$x.LogMb
        if ($null -ne $x.LogUsedPct) { $logText += " ($($x.LogUsedPct)%)" }
        New-Tr @((Get-Td "$($x.Server) / $($x.Database)"), (Get-Td $x.DataMb 'num'), (Get-Td $logText 'num'), (Get-Td $x.Commands 'num'), (Get-Td $x.Transactions 'num'), (Get-Td $x.OldestCommand), (Get-Td $x.RetentionHours), (Get-Td $x.HistoryHours 'num'), (Get-Td $x.Cleanup), (Get-Td $x.MasterKey)) '' "$($x.Server) $($x.Database)"
    })
    $sections.Add((New-Section 'distribution' 'Distribution databases' @('Distributor / database', 'Data MB', 'Log MB', 'Commands', 'Transactions', 'Oldest command', 'Retention min-max (h)', 'History (h)', 'Clean up job', 'Master key') $dRows))
}

if ($ags.Count -gt 0) {
    $aRows = @(foreach ($ag in ($ags.Values | Sort-Object Name)) {
        $lst = (@(foreach ($l in $ag.Listeners) { if ($ag.ListenerPorts.ContainsKey($l)) { "$l,$($ag.ListenerPorts[$l])" } else { $l } }) -join ', ')
        $reps = (@(foreach ($k in $ag.Replicas.Keys) { $role = $ag.Replicas[$k]; if ($role) { "$k ($role)" } else { $k } }) -join ', ')
        New-Tr @((Get-Td $ag.Name), (Get-Td $lst), (Get-Td $reps), (Get-Td ($ag.DbNames -join ', ') 'msg')) '' "$($ag.Name) $lst $reps $($ag.DbNames -join ' ')"
    })
    $sections.Add((New-Section 'ags' "Availability groups ($($ags.Count))" @('Availability group', 'Listener', 'Replicas', 'Databases') $aRows '<p class="muted">Databases of an availability group are drawn under the listener, so a failover does not change the picture.</p>'))
}

$artRows = @(foreach ($a in ($articles | Sort-Object PubServer, PubDb, Publication, Article)) {
    $chg = ''
    if ($a.Change) { $chg = 'New' }
    New-Tr @((Get-Td "$($a.PubServer) / $($a.PubDb)"), (Get-Td $a.Publication), (Get-Td $a.Article), (Get-Td $a.Source), (Get-Td $a.Destination), (Get-Td $a.RowFilter), (Get-Td $a.ExcludedColumns), (Get-Td $chg)) '' "$($a.PubServer) $($a.PubDb) $($a.Publication) $($a.Article) $($a.Source) $($a.Destination)"
})
$sections.Add((New-Section 'articles' "Articles ($(@($articles).Count))" @('Publisher / database', 'Publication', 'Article', 'Source', 'Destination', 'Row filter', 'Columns not published', 'Change') $artRows))

$sRows = @(foreach ($s in $srvRows) {
    $cls = ''
    if ($s.Error) { $cls = 'bad' }
    $sa = ''
    if ($null -ne $s.Sysadmin -and [string]$s.Sysadmin -ne '') { $sa = 'no'; if ($s.Sysadmin) { $sa = 'yes' } }
    New-Tr @((Get-Td $s.Server), (Get-Td $s.ConnectedAs), (Get-Td "$(Get-SqlYear $s.Version) $($s.Version)"), (Get-Td $s.Edition), (Get-Td $s.Login), (Get-Td $sa), (Get-Td $s.Port 'num'),
             (Get-Td $s.AgentService), (Get-Td $s.DistributionDbs), (Get-Td $s.RemoteDistributor), (Get-Td $s.AgRole), (Get-Td $s.Aliases), (Get-Td $s.Publications 'num'),
             (Get-Td $s.Support), (Get-Td $s.UpgradeLimit 'msg'), (Get-Td $s.Error 'msg')) $cls "$($s.Server) $($s.ConnectedAs) $($s.DistributionDbs) $($s.AgRole) $($s.Aliases) $($s.Error)"
})
$sections.Add((New-Section 'servers' "Servers ($(@($srvRows).Count))" @('Server', 'Connected as', 'Version', 'Edition', 'Login', 'sysadmin', 'Port', 'SQL Agent', 'Distribution DBs', 'Remote distributor', 'AG', 'Other names', 'Publications', 'Support', 'Upgrade limit', 'Error') $sRows))

$tRows = @(foreach ($c in $connRows) {
    $cls = ''
    if ($c.Status -ne 'OK') { $cls = 'bad' }
    New-Tr @((Get-Td $c.Entry), (Get-Td $c.Status), (Get-Td $c.Server), (Get-Td $c.Version), (Get-Td $c.Port 'num'), (Get-Td $c.Login), (Get-Td $c.Ms 'num'), (Get-Td "$($c.Note)$($c.Error)" 'msg')) $cls "$($c.Entry) $($c.Status) $($c.Server) $($c.Error)"
})
$sections.Add((New-Section 'connections' "Connection test ($authText)" @('Entry', 'Result', 'Server', 'Version', 'Port', 'Login', 'ms', 'Note / reason') $tRows))

$pubCount  = @($liveEdges | Select-Object -ExpandProperty PubKey -Unique).Count
$distCount = @($serverInfo.Values | Where-Object { $_.DistributionDbs }).Count
$summary = "Servers visited: $($serverInfo.Count) · unreachable: $($failed.Count) · distributors: $distCount · publications: $pubCount · subscriptions: $(@($liveSubs).Count)"
if (-not $NoHealth) {
    $hc = @{}; foreach ($l in 'ok', 'warn', 'error', 'unknown') { $hc[$l] = @($liveSubs | Where-Object { $_.Health -eq $l }).Count }
    $summary += " · health: $($hc.ok) OK, $($hc.warn) warning, $($hc.error) error"
    if ($hc.unknown) { $summary += ", $($hc.unknown) no data" }
}
$summary += " · findings: $($fCount.error) errors, $($fCount.warn) warnings"
if ($CompareTo) { $summary += " · changes: $($changes.Count)" }
$summary += " · generated: $($generated.ToString('yyyy-MM-dd HH:mm')) · $authText"

$pageH = @{ A4 = 210; A3 = 297; A2 = 420 }[$PaperSize]
$pageData = ConvertTo-JsonText ([ordered]@{
    direction = $Direction; perServer = [bool]$PdfPerServer
    servers = @($gServers.Values | ForEach-Object { [ordered]@{ name = $_.name; title = $_.mmdTitle; css = $_.css } })
    nodes = @($gNodes.Values | ForEach-Object { [ordered]@{ id = $_.id; srv = $_.srv; db = $_.db; kind = $_.kind; mmd = $_.mmd; s = $_.s } })
    links = @($gLinks | ForEach-Object { [ordered]@{ kind = $_.kind; a = $_.a; b = $_.b; mmd = $_.mmd; css = $_.css; s = $_.s } })
})

$html = @'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SQL Server Replication Topology</title>
<style>
  :root { --bg:#fafafa; --fg:#1d1d1f; --muted:#666; --line:#ddd; --card:#fff; --bad:#c0392b; --warn:#b35c00; }
  * { box-sizing:border-box; }
  body { margin:0; font:14px/1.45 "Segoe UI", system-ui, sans-serif; background:var(--bg); color:var(--fg); }
  header { padding:16px 20px; border-bottom:1px solid var(--line); background:var(--card); }
  h1 { margin:0 0 4px; font-size:20px; }
  .muted { color:var(--muted); }
  nav.toc { margin-top:6px; font-size:13px; }
  nav.toc a { margin-right:12px; color:#1e5aa8; text-decoration:none; }
  .bar { display:flex; gap:8px; flex-wrap:wrap; align-items:center; padding:10px 20px; }
  button, input { font:inherit; padding:5px 10px; border:1px solid var(--line); border-radius:6px; background:var(--card); cursor:pointer; }
  input { cursor:text; min-width:280px; flex:1 1 280px; max-width:480px; }
  #focus { margin:0 20px 8px; padding:6px 10px; border:1px solid #1e88e5; border-radius:6px; background:#e3f2fd; display:none; }
  #focus button { margin-left:8px; padding:2px 8px; }
  #wrap { margin:0 20px; height:70vh; overflow:auto; border:1px solid var(--line); border-radius:8px; background:var(--card); }
  #diagram { transform-origin:0 0; padding:16px; display:inline-block; }
  #diagram g.node, #diagram g.cluster { cursor:pointer; }
  .legend { padding:8px 20px; font-size:13px; color:var(--muted); }
  .legend b { color:var(--fg); }
  .sw { display:inline-block; width:22px; height:0; border-top:3px solid; vertical-align:middle; margin-right:3px; }
  section { padding:12px 20px 4px; }
  h2 { font-size:16px; margin:12px 0 8px; }
  h3 { font-size:14px; margin:16px 0 6px; }
  table { border-collapse:collapse; width:100%; background:var(--card); font-size:12.5px; }
  th, td { border:1px solid var(--line); padding:3px 6px; text-align:left; vertical-align:top; }
  th { background:#f0f0f0; position:sticky; top:0; }
  td.num { text-align:right; white-space:nowrap; }
  td.msg { max-width:420px; }
  tr.bad td { color:var(--bad); }
  tr.warnrow td { color:var(--warn); }
  tr.gone td { color:#999; text-decoration:line-through; }
  .lv { display:inline-block; padding:0 6px; border-radius:8px; font-size:11px; color:#fff; text-decoration:none; }
  .lv-ok { background:#2e7d32; } .lv-warn { background:#e67e22; } .lv-error { background:#c0392b; }
  .lv-unknown { background:#888; } .lv-removed { background:#9e9e9e; } .lv-info { background:#1e88e5; }
  .tblwrap { max-height:50vh; overflow:auto; }
  #err { color:var(--bad); padding:0 20px; white-space:pre-wrap; }
  .ps { margin:0 0 12px; border:1px solid var(--line); border-radius:8px; background:var(--card); padding:8px 12px; overflow:auto; }
  @page { size: {{PAGESIZE}} landscape; margin: 10mm; }
  @media print {
    body { background:#fff; }
    .bar, .noprint, nav.toc, #focus { display:none !important; }
    #wrap { height:auto; overflow:visible; border:0; margin:0; }
    #diagram { transform:none !important; padding:0; display:block; }
    #diagram svg { width:100% !important; max-width:100% !important; height:auto !important; max-height:{{SVGMAXH}}mm; }
    .ps { border:0; padding:0; break-before:page; break-inside:avoid; overflow:visible; }
    .ps h3 { margin:0 0 4mm; break-after:avoid; }
    .ps svg { width:100% !important; max-width:100% !important; height:auto !important; max-height:{{PSMAXH}}mm; }
    .tblwrap { max-height:none; overflow:visible; }
    th { position:static; }
    tr { break-inside:avoid; }
    section { break-before:page; }
    section.flow { break-before:auto; }
    table { font-size:10px; }
    td.msg { min-width:60mm; }
  }
</style>
</head>
<body>
<header>
  <h1>SQL Server Replication Topology</h1>
  <div class="muted">{{SUMMARY}}</div>
  <nav class="toc">{{TOC}}</nav>
</header>
<div class="bar">
  <input id="filter" placeholder="Filter diagram and tables (server, database, publication, table, error)…" oninput="onFilter()">
  <button onclick="zoom(1.25)">Zoom in +</button>
  <button onclick="zoom(0.8)">Zoom out −</button>
  <button onclick="zoom(0)">100%</button>
  <button onclick="setDir('LR')">Horizontal</button>
  <button onclick="setDir('TB')">Vertical</button>
  <button onclick="saveSvg()">Download SVG</button>
  <button onclick="saveMmd()">Download .mmd</button>
  <button onclick="window.print()">Print / PDF</button>
</div>
<div id="focus"><span id="focusText"></span><button id="focusDir" onclick="flipFocus()">Show upstream</button><button onclick="clearFocus()">Clear</button></div>
<div id="err"></div>
<div id="wrap"><div id="diagram">Drawing…</div></div>
<div class="legend">
  <b>Frame</b> = server (yellow = distributor, blue = availability group listener, red = no connection, grey = not queried) ·
  <b>cylinder</b> = database · <b>hexagon</b> = distribution database ·
  <b>—&gt;</b> transactional · <b>- -&gt;</b> snapshot · <b>&lt;—&gt;</b> merge · <b>&lt;==&gt;</b> P2P ·
  health: <span class="sw" style="border-color:#2e7d32"></span>OK <span class="sw" style="border-color:#e67e22"></span>warning
  <span class="sw" style="border-color:#c0392b"></span>error <span class="sw" style="border-color:#333"></span>no data
  <span class="sw" style="border-color:#9e9e9e;border-top-style:dashed"></span>removed · thick line = new ·
  <b>click</b> a database or a server to see what depends on it
</div>
<section id="persrv" class="flow" style="display:none">
  <h2 class="noprint">Diagrams per server</h2>
  <div id="persrvList"></div>
</section>
{{SECTIONS}}
<p class="muted" style="padding:0 20px 20px">The diagram is drawn by the Mermaid library: embedded in this file (when mermaid.min.js was next to the script), from mermaid.min.js next to this page, or from the internet. Without it use topology.dot (Graphviz) or topology.mmd.</p>

<script type="application/json" id="data">{{DATA}}</script>
{{MERMAIDLIB}}
<script>
  var D = JSON.parse(document.getElementById('data').textContent);
  var N = {};
  D.nodes.forEach(function (n) { N[n.id] = n; });
  var dir = D.direction, scale = 1, query = '', lastText = '', timer = null, seq = 0, focus = null, frames = [];

  // Nodes and links to draw: everything, links matching the filter text, or links of one server
  function select(q, srv) {
    if (!q && !srv) return { nodes: D.nodes, links: D.links };
    var inc = {}, links = [];
    D.links.forEach(function (l) {
      if (l.kind !== 'repl') return;
      var a = N[l.a], b = N[l.b];
      var ok = srv ? (a.srv === srv || b.srv === srv)
                   : (l.s.indexOf(q) >= 0 || a.s.indexOf(q) >= 0 || b.s.indexOf(q) >= 0);
      if (ok) { links.push(l); inc[l.a] = inc[l.b] = true; }
    });
    D.nodes.forEach(function (n) {
      if (n.kind !== 'dist' && (srv ? n.srv === srv : n.s.indexOf(q) >= 0)) inc[n.id] = true;
    });
    D.links.forEach(function (l) {
      if (l.kind === 'dist' && inc[l.a]) { links.push(l); inc[l.b] = true; }
    });
    return { nodes: D.nodes.filter(function (n) { return inc[n.id]; }), links: links };
  }
  // Impact: everything that receives data from the start nodes (or, upstream, what feeds them)
  function impact(start, up) {
    var inc = {}, links = [], queue = start.slice(), seen = {};
    start.forEach(function (id) { inc[id] = true; });
    start.forEach(function (id) {
      if (N[id].kind === 'dist') D.links.forEach(function (l) { if (l.kind === 'dist' && l.b === id) { inc[l.a] = true; queue.push(l.a); } });
    });
    while (queue.length) {
      var id = queue.shift();
      if (seen[id]) continue;
      seen[id] = true;
      D.links.forEach(function (l) {
        if (l.kind !== 'repl') return;
        var from = up ? l.b : l.a, to = up ? l.a : l.b;
        if (from === id) { if (links.indexOf(l) < 0) links.push(l); inc[to] = true; queue.push(to); }
      });
    }
    D.links.forEach(function (l) { if (l.kind === 'dist' && inc[l.a]) { links.push(l); inc[l.b] = true; } });
    return { nodes: D.nodes.filter(function (n) { return inc[n.id]; }), links: links };
  }
  // Same layout rules as Build-Mermaid in the PowerShell script
  function build(sel, track) {
    var out = ['flowchart ' + dir], styles = [], si = 0, byCss = {}, order = [];
    if (track) frames = [];
    D.servers.forEach(function (s) {
      var ns = sel.nodes.filter(function (n) { return n.srv === s.name; });
      if (!ns.length) return;
      si++;
      if (track) frames[si] = s.name;
      out.push('  subgraph s' + si + '["' + s.title + '"]', '    w' + si + '["' + s.title + '"]:::sp');
      ns.forEach(function (n) { out.push('    ' + n.mmd); });
      out.push('  end');
      if (s.css) styles.push('  style s' + si + ' ' + s.css);
    });
    sel.links.forEach(function (l, i) {
      out.push('  ' + l.mmd);
      if (!byCss[l.css]) { byCss[l.css] = []; order.push(l.css); }
      byCss[l.css].push(i);
    });
    out = out.concat(styles);
    order.forEach(function (c) { out.push('  linkStyle ' + byCss[c].join(',') + ' ' + c); });
    out.push('  classDef sp fill:none,stroke:none,color:transparent');
    return out.join('\n');
  }
  async function render(el, text) {
    var res = await mermaid.render('g' + (++seq), text);
    el.innerHTML = res.svg;
  }
  function attachClicks(el) {
    el.querySelectorAll('g.node').forEach(function (g) {
      var m = /flowchart-(n\d+)-/.exec(g.id || '');
      if (m && N[m[1]]) g.addEventListener('click', function (ev) { ev.stopPropagation(); setFocus([m[1]], N[m[1]].srv + ' / ' + N[m[1]].db); });
    });
    el.querySelectorAll('g.cluster').forEach(function (g) {
      var m = /(?:^|-)s(\d+)$/.exec(g.id || '');
      if (m && frames[+m[1]]) g.addEventListener('click', function () {
        var srv = frames[+m[1]];
        setFocus(D.nodes.filter(function (n) { return n.srv === srv; }).map(function (n) { return n.id; }), srv);
      });
    });
  }
  async function draw() {
    var el = document.getElementById('diagram');
    var sel = focus ? impact(focus.start, focus.up) : select(query, null);
    if (!sel.nodes.length) { el.textContent = 'Nothing matches the filter.'; lastText = ''; return; }
    lastText = build(sel, true);
    try {
      await render(el, lastText);
      attachClicks(el);
      document.getElementById('err').textContent = '';
    } catch (e) {
      el.textContent = '';
      document.getElementById('err').textContent = 'Could not draw the diagram: ' + e + '\nUse topology.dot (Graphviz).';
    }
    if (focus) {
      var subs = sel.links.filter(function (l) { return l.kind === 'repl'; }).length;
      var srvs = {}; sel.nodes.forEach(function (n) { srvs[n.srv] = true; });
      document.getElementById('focusText').textContent = (focus.up ? 'Feeds ' : 'Depends on ') + focus.label + ': ' + subs + ' replication link(s), ' + Object.keys(srvs).length + ' server(s)';
      document.getElementById('focusDir').textContent = focus.up ? 'Show downstream' : 'Show upstream';
    }
  }
  function setFocus(ids, label) { focus = { start: ids, up: false, label: label }; document.getElementById('focus').style.display = 'block'; draw(); }
  function flipFocus() { if (focus) { focus.up = !focus.up; draw(); } }
  function clearFocus() { focus = null; document.getElementById('focus').style.display = 'none'; draw(); }
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && focus) clearFocus(); });
  async function drawPerServer() {
    if (!D.perServer) return;
    var list = document.getElementById('persrvList');
    document.getElementById('persrv').style.display = '';
    for (var i = 0; i < D.servers.length; i++) {
      var s = D.servers[i];
      var sel = select(null, s.name);
      if (!sel.links.length) continue;
      var box = document.createElement('div'); box.className = 'ps';
      var h = document.createElement('h3'); h.textContent = s.name; box.appendChild(h);
      var d = document.createElement('div'); box.appendChild(d);
      list.appendChild(box);
      try { await render(d, build(sel, false)); } catch (e) { d.textContent = 'Could not draw: ' + e; }
    }
  }
  function setDir(d) { dir = d; draw(); }
  function zoom(f) { scale = f === 0 ? 1 : scale * f; document.getElementById('diagram').style.transform = 'scale(' + scale + ')'; }
  function onFilter() {
    query = document.getElementById('filter').value.trim().toLowerCase();
    document.querySelectorAll('tr[data-s]').forEach(function (tr) {
      tr.style.display = !query || tr.getAttribute('data-s').indexOf(query) >= 0 ? '' : 'none';
    });
    clearTimeout(timer);
    timer = setTimeout(draw, 300);
  }
  function download(name, type, text) {
    var a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([text], { type: type })); a.download = name; a.click();
  }
  function saveSvg() {
    var svg = document.querySelector('#diagram svg');
    if (svg) download('replication-topology.svg', 'image/svg+xml', svg.outerHTML);
  }
  function saveMmd() { if (lastText) download('replication-topology.mmd', 'text/plain', lastText); }

  // Mermaid: embedded; if missing - file next to the page, then the CDNs in turn
  var libs = ['mermaid.min.js',
              'https://cdn.jsdelivr.net/npm/mermaid@11.17.2/dist/mermaid.min.js',
              'https://unpkg.com/mermaid@11.17.2/dist/mermaid.min.js',
              'https://cdnjs.cloudflare.com/ajax/libs/mermaid/11.17.2/mermaid.min.js'];
  function start() {
    if (window.mermaid) {
      mermaid.initialize({ startOnLoad: false, maxTextSize: 5000000, maxEdges: 20000, securityLevel: 'strict',
                           flowchart: { htmlLabels: true, useMaxWidth: false, curve: 'basis' } });
      draw().then(drawPerServer);
      return;
    }
    var url = libs.shift();
    if (!url) {
      document.getElementById('diagram').textContent = 'Mermaid library not available: it was not embedded, there is no mermaid.min.js next to this page and the internet (CDN) is unreachable. ' +
        'Copy mermaid.min.js next to Get-ReplTopology.ps1 and run the script again (or next to topology.html). You can also use topology.dot or topology.mmd.';
      return;
    }
    var s = document.createElement('script');
    s.src = url; s.onload = start; s.onerror = start;
    document.head.appendChild(s);
  }
  start();
</script>
</body>
</html>
'@

$html = $html.Replace('{{SUMMARY}}', (Enc-Html $summary)).
              Replace('{{PAGESIZE}}', $PaperSize).
              Replace('{{SVGMAXH}}', [string]($pageH - 65)).
              Replace('{{PSMAXH}}', [string]($pageH - 50)).
              Replace('{{TOC}}', ($tocItems -join ''))
# Sections, data and library last, so their content does not go through the other replacements
$html = $html.Replace('{{SECTIONS}}', ($sections -join "`n"))
$html = $html.Replace('{{DATA}}', $pageData)
$libTag = ''
if ($MermaidJs -and (Test-Path -LiteralPath $MermaidJs -PathType Leaf)) {
    $lib = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $MermaidJs).ProviderPath)
    $libTag = '<script>' + ($lib -replace '</script', '<\/script') + '</script>'
    Write-Host "Mermaid embedded in HTML ($MermaidJs) - the diagram works without internet." -ForegroundColor DarkGray
} else {
    Write-Warning "$MermaidJs not found - topology.html will load Mermaid from the internet. Offline: put mermaid.min.js next to the script."
}
$html = $html.Replace('{{MERMAIDLIB}}', $libTag)
$htmlPath = Join-Path $OutputDir 'topology.html'
[IO.File]::WriteAllText($htmlPath, $html, $utf8)

# PDF: the same page printed by headless Edge/Chrome (the diagram is drawn by JavaScript)
if (-not $NoPdf) {
    if (-not $BrowserPath) {
        $cands = @()
        foreach ($base in @(${env:ProgramFiles(x86)}, $env:ProgramFiles, $env:LOCALAPPDATA)) {
            if ($base) {
                $cands += Join-Path $base 'Microsoft\Edge\Application\msedge.exe'
                $cands += Join-Path $base 'Google\Chrome\Application\chrome.exe'
            }
        }
        $cands += @(Get-Command msedge, chrome, google-chrome, chromium -ErrorAction SilentlyContinue | ForEach-Object Source)
        $BrowserPath = $cands | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
    }
    $outFull = (Resolve-Path -LiteralPath $OutputDir).ProviderPath
    $pdfPath = Join-Path $outFull 'topology.pdf'
    if (-not $BrowserPath) {
        Write-Warning "Edge/Chrome not found - topology.pdf skipped. Use -BrowserPath, or open topology.html and click 'Print / PDF'."
    } else {
        # Separate profile, so a running Edge/Chrome does not take over the job
        $profileDir = Join-Path ([IO.Path]::GetTempPath()) ('ReplTopologyPdf_' + [guid]::NewGuid().ToString('N'))
        $htmlUri = (New-Object UriBuilder -Property @{ Scheme = 'file'; Host = ''; Path = (Join-Path $outFull 'topology.html') }).Uri.AbsoluteUri
        $budget = 20000
        if ($PdfPerServer) { $budget = 60000 }
        $pdfArgs = @('--headless', '--disable-gpu', '--no-first-run', '--no-pdf-header-footer', '--print-to-pdf-no-header',
                     '--disable-extensions', '--disable-background-networking', '--disable-component-update',
                     '--no-default-browser-check', '--disable-sync', '--log-level=3', "--virtual-time-budget=$budget",
                     "--user-data-dir=`"$profileDir`"", "--print-to-pdf=`"$pdfPath`"", $htmlUri)
        if (Test-Path -LiteralPath $pdfPath) { Remove-Item -LiteralPath $pdfPath -Force }
        $proc = $null
        $logOut = "$profileDir.out.log"; $logErr = "$profileDir.err.log"
        Write-Host "Creating PDF (headless $([IO.Path]::GetFileName($BrowserPath)), may take up to ~30 s)..." -ForegroundColor DarkGray
        try {
            # Browser console noise goes to temp logs, not to the screen
            $proc = Start-Process -FilePath $BrowserPath -ArgumentList $pdfArgs -Wait -PassThru `
                -RedirectStandardOutput $logOut -RedirectStandardError $logErr
        } catch {
            Write-Warning "PDF: cannot start $BrowserPath : $($_.Exception.Message)"
        }
        Remove-Item -LiteralPath $profileDir -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path -LiteralPath $pdfPath) -and (Test-Path -LiteralPath $logErr)) {
            Get-Content -LiteralPath $logErr -Tail 5 | ForEach-Object { Write-Verbose "  browser: $_" }
        }
        Remove-Item -LiteralPath $logOut, $logErr -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $pdfPath) {
            Write-Host "PDF: $pdfPath" -ForegroundColor DarkGray
        } elseif ($proc) {
            Write-Warning "PDF was not created (exit code $($proc.ExitCode)). Open topology.html and click 'Print / PDF'."
        }
    }
}

Write-Host ''
Write-Host $summary -ForegroundColor Green
$top = @($findings | Where-Object { $_.Severity -ne 'info' } | Sort-Object { $sevOrder[$_.Severity] }, Category)
foreach ($f in ($top | Select-Object -First 25)) {
    $col = 'Yellow'
    if ($f.Severity -eq 'error') { $col = 'Red' }
    Write-Host ("  {0,-5} {1,-11} {2}: {3}" -f $f.Severity.ToUpper(), $f.Category, $f.Object, $f.Finding) -ForegroundColor $col
}
if ($top.Count -gt 25) { Write-Host "  ... and $($top.Count - 25) more (see findings.csv)" -ForegroundColor Yellow }
if ($CompareTo) {
    Write-Host "Changes since $prevGenerated : $($changes.Count)" -ForegroundColor Cyan
    foreach ($c in ($changes | Select-Object -First 20)) { Write-Host "  $($c.Change): $($c.Item) $($c.Detail)" -ForegroundColor Cyan }
}
$aiM = New-AiMasker
Add-AiKnownNames $aiM
$ai = New-Object System.Collections.Generic.List[string]
$ai.Add('# SQL Server replication - report for an AI assistant'); $ai.Add('')
foreach ($x in $aiQuestion) { $ai.Add($x) }
$ai.Add(''); $ai.Add("Collected by Get-ReplTopology.ps1 $($scriptVersion): $summary"); $ai.Add('')
$ai.Add('## Problems')
if (-not $repProblems.Count) { $ai.Add('None - every subscription and Log Reader is OK.') }
foreach ($P in $repProblems) {
    $ai.Add("- **$($P.Label)** - $($P.Level): $($P.Problem)")
    $ai.Add("  - agent status: $($P.Status); agent job: $($P.Job)")
    if ($P.Msg) { $ai.Add("  - last message: $(($P.Msg -replace '\s+', ' ').Trim())") }
}
$ai.Add(''); $ai.Add('## Findings')
foreach ($f in ($findings | Where-Object { $_.Severity -in 'error', 'warn' })) { $ai.Add("- [$($f.Severity)] $($f.Category) - $($f.Server) $($f.Object): $($f.Finding)") }
$ai.Add(''); $ai.Add('## Availability groups')
foreach ($ag in $ags.Values) {
    $reps = @(foreach ($r in @($ag.Replicas.Keys)) { "$r ($($ag.Replicas[$r]))" }) -join ', '
    $ai.Add("- AG $($ag.Name): listener $($ag.Listeners -join ', '); replicas $reps; databases $($ag.DbNames -join ', ')")
}
$ai.Add(''); $ai.Add('## Servers')
foreach ($s in ($serverInfo.Values | Sort-Object Server)) { $ai.Add("- $($s.Server): $(Get-SqlYear $s.Version) $($s.Edition); distribution databases: $($s.DistributionDbs); AG role: $($s.AgRole)") }
$aiSaved = Save-AiReport ($ai -join "`n") $aiM 'ai-report'
if ($repairsFile) { Write-Host "Repairs: $($repBlocks.Count) script(s) in repairs.sql (commented out - review before running)" -ForegroundColor Cyan }
Write-Host "Report for an AI assistant: $($aiSaved.File)$(if ($aiSaved.Map) { " (names masked; tokens in $(Split-Path $aiSaved.Map -Leaf) - do not paste that one)" })" -ForegroundColor Cyan
Write-Host "Output: $OutputDir" -ForegroundColor Green
if ($failed.Count -gt 0) { Write-Host "Unreachable servers: $($failed.Keys -join ', ')" -ForegroundColor Yellow }
if (-not $NoOpen) { Invoke-Item $htmlPath }
