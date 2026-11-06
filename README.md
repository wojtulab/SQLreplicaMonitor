# Get-ReplTopology.ps1 - SQL Server replication topology and live monitor

One PowerShell script that finds every SQL Server replication relation you have (transactional,
snapshot, merge, peer-to-peer, republishing chains, Always On availability groups), checks its
health and either writes a report or watches it live.

| Mode | Start | What you get |
|---|---|---|
| **Topology report** (default) | `.\Get-ReplTopology.ps1 -Servers .\servers.txt` | HTML report with an interactive diagram, PDF, CSV/JSON, audit findings, comparison with a previous run |
| **Live monitor in the browser** | `... -Monitor` | A web page served by the script itself: status, latency, pending commands, flow, waits, blocking, AG, errors with the failing command, events, history charts |
| **Live monitor in the console** | `... -Console` | The same live data drawn in the PowerShell window, operated with the keyboard |

All three modes first run the same discovery (connection test and crawl), so the monitors know
the whole topology before they start watching it. By default the script only reads: it changes no
replication settings and no data. Writing has to be switched on: `-AllowTracerTokens` for tracer
tokens, `-AllowRepair` / `-AllowAllRepair` for repairs (section 10).

- Version 1.9 (2026-11-06), author Wojtek, first version 2017-03-14. The full version history
  is in the header of the script.
- Runs in Windows PowerShell 5.1 and PowerShell 7 without installing modules.

---

## Contents

