# Ruby on 3GS — Implementation Plan

## Goal

Give a 2009 iPhone 3GS a dashboard that controls a local AI agent.
The agent watches the home LAN. The user asks the phone in plain English.
The agent scans devices, pings, checks ports, and wakes machines.
The model runs open-weight on a PC on the LAN. `config/agent.yml` sets the model.
The default is `qwen3.8-ridge-16k:latest`.

## Architecture

Three parts. Each part runs on a different machine. All parts use Ruby.

```
3GS (Ruby dashboard client)
  └── HTTP LAN ──> Mac (Ruby agent: scan / ping / port / WOL / chat)
                        └── HTTP LAN ──> PC (ollama → model from config/agent.yml)
```

The 3GS is too weak to run a model. It is a remote control.
The agent is a thin shell. The model lives on the PC.
Each part is replaceable. This is the open-innovation pitch.

## Components

### 1. Agent (runs on Mac now, Linux laptop later)

Stdlib only. No gems. This keeps it portable.

- `server.rb` — minimal TCP server. Serves JSON over HTTP.
- `scanner.rb` — reads the ARP table. Pings the /24 subnet. Checks ports.
- `wol.rb` — sends a Wake-on-LAN magic packet over UDP.
- `llm.rb` — HTTP client for the ollama API.
- `registry.rb` — maps device name to MAC address and IP. Loads `config/devices.yml`.

### 2. Client (runs on the 3GS)

Stdlib only. No gems. No curses gem (it may not build on iOS).

- `dashboard.rb` — draws with ANSI escape codes. Polls `/api/status` every 3–5 s.
  Reads keys in raw mode via `io/console` and `stty raw`.
  One input line at the bottom. Sends text to `/api/chat`.

### 3. Model (runs on the PC)

ollama serves the model that `config/agent.yml` names.
The default is `qwen3.8-ridge-16k:latest`. See pitfall P1 below.

## API Contract

| Method | Path         | Body                  | Returns |
| ------ | ------------ | --------------------- | ------- |
| GET    | `/api/status`| —                     | `{ devices, agent, model }` |
| POST   | `/api/chat`  | `{ "text": "..." }`   | `{ "reply", "action" }` |
| POST   | `/api/action`| `{ "action", "target" }` | `{ "result" }` |

Chat routing is deterministic first, LLM fallback second.

- `ping <name>` → ping the device.
- `scan` → rescan the network now.
- `wake <name>` → send WOL packet.
- `ports <name>` → list open ports.
- Anything else → send text to the model, return the reply.

The model reply is plain text. It never runs commands directly.

## Repo Layout

```
ruby-on-3gs/
  agent/
    server.rb
    scanner.rb
    wol.rb
    llm.rb
    registry.rb
  client/
    dashboard.rb
  config/
    devices.yml
  README.md
  PLAN.md
```

## Weekend Scope (MVP)

1. Agent serves `/api/status` from a live scan. Green.
2. Agent serves `/api/chat` with deterministic routing + LLM fallback. Green.
3. WOL works from the command line. Green.
4. Client dashboard draws the device list and accepts chat. Green.
5. End-to-end: ask on the 3GS, model answers on the LAN. Green.

## Deferred (plan only, do not build now)

- Migrate the agent to the Linux laptop. Add a systemd unit. Run 24/7.
- Add a browser dashboard for normal machines.
- Add a second 3GS.
- Let the model propose tool calls (stretch; MVP keeps routing deterministic).

## Pitfalls

- **P1 — ollama binds to localhost by default.** On the PC set `OLLAMA_HOST=0.0.0.0`
  or the Mac agent cannot reach it. Confirm when the PC is on.
- **P2 — no curses gem on the 3GS.** Use raw ANSI escape codes and `stty raw`.
- **P3 — the 3GS has 256 MB RAM.** It cannot run a model. Keep the client thin.
- **P4 — plain HTTP only.** The 3GS cannot speak TLS 1.2. Do not add HTTPS.

## Why Open Innovation Matters

Closed cloud AI cannot reach a home LAN or a 2009 phone.
An open-weight model on the user's own PC can do both.
The user owns the data. The user swaps the model freely.
This is the story for the DEV post.
