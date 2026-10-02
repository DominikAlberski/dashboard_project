# Plan — goal 96f8cff5: weekend MVP (PLAN.md steps 1 to 5)

Revision 3. Revision 2 answered the 13 findings of review task 4d30d1c3. Revision 3 closes finding 7 of task 21c70e4c.
Source: `PLAN.md` at the repository root. Goal message from the project manager.
Graph: fresh (0 commits since build). The repository has no code yet.

## Decisions

- The agent and the client use the Ruby standard library only. No gems at runtime.
- Tests use Minitest. Minitest is a bundled gem of Ruby. Tests do not use rake.
- The test suite runs with one command: `ruby test/all.rb`.
  `test/all.rb` requires every `test/**/*_test.rb` file.
- The protocol is plain HTTP/1.1 with JSON bodies. The agent has no auth and no HTTPS.
- The agent serves the LAN only. The README states this risk.
- The model never runs commands. The agent sends the model reply to the client as text.
- The model is `qwen3.8-ridge-16k:latest`. The project manager decided this in the goal message.
  This decision replaces "Gemma 3 4B" in `PLAN.md`. T0 updates `PLAN.md` to name the configured model. (Finding 1.)
- Supported Ruby versions: the agent targets the Mac Ruby (4.0). The client targets Ruby 2.0 and later.
  The 3GS Ruby version is unknown. The client avoids syntax newer than Ruby 2.0.
  Examples: no numbered block parameters, no `it`, no endless methods, no `then` aliases, no `&.`, no required keyword arguments.
  The client uses only `json`, `io/console`, and `net/http` from the standard library.
- Every class gets its collaborators through the constructor. Tests pass fakes. Tests need no LAN, no PC, and no phone.
- Subprocesses run with argument arrays. No subprocess call goes through a shell. (Finding 9.)

## Configuration

File `config/agent.yml`. The agent loads it at start. Keys and defaults:

| Key | Default | Rule |
| --- | --- | --- |
| `bind` | `0.0.0.0` | IPv4 address |
| `port` | `4567` | 1 to 65535 |
| `scan_range` | `192.168.33.0/24` | IPv4 CIDR, prefix 24 to 30 |
| `scan_interval` | `30` | seconds, integer, 5 or more |
| `ping_timeout` | `1` | seconds, integer, 1 to 5 |
| `ports` | `[22, 80, 443, 445, 3389, 5900, 11434]` | each 1 to 65535 |
| `model_host` | `http://192.168.33.34:11434` | `http://` URL |
| `model_name` | `qwen3.8-ridge-16k:latest` | nonempty string |
| `model_timeout` | `170` | seconds, integer, 10 to 170 |
| `devices_file` | `config/devices.yml` | path |

File `config/devices.yml` ships with placeholder devices. Each device has `name`, `mac`, and `ip`.
`name` matches `/\A[a-z0-9][a-z0-9-]{0,31}\z/i`. `mac` is six hex pairs with `:` or `-`. `ip` is IPv4.
Names are unique (case-insensitive). (Finding 9.)

If a value breaks a rule, the agent prints the key and the rule, and exits with status 1 before it binds the port.

## Agent design

Files under `agent/`. Each file holds one class. Each class stays under 100 lines.

- `config.rb` — `Config` loads `config/agent.yml`, applies the defaults, and validates each value.
- `registry.rb` — `Registry` loads and validates `devices.yml`. It finds a device by name (case-insensitive).
- `runner.rb` — `Runner` runs one subprocess from an argument array with a deadline.
  If the deadline passes, `Runner` kills the process and returns a failure. Tests pass a fake runner.
- `scanner.rb` — `Scanner` runs one scan.
  A scan pings every address in `scan_range` (`ping -c 1 -W <ping_timeout ms>`; process deadline `ping_timeout + 1` s).
  The pings run in a pool of 32 threads. After the pings, the scan reads the ARP table (`arp -an`) for MAC addresses.
  `Scanner` also checks TCP ports of one address. A connector object opens each connection with a 1-second deadline.
  The port checks of one address run in parallel. Tests pass a fake runner and a fake connector.