1. [Requirements and files](#1-requirements-and-files)
2. [Quick start](#2-quick-start)
3. [Server list file](#3-server-list-file)
4. [Logging in](#4-logging-in)
5. [Permissions](#5-permissions)
6. [How the discovery works](#6-how-the-discovery-works)
7. [Mode 1 - topology report](#7-mode-1---topology-report)
8. [Mode 2 - live monitor in the browser](#8-mode-2---live-monitor-in-the-browser)
9. [Mode 3 - live monitor in the console](#9-mode-3---live-monitor-in-the-console)
10. [Repairs and reports for an AI assistant](#10-repairs-and-reports-for-an-ai-assistant)
11. [Health rules](#11-health-rules)
12. [What the monitor asks the servers](#12-what-the-monitor-asks-the-servers)
13. [Parameters](#13-parameters)
14. [Examples](#14-examples)
15. [Troubleshooting](#15-troubleshooting)

---

## 1. Requirements and files

| Item | Notes |
|---|---|
| `Get-ReplTopology.ps1` | The script (UTF-8 with BOM, keep it that way so Windows PowerShell 5.1 reads it correctly). |
| `mermaid.min.js` | Diagram library (Mermaid 11.17.2). Copy it next to the script. It is embedded in the HTML report and served by the web monitor, so nothing is loaded from the internet. Without it the report loads Mermaid from a CDN and the web monitor works without the diagram. |
| PowerShell | Windows PowerShell 5.1 or PowerShell 7.x. |
| .NET SQL client | `System.Data.SqlClient` (built in). `Microsoft.Data.SqlClient` (from the `SqlServer` module, version 22 or newer) is loaded only for `-Encrypt Strict`, `-Authentication ...` or `-SqlClient Microsoft`. |
| Edge or Chrome | Only for `topology.pdf` (headless print). Without a browser the PDF is skipped; the HTML has a Print/PDF button. |
| Console font | For `-Console`: Windows Terminal, or the classic console with a TrueType font (Consolas, Lucida Console) shows the `■ ░ ▒ ▓ █` characters. |
| `tests/` | Only for development: the Docker test bed (SQL Server 2022, availability group, replication) and the test scripts - see [tests/README.md](tests/README.md). Not needed to run the tool. |

Execution policy: if scripts are blocked, run `powershell -ExecutionPolicy Bypass -File .\Get-ReplTopology.ps1 ...`,
or unblock the downloaded file with `Unblock-File .\Get-ReplTopology.ps1`.

## 2. Quick start

```powershell
# Check the connections to every server in the list (nothing else)
.\Get-ReplTopology.ps1 -Servers .\servers.txt -TestOnly

# Report: topology, health and findings in .\ReplTopology\topology.html (+ PDF, CSV, JSON)
.\Get-ReplTopology.ps1 -Servers .\servers.txt

# Live monitor in the browser (the address with an access key is printed and opened)
.\Get-ReplTopology.ps1 -Servers .\servers.txt -Monitor

# Live monitor in this console window
.\Get-ReplTopology.ps1 -Servers .\servers.txt -Console

# Any mode with a SQL login instead of Windows authentication (asks for the password)
.\Get-ReplTopology.ps1 -Servers .\servers.txt -Console -SqlUser sa

# Find the SQL Server instances around you and pick them from a list
.\Get-ReplTopology.ps1 -Scan

# Monitor that may run the safe repairs (agents, snapshots, clean up) after a confirmation
.\Get-ReplTopology.ps1 -Servers .\servers.txt -Monitor -AllowRepair
```

A single distributor is enough as the start server: everything else is found from its
distribution databases. Starting from several servers helps when some of them cannot be reached
by name.

## 3. Server list file

`-Servers` takes server names, or a path to a text file with one entry per line. `#` starts a comment.

```text
SQL01                   # default instance, port 1433
SQL02\INST1             # named instance through SQL Browser
SQL03,50001             # non-default port
SQL04\INST2,50002       # named instance on a fixed port (no SQL Browser needed)
AGL-SALES,1450          # AG listener on a non-default port
```

The connection test comes first: name resolution, TCP port, login. Every entry gets a result
line with the real server name, port, login and sysadmin rights, or the reason it failed plus a
hint. Typical hints are a host that is not in DNS, a closed port, a named instance without
SQL Browser (add the port), a failed login, or a TLS problem. `connections.csv` keeps the
result. With `-TestOnly` the script stops after this step.

**Finding the servers.** `-Scan` lists the instances on this computer (registry and services) and
the ones SQL Browser announces in the local subnet (UDP 1434, broadcast); `-ScanHost SQL01,SQL02`
asks SQL Browser on the given hosts, also across routers. Pick the instances by number (`1,3` or
`all`); the script can save them to `servers.txt` (with the port, so later connections do not need
SQL Browser) and goes on with the chosen mode. A host without SQL Browser, or with UDP 1434 blocked,
shows nothing; AG listeners do not answer, but the script finds them from their replicas.

Ports learned along the way are reused while crawling: ports from the list, AG listener ports and
read-only routing URLs. A server that was reached on a special port is always contacted the same
way.

## 4. Logging in

| How | Parameters |
|---|---|
| Windows authentication (default) | nothing |
| SQL login, password asked once | `-SqlUser sa` |
| SQL login from a credential object | `-SqlCredential (Get-Credential)` |
| Microsoft Entra ID | `-Authentication ActiveDirectoryIntegrated` (or `...Interactive`, `...Password`, `...Default`, `...ManagedIdentity`; needs Microsoft.Data.SqlClient) |

The same login is used for every server. Encryption: `-Encrypt Optional` (default),
`Mandatory`, or `Strict` (TDS 8, needs Microsoft.Data.SqlClient). Server certificates are
trusted unless `-StrictCert` is given.

## 5. Permissions

sysadmin everywhere gives everything. With less:

| Feature | Needs |
|---|---|
| Topology: publications, subscriptions, articles, agents | `db_datareader` in every distribution database. The `replmonitor` role alone cannot read the MS* tables. |
| Agent status (`sp_replmonitorhelpsubscription`) | `replmonitor` (or `db_owner`) in the distribution database |
| Pending commands in the report (`sp_replmonitorsubscriptionpendingcmds`) | sysadmin or `db_owner` in the distribution database |
| Pending commands in the monitors (own query, same rules) | `db_datareader` in the distribution database |
| Agent jobs, profiles, retention | read access to msdb, e.g. `SQLAgentReaderRole` |
| Log usage, AG roles, SQL Server Agent state; in the monitors: sessions, blocking, waits, AG state | `VIEW SERVER STATE` (SQL Server 2022: also `VIEW SERVER PERFORMANCE STATE`) |
| AG listeners and replicas | `VIEW ANY DEFINITION` |
| AG replicas registered at the distributor (`msdb.dbo.MSdistpublishers`) | sysadmin or `SELECT` on that table at the distributor; without it the check is listed under Coverage |
| Row counts publisher vs subscriber | access to the replicated databases |
| Failing command of an error (`sp_browsereplcmds`) | sysadmin, `db_owner` or `replmonitor` in the distribution database |
| Tracer tokens (`sp_posttracertoken`) | sysadmin or `db_owner` in the publication database, and `-AllowTracerTokens` |
| Repairs: start, stop, enable agent and clean up jobs | sysadmin, or the job owner with `SQLAgentOperatorRole` in msdb |
| Repairs: snapshot, reinitialize, skip a transaction, `sp_replrestart`, `sp_repldone`, redirect | sysadmin or `db_owner` in the publication, subscription or distribution database |

Nothing fails because of a missing permission. What could not be checked is listed under
Findings (category Coverage) in the report, or as a note at the server in the monitors.

## 6. How the discovery works

1. **Connection test** of the start servers (in parallel), as described in section 3.
2. **Crawl.** Each server is read for:
   - its databases and log usage;
   - availability groups (replicas, listeners, databases);
   - replication agent jobs in msdb, and the distributor (local or remote).

   Each distribution database is read for:
   - publications, subscriptions and articles;
   - agent health (`sp_replmonitorhelpsubscription`, the procedure Replication Monitor uses), last
     agent messages and errors, failures in the last `-HistoryHours`;
   - pending commands, distribution database size and retention, AG redirections
     (`MSredirected_publishers`).

   Every publisher, subscriber and distributor found is added to the crawl, which goes on in
   waves of parallel queries (`-ThrottleLimit`).
3. **Availability groups.** Databases in an AG are drawn under the listener, not under the
   replica that happens to be primary. A failover therefore does not change the topology, and
   `-CompareTo` does not report it as a change. If the login cannot see the AG metadata, a server
   reached through a name that differs from `@@SERVERNAME` on an HADR instance is treated as a
   listener.
4. **Health beyond Replication Monitor.** The script also checks:
   - agent jobs: disabled, not running, SQL Server Agent stopped, `-SkipErrors`;
   - Log Reader health;
   - publisher log usage while the log waits for replication;
   - subscriber database missing or not online;
   - failures and retries in the last hours.
5. **Row counts** (report only, optional) of every replicated table, publisher vs subscriber,
   from metadata (`sys.partitions`). No table data is read, except with `-FilteredRowCounts`: then
   the publisher rows of a row-filtered article are counted with its WHERE (a COUNT on the table).
   The publication settings (DDL replication, row and column filters) are read in every mode.

## 7. Mode 1 - topology report

```powershell
.\Get-ReplTopology.ps1 -Servers .\servers.txt [-OutputDir C:\Repl\2026-11-06] [-CompareTo C:\Repl\2026-11-05]
```

Files in `-OutputDir` (default `.\ReplTopology`):

| File | Content |
|---|---|
| `topology.html` | Interactive diagram and all tables (opened at the end unless `-NoOpen`) |
| `topology.pdf` | The same page as PDF (Edge/Chrome headless; `-NoPdf`, `-PaperSize A4/A3/A2`, `-PdfPerServer`) |
| `topology.mmd` | Mermaid text for wikis, Azure DevOps, GitHub, draw.io |
| `topology.dot` | Graphviz: `dot -Tsvg topology.dot -o topology.svg` |
| `topology.json` | All data. Pass the folder to `-CompareTo` next time. |
| `findings.csv` | Everything worth a look, with recommendations |
| `edges.csv` | Publication-to-subscription relations with health |
| `articles.csv` | Articles (tables) per publication, with the row filter and the columns a column filter leaves out |
| `rowcounts.csv` | Row counts, publisher vs subscriber |
| `servers.csv` | Visited servers: versions, roles, support, upgrade limits, errors |
| `connections.csv` | Result of the connection test |
| `changes.csv` | Differences against `-CompareTo` (only with `-CompareTo`) |
| `repairs.sql` | Repair scripts for the problems found, every block commented out (section 10) |
| `ai-report-<time>.md` | The run as a report for an AI assistant, names masked; the tokens are in `ai-report-<time>.names.txt` |

CSV files use the list separator of the regional settings and UTF-8 with BOM, so they open
correctly in Excel.

**The diagram.**
- A frame is a server: yellow = distributor, blue = AG listener, red = no connection,
  grey = not queried.
- A cylinder is a database, a hexagon is a distribution database.
- Arrows: `-->` transactional, `-.->` snapshot, `<-->` merge, `<==>` P2P. Arrows between the
  same two databases are merged into one (`-ExpandEdges` keeps one arrow per publication).
- Line color is health: green OK, orange warning, red error, black no data, dashed grey removed;
  a thick line is new since `-CompareTo`.
- Click a database or a server to see what depends on it, and switch to see what feeds it.
- The filter box redraws the diagram and filters every table.

**Report sections:**

| Section | Content |
|---|---|
| Findings | See the categories below |
| Changes | New, removed and changed relations and articles since `-CompareTo`, including AG failovers |
| Publications and subscriptions | Status, health and problems, agent job, latency, last sync, pending commands, failures and retries, tables, last agent message, distributor |
| Row counts | Only differences that matter: nothing pending and the article not filtered (with `-FilteredRowCounts` filtered articles are compared through their filter) |
| Table lineage | Through republishing (table A -> B -> C) |
| Log Reader agents | One per published database |
| Distribution databases | Size, commands, transactions, oldest command, retention, cleanup job, master key |
| Availability groups | Listeners, replicas, databases |
| Articles | Per publication, with the row filter (WHERE) and the columns a column filter leaves out |
| Servers | Version, edition, login, sysadmin, port, SQL Agent, AG role, other names, support end, upgrade limit |
| Connection test | Result per server list entry |

Findings categories:

| Category | What it checks |
|---|---|
| Health | Subscriptions and Log Readers in error or warning |
| Versions | Version combinations that are not supported (distributor >= publisher, subscriber within the supported range), upgrade limits, end of extended support |
| Distributor | Distribution clean up job disabled, failed or not run recently; the oldest replicated command; published databases in an availability group: replicas that are not publishers at the distributor and a publisher not redirected to the listener (either one stops the Log Reader after a failover) |
| Settings | immediate_sync, shared Distribution Agents, subscriptions that never expire, schema changes not replicated (replicate_ddl = 0) |
| Security | Agents connecting as sa or with SQL logins, agent jobs without a proxy, job owners that no longer exist, no database master key in the distribution database |
| Leftovers | Databases marked as published without publications, replication jobs without an agent or subscription |
| Coverage | What could not be checked and why (permissions) |

## 8. Mode 2 - live monitor in the browser

```powershell
.\Get-ReplTopology.ps1 -Servers .\servers.txt -Monitor [-RefreshSeconds 10] [-AllowTracerTokens]
```

After the discovery the script becomes a small web server. It needs no IIS and no modules: it is
a `TcpListener` in the same PowerShell process. It prints an address such as
`http://localhost:8642/?t=3f2a...` and opens it in the default browser (`-NoOpen` skips that).
The page refreshes by itself. Stop the monitor with Ctrl+C in the PowerShell window or with the
Stop button on the page. No files are written.

**Security.**
- It listens on 127.0.0.1 by default, so only this computer can open it.
- The address contains a random access key; the API accepts the key only in a header.
- The page loads nothing from the internet and sends nothing anywhere.
- `-ListenAddress 0.0.0.0` lets other computers open it. The traffic is plain HTTP, so share
  the address with care.
- If port 8642 is taken, the next free port is used (`-Port` sets another one).

**Header.**
- Counters: subscriptions OK / warning / error, Log Readers, blocked agents, errors in the last
  hour, highest latency, total pending commands, flow in commands per second, AG problems,
  servers that do not answer.
- Controls: refresh interval, Pause/Resume, Refresh now (it also counts pending commands at
  once), Stop.

**Filters.** They act on every tab and on the diagram:
- free text (all words must match; server, database, publication, table, error text, wait type);
- quick filters: Problems, Errors, Blocked, Pending, Not running, Latency >= 30 s;
- a server list.

**Tabs:**

| Tab | Content |
|---|---|
| Overview | Diagram colored by live health. Moving dashes mean commands are being delivered (faster and thicker = more), purple dotted means blocked, the database border shows Log Reader health. Next to it: "Needs attention" and the state of every queried server with its notes, e.g. missing permissions. Click a line for details, a database or a server to filter. |
| Subscriptions | Health, status, publication, publisher -> subscriber, latency, pending commands (hover for the agent work they mean, as Replication Monitor estimates it), oldest undelivered transaction, commands/s, wait of the agent session, problems / last message, scan notes, distributor. Trends as sparklines. Click a column to sort. |
| Log Readers | Health, status, latency, commands/s, commands in the session, last activity, wait, AG state of the published database |
| Sessions & waits | Blocking chains with the head blocker (program, host, login, database, status, open transactions, SQL, object name of the lock), sessions blocked by an agent, all agent sessions (state, wait, CPU, reads/writes, SQL), waits per agent (since the monitor started and in the last interval) and per server (ms of waiting per second) |
| Availability groups | Role, mode, synchronization, send and redo queue, lag behind the primary |
| Errors | MSrepl_errors per error event, newest first: the cause (for 14151 "agent failed", the error behind it; the details an agent writes under the next id stay with their error), repeats collapsed ("repeated 12 times since ..."), what to do, the .NET stack trace folded when the agent wrote one, and a Command button that shows the replicated command that failed |
| Events | What changed while the monitor ran: health changes, blocking started/ended, new replication errors, servers lost and back, pause/resume, tracer tokens |
| Findings | The audit from the discovery (does not refresh), with a Repair column (section 10) |

**Detail.** Click a subscription or a Log Reader. A panel opens with:
- the live facts and the agent sessions with their waits, plus who blocks the agent;
- the repairs for the problem and the Report for AI button (section 10);
- history charts for 1 h to 30 days: latency (highest per interval) with the agent status strip,
  and commands per second;
- pending commands per article, and the largest pending transactions (one big transaction
  delays everything behind it);
- errors in the period with the failing command;
- agent statistics: the agents write a performance record every 5 minutes, which shows whether
  reading from the distributor or applying at the subscriber is the bottleneck;
- tracer tokens: publisher -> distributor -> subscriber times, and the Post tracer token button
  with `-AllowTracerTokens`;
- the agent messages.

Colors:

| Value | Warning | Error |
|---|---|---|
| Latency | 30 s | 300 s |
| Pending commands | `-PendingWarn` | 10 x `-PendingWarn` |
| Age of the oldest undelivered transaction | 60 s | 600 s |

The status column shows the Replication Monitor state: Running, Idle, Retrying, Failed, Stopped,
or Not running for a continuous agent whose job is not running.

## 9. Mode 3 - live monitor in the console

```powershell
.\Get-ReplTopology.ps1 -Servers .\servers.txt -Console [-SqlUser sa] [-RefreshSeconds 10] [-AllowTracerTokens]
```

The same live data as the web page, drawn in the PowerShell window. There is no web server.
- Only changed lines are rewritten, so the screen does not flicker.
- Moving the selection and scrolling reuse the prepared view, so they react at once. While you
  hold a key, new data waits a moment (at most until the next second).
- The layout adapts when the window is resized; narrow windows drop the trend, oldest pending
  and activity columns.
- The window must be at least 70 x 16 characters to start. Below 40 x 10 the monitor waits for
  the window to grow.
- Only characters of the console code pages 437/850/852 are used, so Windows PowerShell 5.1
  shows them correctly. The console colors are restored on exit, also after Ctrl+C.

```
 Replication Monitor 1.9 | SQL login 'sa' | every 5 s | 20:01:53 live        Space pause  r refresh  +/- interval  q quit
 Subscriptions 4 ok 1 warn 1 error | Log Readers 2 ok | Blocked 1 | Errors 1 h 22 | Max latency 2 s | Pending 9,618 | Flow 40.0 cmd/s
 1 Subscriptions  2 Log Readers  3 Blocking+waits  4 AG  5 Errors  6 Events  7 Servers  8 Findings   sort: health
  Health  Status      Publication   Publisher/DB -> Subscriber/DB   Latency trend      Pending   Oldest   cmd/s Activity Problem / wait
> ■ error Failed      PubOrders     SQLA/SalesA -> SQLC/MissingDb       0 s              4,889   13 min     0.0     17 s FAILED, OLDEST PENDING 13 MIN
  ■ warn  Running     PubSales      SQLA/SalesA -> AGLB/SalesB          0 s                 50     46 s     0.0    1 min blocked 42 s by session 58 (SQLCMD, SQLB1)
  ■ ok    Running     PubOrders     SQLA/SalesA -> AGLB/SalesB          2 s ░▒▓█▓▒░░       200      2 s    40.0      2 s
 Events
 20:04:27 ■ PubSales: SQLA/SalesA -> AGLB/SalesB : ok -> warn (BLOCKED 7 S ON SQLB1)
 Up/Down select | Enter detail | / filter | p quick filter | s sort | 1-8 views | Esc clear filter | Space pause | r refresh | q quit
```

Views:

| Key | View |
|---|---|
| `1` | Subscriptions (with the latest events at the bottom) |
| `2` | Log Readers |
| `3` | Blocking + waits: blocking chains (head blocker and its SQL, lock object), agent sessions, server waits (ms/s), agent waits |
| `4` | Availability groups |
| `5` | Errors (cause, repeats collapsed; Enter for the full text, the hint and the failing command) |
| `6` | Events |
| `7` | Servers (state, query time, connection string, notes about missing permissions) |
| `8` | Findings of the discovery (Enter for the recommendation) |

Keys:

| Key | In a list | In a detail |
|---|---|---|
| Up / Down, PgUp / PgDn, Home / End | move the selection | scroll |
| Enter | open the detail of the selected item | |
| Esc | clear the filter and the quick filter | back to the list (Backspace too) |
| `/` | type a filter (all words must match; Enter keeps it, Esc cancels) | |
| `p` | next quick filter: all, problems, errors, blocked, pending, not running, latency | |
| `s` | next sort (subscriptions: health, latency, pending, oldest, flow, publication, subscriber) | |
| `h` | | history period: 1 h, 6 h, 24 h, 3 d, 7 d, 30 d |
| `r` | refresh all servers now (pending commands too) | reload the detail |
| `t` | | post a tracer token (subscription detail, with `-AllowTracerTokens`) |
| `c` | | show the replicated command of the error (error detail or subscription detail) |
| `1` - `9` | | open a repair of the item; in the repair `x` runs it (with confirmation), `w` saves the .sql |
| `a` | | write the report for an AI assistant (subscription or Log Reader detail) |
| Space | pause / resume | pause / resume |
| `+` / `-` | refresh interval 5 / 10 / 15 / 30 / 60 / 120 / 300 s | same |
| `q` (or Ctrl+C) | quit | quit |

The detail of a subscription or Log Reader contains the same sections as the web panel: facts,
sessions, blocked by, waits, history (latency, commands/s and status as character strips),
pending per article, largest transactions, errors with the command, agent statistics, tracer
tokens and messages.

**Line mode.** The console view needs a real console window. It falls back to printing changes
line by line when:
- the script runs in PowerShell ISE;
- it runs in a remote session (`Enter-PSSession`);
- the output is redirected;
- the window is smaller than 70 x 16.

Line mode prints a status line whenever the counts change (and every 5 minutes), plus every
event. Keys pressed while the topology is being read are ignored.

## 10. Repairs and reports for an AI assistant

Without extra switches the script only reads. It still says what to do: every problem the
catalog knows gets a repair script, and any subscription or Log Reader can be written to a report
for an AI assistant (ChatGPT, Claude, Copilot ...).

**Levels.**

| Level | What it does | Runs in the monitors with |
|---|---|---|
| safe | Starts what should run: agent jobs, the Snapshot Agent, the distribution clean up job | `-AllowRepair`, after a confirmation |
| full | Changes data or settings: skips a transaction, reinitializes, `sp_replrestart`, `sp_repldone`, redirects a publisher | `-AllowAllRepair`, after typing a word such as `SKIP` |
| script | Needs a password or a decision: agent passwords, AG registration, tablediff | never - save it and run it in SSMS |

**The catalog.**

| Problem | Repair | Level |
|---|---|---|
| Agent job disabled or not running | Enable and start the job / start it | safe |
| Agent failed or retrying while its job runs (network break, timeout, deadlock) | Restart the job | safe |
| Subscription UNINITIALIZED | Start the Snapshot Agent (the pull agent job gets "start the job") | safe |
| Subscription inactive or expired (21074) | Reinitialize (`sp_reinitsubscription` / `sp_reinitpullsubscription`) and start a snapshot | full |
| Row not found at the subscriber (20598), duplicate key (2601, 2627) | Skip the failing transaction: stop the job, `sp_setsubscriptionxactseqno` at the subscriber, start the job | full |
| The same | Compare the table of the failing command and generate the fix (`tablediff` command line); on a filtered article a count with the filter at both sides instead - tablediff knows no filter and its fix would copy the rows and columns the filter leaves out | script |
| Log Reader cannot find its log position (sp_repldone / LSN errors, e.g. after a restore) | `sp_replrestart` between stopping and starting the Log Reader | full |
| Publisher log full, log_reuse_wait = REPLICATION | `sp_repldone` + `sp_replflush` - last resort, the subscriptions have to be reinitialized afterwards | full |
| Login failed (password changed) | New password for the push / pull agent or the Log Reader (`sp_changesubscription`, `sp_change_subscription_properties`, `sp_changelogreader_agent`) | script |
| Finding: distribution clean up job disabled, failed or not run recently | Enable and start it / run it | safe |
| Finding: AG replica not a publisher at the distributor | `sp_adddistpublisher` at the distributor; `sp_adddistributor` and the push subscribers as linked servers on the replica | script |
| Finding: publisher not redirected to the AG listener | `sp_redirect_publisher` | full |

Repairs that follow from an error appear only while the agent fails (failed, retrying, or an error
of it in the last 30 minutes) - not because of old errors of an agent that runs fine.

**Where.**
- Web page: the detail panel has a Repairs section (why, risk, T-SQL, Save .sql, Run) and the
  Report for AI button; the Findings tab has a Repair column.
- Console: the detail lists the repairs; a number opens one (the T-SQL, `w` saves it, `x` runs it),
  `a` writes the report for AI.
- Report: `repairs.sql` with a block per problem, every block commented out, so running the whole
  file changes nothing; and `ai-report-<time>.md`.

Every script names its steps with `:CONNECT <server>` (SSMS: Query > SQLCMD Mode), the reason, the
risk, how to undo it and what to check afterwards. A run in the monitor goes step by step on the
servers of the script, stops at the first error, adds events and appends to `repairs.log` in
`-OutputDir` (time, login, server, database, T-SQL, result). One repair runs at a time and nothing
runs on its own.

**Report for an AI assistant.** A Markdown file with a question for the assistant and what the
monitor knows: the item (health, status, job, latency, pending, last message), errors with their
details, the failing command, agent history and statistics, pending commands per article, tracer
tokens, agent sessions and blocking, the AG state, related findings, versions and the repairs the
tool offers. Names of servers, instances, listeners, AGs, databases, publications, tables and
replication jobs become tokens (SRV1, DB2, PUB1, TAB3 ...), values in replicated commands and
duplicate keys become their type, IP addresses and domain names disappear. The tokens are listed
in `<report>.names.txt` next to the report - keep that file, do not paste it. `-NoMask` writes the
report without masking (for an assistant your company approved).

## 11. Health rules

A subscription or Log Reader gets the worst level of its problems. The first group comes from
`sp_replmonitorhelpsubscription`, the same rules Replication Monitor uses.

| Problem | Level | Meaning |
|---|---|---|
| FAILED | error | Agent status 6 |
| RETRYING | warn | Agent status 5 |
| ERROR | error | Monitor ranking 60+ |
| PERFORMANCE CRITICAL | warn | Latency over the critical threshold of the publication |
| LATENCY n s | warn | Latency over the threshold set for the publication in Replication Monitor |
| EXPIRING | warn | The subscription is close to its retention |
| UNINITIALIZED | warn | No snapshot applied yet |
| SLOW MERGE, LOW MERGE SPEED, LONG-RUNNING MERGE | warn | Merge thresholds |
| INACTIVE | error | Subscription status 0 |

Added by this script in all modes:

| Problem | Level | Meaning |
|---|---|---|
| PENDING n | warn | Undelivered commands >= `-PendingWarn` |
| AGENT JOB DISABLED | error (continuous) / warn | The agent job is disabled |
| AGENT NOT RUNNING | warn, error with pending commands | A continuous agent whose job is not running |
| LOG READER ... | error | The Log Reader of the published database failed or does not run |
| SUBSCRIBER DB MISSING / state | error / warn | Report |
| SQL AGENT STOPPED ON server | error | Report |
| SKIPS ERRORS codes | warn | `-SkipErrors` in the agent job or profile. Report, and a note in the monitors. |
| n FAILURES / RETRIES IN h H | warn | Report, and a note in the monitors |
| PUBLISHER LOG n% (REPLICATION) | warn >= `-LogUsedWarn`, error >= 90 | The publisher log cannot be reused because of replication (report) |

Added by the monitors:

| Problem | Level | Meaning |
|---|---|---|
| OLDEST PENDING n MIN | warn >= 5 min, error >= 30 min | A continuous agent whose oldest undelivered transaction is that old. A stuck agent is caught even when SQL Server reports it as running. |
| NO PROGRESS n MIN | warn | Status running or idle, but no history entry for 10 minutes |
| BLOCKED n S ON server | warn | An agent session waits 5+ seconds for a lock; the head blocker is shown |
| AGENT JOB MISSING | warn | The agent job is not in msdb any more |
| DISTRIBUTOR NOT REACHABLE | - | No data, the distributor does not answer |
| AG SECONDARY x NOT SYNCHRONIZED | warn (Log Reader) | A synchronous secondary is not synchronized. The Log Reader reads only changes hardened on every synchronous secondary unless trace flag 1448 is on. |

Availability group replicas:
- error: DISCONNECTED, SUSPENDED, NOT SYNCHRONIZING, NOT_HEALTHY;
- warn: SYNCHRONIZING for a synchronous replica, PARTIALLY_HEALTHY, send or redo queue over 100 MB.

## 12. What the monitor asks the servers

Each server is queried on its own schedule (`-RefreshSeconds`) in a background runspace, so a
slow server does not hold the others back. Query timeout in the monitors is
`min(-QueryTimeout, 60)` seconds.

When a server does not answer, its last answer is dropped, so nothing stale stays on screen:
- the subscriptions and Log Readers of a lost distributor show `unknown` and
  `DISTRIBUTOR NOT REACHABLE`;
- the sessions, waits and AG data of a lost server disappear.

An event records the loss and the return. An unexpected problem with one answer is reported as
an event and the monitor keeps running.

Every refresh:

| Where | What |
|---|---|
| Distributors | `sp_replmonitorhelpsubscription` per publisher and publication type; the latest history entry of every Distribution Agent and Log Reader; new rows of `MSrepl_errors` and the agents they belong to |
| Every server (with `VIEW SERVER STATE`) | Replication agent sessions (recognized by program name), their blocking chains and the sessions they block; wait statistics per agent session (SQL Server 2016+) and per server; AG replica state on HADR servers |
| Servers with replication jobs | Job enabled/running from msdb |

Every `-PendingEvery`-th refresh (default every 3rd), on the distributors: the undelivered
commands of all subscriptions in one query. It applies the rules of
`sp_replmonitorsubscriptionpendingcmds` to `MSrepl_commands`, `MSsubscriptions` and
`MSrepl_transactions`, and also returns the age of the oldest undelivered transaction. It does
not cover loopback detection (bidirectional transactional) or P2P agents. On a large backlog this
is the heaviest query, so raise `-PendingEvery` if needed.

Only when you open a detail:
- the history of one agent for the chosen period;
- its errors and tracer tokens;
- pending commands per article and the largest pending transactions;
- `sp_browsereplcmds` for a failing command;
- `sp_posttracertoken` with `-AllowTracerTokens`.

Reads use `READ UNCOMMITTED`. The Replication Monitor procedure and the pending-command query use
`READ COMMITTED`, because `READPAST` needs it.

The monitor uses about 1% CPU between refreshes, with short peaks while the servers answer.

## 13. Parameters

| Parameter | Default | Mode | Meaning |
|---|---|---|---|
| `-Servers` | | all | Start servers, or a file with one entry per line (or use `-Scan`) |
| `-Scan` | off | all | Find instances on this computer and in the subnet (SQL Browser, UDP 1434) and pick them from a list |
| `-ScanHost` | | all | Ask SQL Browser on these hosts for their instances (works across subnets) |
| `-SqlUser` | | all | SQL login; the password is asked for |
| `-SqlCredential` | | all | SQL login as a PSCredential |
| `-Authentication` | Default | all | Microsoft Entra ID method |
| `-Encrypt` | Optional | all | Optional, Mandatory, Strict |
| `-StrictCert` | off | all | Validate the server certificate |
| `-SqlClient` | Auto | all | Auto, System, Microsoft |
| `-ConnectTimeout` | 10 | all | Connection timeout (s) |
| `-QueryTimeout` | 120 | all | Query timeout (s); monitors use at most 60 |
| `-ThrottleLimit` | 8 | all | Servers queried at the same time during discovery |
| `-MaxServers` | 200 | all | Upper limit of servers to visit |
| `-NoCrawl` | off | all | Only the given servers, do not follow publishers and subscribers |
| `-KeepDomain` | off | all | Keep the domain part of server names |
| `-Alias` | | all | `@{ 'IP or alias' = 'SERVER' }` - names of the same server |
| `-TestOnly` | off | report | Only the connection test |
| `-OutputDir` | `.\ReplTopology` | all | Folder for the files; the monitors write `repairs.log`, saved scripts and AI reports there |
| `-NoHealth` | off | report | Skip agent health (topology only) |
| `-NoPendingCommands` | off | report | Skip counting pending commands |
| `-NoRowCounts` | off | report | Skip row counts |
| `-FilteredRowCounts` | off | report | Count the publisher rows of row-filtered articles with their WHERE, so they are compared too (a COUNT on the publisher table) |
| `-PendingWarn` | 10000 | all | Pending commands from which a warning is raised |
| `-HistoryHours` | 24 | all | Failures and retries period; first load of errors in the monitors |
| `-LogUsedWarn` | 70 | report | Publisher log usage (%) for a warning |
| `-CompareTo` | | report | Folder or topology.json of a previous run |
| `-HideDistributors` | off | report | No distribution database hexagons on the diagram |
| `-ExpandEdges` | off | report | One arrow per publication |
| `-Direction` | LR | report, web | Diagram layout LR or TB |
| `-NoOpen` | off | report, web | Do not open the browser |
| `-NoPdf` | off | report | No PDF |
| `-PaperSize` | A4 | report | A4, A3, A2 (landscape) |
| `-PdfPerServer` | off | report | One diagram page per server |
| `-BrowserPath` | auto | report | Edge/Chrome for the PDF |
| `-MermaidJs` | next to the script | report, web | Path to mermaid.min.js |
| `-Monitor` | off | web | Live monitor in the browser |
| `-Console` | off | console | Live monitor in the console window (implies `-Monitor`) |
| `-Port` | 8642 | web | TCP port (the next free port is used when taken) |
| `-ListenAddress` | 127.0.0.1 | web | 0.0.0.0 to open the page from other computers |
| `-RefreshSeconds` | 10 | web, console | How often each server is queried (2-3600; can be changed live) |
| `-PendingEvery` | 3 | web, console | Count pending commands every N-th refresh |
| `-AllowTracerTokens` | off | web, console | Allow posting tracer tokens |
| `-AllowRepair` | off | web, console | Run the safe repairs, after a confirmation |
| `-AllowAllRepair` | off | web, console | Run all repairs except the scripts, each after typing its word (implies `-AllowRepair`) |
| `-NoMask` | off | all | Reports for an AI assistant without masking |

`Get-Help .\Get-ReplTopology.ps1 -Full` shows the same in PowerShell.

## 14. Examples

```powershell
# Report for one distributor, compared with yesterday, A3 PDF with a page per server
.\Get-ReplTopology.ps1 -Servers SQLDIST1 -OutputDir C:\Repl\2026-11-06 -CompareTo C:\Repl\2026-11-05 -PaperSize A3 -PdfPerServer

# Only the topology, fast (no health, no pending commands, no row counts)
.\Get-ReplTopology.ps1 -Servers SQLDIST1 -NoHealth -NoRowCounts -NoPdf

# Web monitor on another port, open for the team, refresh every 5 s, tracer tokens allowed
.\Get-ReplTopology.ps1 -Servers .\servers.txt -Monitor -Port 9000 -ListenAddress 0.0.0.0 -RefreshSeconds 5 -AllowTracerTokens

# Console monitor with a SQL login; pending commands counted every 5th refresh (large distributor)
.\Get-ReplTopology.ps1 -Servers .\servers.txt -Console -SqlUser sa -PendingEvery 5

# Servers known by IP: give them their names
.\Get-ReplTopology.ps1 -Servers 10.0.0.5 -Alias @{ '10.0.0.5' = 'SQLDIST1'; '10.0.0.6' = 'SQLPUB1' }
```

## 15. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `Instance not found through SQL Browser` | UDP 1434 is blocked or the instance name is wrong. Add the port: `HOST\INST,50002`. |
| `Port ... is closed or filtered` | Server down, firewall, or SQL Server listens on another port. Check the port in SQL Server Configuration Manager. |
| `TLS/certificate problem` | Use `-Encrypt Optional`, or install a trusted certificate and use `-StrictCert`. |
| Topology empty although the login works | The login has `replmonitor` but not `db_datareader` in the distribution database. |
| No sessions, blocking, waits or AG in the monitors | The login lacks `VIEW SERVER STATE`; the server note in the monitor says so. |
| Pending commands empty in the report | `sp_replmonitorsubscriptionpendingcmds` needs sysadmin or `db_owner`. The monitors count them with `db_datareader`. |
| "This window cannot draw the console monitor" | ISE, a remote session, redirected output or a window smaller than 70 x 16. Line mode is used; open a normal console or Windows Terminal. |
| Squares or question marks instead of `■ ░ ▒ ▓ █` in the console | Raster font. Switch the console font to Consolas or use Windows Terminal. |
| "Cannot listen on ... ports" | Ports 8642-8651 are taken or not allowed. Use `-Port`. |
| Diagram missing in the web monitor | `mermaid.min.js` is not next to the script (or `-MermaidJs` points elsewhere). |
| No PDF | Edge/Chrome not found. Use `-BrowserPath`, or Print/PDF in topology.html. |
| A replica shows "now leads to X, not to Y" | The replica is reachable only through its AG listener, and after a failover the listener leads to another replica. Add the replica with its own name and port to the server list. |
| The monitor seems slow on a large distributor | Raise `-PendingEvery` and/or `-RefreshSeconds`. Check `Query` per server in Overview (web) or view 7 (console). |
| A repair says "does not apply any more" | The state changed since the detail was loaded (the agent recovered, another repair ran). Reload the detail. |
| A repair fails with a permission error | Jobs need `SQLAgentOperatorRole` (or sysadmin), the other repairs `db_owner` or sysadmin - see Permissions. The step and the error are in `repairs.log`. |
| `-Scan` finds nothing | SQL Browser is stopped, UDP 1434 is blocked, or the servers are in another subnet. Use `-ScanHost <names>` or `-Servers`. |