- `snapshot.rb` — `Snapshot` owns the scan state. (Findings 4, 5.)
  - Only one scan runs at a time. A mutex guards the scan.
  - If a scan request arrives during a scan, the request waits for the running scan. It returns that scan result.
  - A background thread starts a scan every `scan_interval` seconds.
  - A complete scan result replaces the published state in one assignment of a frozen object.
  - If a scan fails, the last good state stays. `last_scan_error` holds the error text. The next good scan clears it.
  - Online rule: a device is online if it answered the ping in the latest good scan. An ARP entry alone does not make a device online.
  - Merge rule: each registry device appears one time, online or offline.
    A scan address matches a registry device by MAC first, then by IP. A matched address does not appear again.
    Each unmatched address that answered the ping appears one time, with `registered: false` and `name: null`.
  - Before the first good scan, `devices` holds the registry devices, all offline. `last_scan_at` is null.
- `wol.rb` — `Wol` builds the magic packet: 6 bytes `0xFF`, then the MAC address 16 times (102 bytes).
  `Wol` sends the packet over UDP broadcast to `255.255.255.255` port 9. A socket object sends it. Tests pass a fake socket.
- `llm.rb` — `Llm` calls ollama `POST /api/chat` with `stream: false` and `model_name`. (Findings 6, 7.)
  It reads `message.content`. It removes any `<think>...</think>` block. It ignores `message.thinking`.
  Deadline: one absolute deadline of `model_timeout` s covers connect, write, and read. (Finding 7, round 2.)
  Connect also has its own 5-second limit inside that deadline. The model call ends by 170 s at most.
  The agent sends its reply by 175 s at most. The client waits 180 s. The last 5 s are a margin for the agent.
  Tests use a fake transport and a fake clock. They prove that a slow model gives a timeout reply before 175 s.
  `Llm#reachable?` calls `GET /api/tags` with connect and read deadlines of 2 s each.
  A transport object sends the HTTP request. Tests pass a fake transport.
- `model_monitor.rb` — `ModelMonitor` owns the cached reachability. (Finding 6.)
  A background thread calls `Llm#reachable?` every 30 seconds. The initial value is null (unknown).
  A failed check sets false. A status request reads the cached value only. It never calls the model host.
- `chat.rb` — `Chat` routes text. The routes are deterministic first, then the model.
  - `ping <target>` pings the target.
  - `scan` runs a scan now (see the `Snapshot` wait rule).
  - `wake <name>` sends a magic packet to a registry device.
  - `ports <target>` lists the open ports of the target from `ports`.
  - A target is a registry device name or an IPv4 address in `scan_range`.
  - The command word is case-insensitive. Surrounding white space is ignored.
  - An unknown target returns a reply that names the registry devices. It does not call the model.
  - Any other text goes to the model.
- `server.rb` — `Server` is a `TCPServer`. One thread serves each connection. (Finding 2.)
  - One request per connection. Each response has `Content-Length`, `Content-Type: application/json`, and `Connection: close`.
    The server closes the socket after the response.
  - The request line and headers have a limit of 8 KB and a read deadline of 5 s.
  - A body needs `Content-Length`. The body limit is 16 KB. The body read deadline is 5 s.
  - The server reads fragmented headers and bodies correctly.
  - A chat request ends by `model_timeout + 5` s at most (175 s with the maximum). Status requests still answer during that wait.
- `bin/agent` starts the agent. `bin/wol <name or MAC>` sends a magic packet from the command line.
  `bin/wol` validates the argument before it sends. It exits 0 on success, 2 on a bad argument, 1 on a send failure.

## API contract

All bodies are JSON. Each error returns `{ "error": "<text>" }`. (Findings 2, 3.)

| Case | Status |
| --- | --- |
| Unknown path | 404 |
| Known path, wrong method | 405 |
| Headers or body over the limit | 413 |
| Missing `Content-Length` on POST | 411 |
| Read deadline passes | 408 |
| Body is not JSON, or JSON is not an object | 400 |
| Field missing or of the wrong type | 422 |

`GET /api/status` returns: (Finding 4.)

```
{ "devices": [ { "name": string|null, "ip": string, "mac": string|null,
                 "online": bool, "registered": bool } ],
  "agent":   { "started_at": iso8601, "last_scan_at": iso8601|null,
               "scanning": bool, "last_scan_error": string|null },
  "model":   { "host": string, "name": string, "reachable": bool|null } }
```

`POST /api/chat`: the body is `{ "text": string }`. `text` is nonempty after strip and 1000 characters or fewer.
It returns `{ "reply": string, "action": "ping"|"scan"|"wake"|"ports"|"model"|"unknown_target" }`.
If the model host does not answer, `reply` says so and `action` is `model`. The status code stays 200.

`POST /api/action`: the body is `{ "action": string, "target": string|null }`. It returns `{ "result": string }`.
`action` is `ping`, `scan`, `wake`, or `ports`. For `scan`, `target` is absent or null.
For the other actions, `target` follows the `Chat` target rule. `wake` needs a registry device name.
An invalid action or target returns 422. `Chat` and the action endpoint share one route table.

## Client design

Files under `client/`. Each class stays under 100 lines.

- `api.rb` — `Api` calls the agent with `Net::HTTP`. (Finding 7.)
  Status: open timeout 3 s, read timeout 5 s. Chat: open timeout 3 s, read timeout 180 s.
- `sanitizer.rb` — `Sanitizer` cleans remote text before rendering. (Finding 10.)
  It removes ESC sequences, other C0 control characters except `\n`, DEL, and C1 control characters.
  It keeps printable text and line breaks. Every remote string goes through `Sanitizer`: replies, device names, errors.
- `screen.rb` — `Screen` renders the device list, the last chat reply, a status line, and the input line.
  It uses ANSI escape codes only. Screen control codes come from `Screen` only, never from remote text.
  It renders to an IO object. Tests pass a `StringIO`.
- `dashboard.rb` — `Dashboard` runs the loop. (Finding 8.)
  - The main thread owns all rendering and all terminal writes.
  - A status thread polls `/api/status` every 4 seconds (allowed range 3 to 5). It pushes results to a queue.
  - Enter sends the input line to `/api/chat` in a chat thread. The chat thread pushes the reply to the queue.
  - Only one chat request runs at a time. If a chat request runs, Enter does not send. The status line says "waiting for reply".
  - During the chat wait, the screen shows a thinking indicator with the elapsed seconds. Status polls continue.
  - The main thread reads keys in raw mode with `io/console`, drains the queue, and renders.
  - Ctrl-C, or `q` on an empty input line, exits. Exit does not wait for a running chat request. The threads stop.
  - An `ensure` block restores cooked mode and shows the cursor on normal exit and on an exception.
- The agent URL comes from the first argument or from the `AGENT_URL` environment variable.
- Tests use fake input, a fake `Api`, and a `StringIO` screen. They cover the one-request rule, the queue,
  the sanitizer, and terminal restore on an exception.

## Glossary (agreed with the reviewer)

T0 commits these terms to `GLOSSARY.md`. Domain terms only.

- **Agent** — The program that watches the home LAN for the user. It scans, pings, checks ports, and wakes devices. _Avoid_: server, bot.
- **Client** — The dashboard that the user holds. It shows device status and sends the user's text to the agent. _Avoid_: app, frontend.
- **Device** — A machine on the home LAN. A device is registered (the registry names it) or unregistered. _Avoid_: host, node.
- **Registry** — The list of registered devices. It maps a device name to its MAC address and IP address. _Avoid_: inventory.
- **Model** — The open-weight language model that answers free text for the agent. The model never runs commands. _Avoid_: AI, LLM.
- **Scan** — One check of the home LAN for devices and their current availability.

Snapshot, Magic packet, and Model host are technical terms. They stay in the plan and the README, not in the glossary.
The display-name rule (an unregistered device shows its IP) belongs to the client, not to the glossary.

## Task split

Two independent paths. Each path has one owner. (Finding 13.)

| Task | Role | Scope |
| --- | --- | --- |
| T0 commit plan, glossary, PLAN.md model line | backend-developer | `docs/**`, `GLOSSARY.md`, `PLAN.md` |
| T1 agent core: config, registry, runner, scanner, snapshot, WOL, `bin/wol` | backend-developer | `agent/**`, `bin/**`, `config/**`, `test/agent/**`, `test/all.rb` |
| T2 agent chat: llm, model monitor, chat, server, `bin/agent`, README | backend-developer | `agent/**`, `bin/**`, `test/agent/**`, `README.md` |
| T3 client dashboard | frontend-developer | `client/**`, `test/client/**` |

- T0 commits this plan to `docs/plans/weekend-mvp.md`.
- T1 and T2 share a scope. T2 starts only after T1 merges into the goal branch. One worker owns both.
- T3 runs in parallel with T1 and T2. T3 depends on the API contract above only.
- Each test folder has its own helper (`test/agent/test_helper.rb`, `test/client/test_helper.rb`). No shared helper.
- One review task follows each implementation task.

## Acceptance mapping

The goal acceptance list of the project manager:

1. `GET /api/status` from a live scan — T1 (`Snapshot`) and T2 (`Server`). Tests use a fake runner.
2. `POST /api/chat` routing without the model — T2. Tests assert that the fake model gets no call for the four commands.
3. WOL from the command line — T1. Tests check the packet bytes with a fake socket and the `bin/wol` exit codes.
4. Client — T3. Tests render to `StringIO` and use a fake `Api`.
5. Tests need no LAN, no PC, no phone — every task. No test opens a network socket except a loopback `TCPServer` in the server test.
6. README — T2. The README states that the agent has no auth and serves the LAN only.

PLAN.md step 5 (end to end on the 3GS) is a manual check. (Finding 11.)
The goal acceptance item 5 says: "Real-device checks stay manual."
No worker has access to the phone, the PC, or the LAN. The user runs the manual checks.
The architect reports the goal as "automated acceptance passed, manual checks pending".
The report names each manual check. The project manager asks the user to run them.
The user records the 3GS Ruby version and the result of `ruby -rjson -rio/console -rnet/http -e 'puts RUBY_VERSION'`.

## Merge suite

`ruby test/all.rb` in the goal worktree, under `coord with-lock system-test`.

## Manual checks (the user runs them)

1. On the 3GS: `ruby -rjson -rio/console -rnet/http -e 'puts RUBY_VERSION'` prints a version.
2. On the Mac: `bin/agent` starts. `GET /api/status` lists real devices. Record the scan duration.
3. `bin/wol <pc-name>` wakes the PC.
4. On the PC: ollama binds to `0.0.0.0` (pitfall P1). The model answers through `/api/chat`.
5. On the 3GS: the client shows the device list. A free-text question gets a model reply.

The Ollama PC did not answer at the last check. Checks 3 to 5 wait until the PC is on.

## Risks

- The `ping` flags differ between macOS and Linux. T1 uses the macOS flags now. The Linux move is out of scope.
- Scan duration is an estimate. 254 pings in 32 threads with a 2-second process deadline is about 16 seconds at most.
  Manual check 2 measures the real duration. (Finding 5.)
- Some devices do not answer ping (phones in sleep). Such a device shows offline. The MVP accepts this.
- The 3GS Ruby version is an assumption. If the client fails on the 3GS, a fix task follows.

## Addendum A — 3GS Ruby version (2026-10-02, after approval)

The user reported a fact. The 3GS runs CRuby 4.0.7. Source: `../docs/device-first-run.md` in the parent project.
This fact replaces the Ruby 2.0 assumption in Decisions and Risks.

- The client targets CRuby 4.0.7. Modern syntax is allowed.
- The device build has no `openssl` and no `psych` extension. The client must not require `openssl`, `yaml`, or `psych`.
- RubyGems does not load automatically on the device. The client must load with `ruby --disable-gems`.
- The device build stores 64-bit inline caches without atomics. This is safe with one Ruby thread.
  The GVL makes the risk low with several Ruby threads. The client keeps its threads. Manual check 5 confirms it.
- The device runs Ruby about 60 times slower than an M1 Mac. The client renders only after a change.
- Manual check 1 becomes: `ruby --disable-gems -rjson -rio/console -rnet/http -e 'puts RUBY_VERSION'` prints 4.0.7.
