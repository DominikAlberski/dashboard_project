# Ruby on 3GS

The repository holds two programs.

- `agent/` runs on the Mac. The agent watches the home LAN.
- `client/` runs on the 3GS. The client shows device status and sends text to the agent.

The agent and the client use the Ruby standard library only. No gems are needed at runtime.

## Security

The agent has no authentication. The agent serves the LAN only.
Do not expose the agent to the internet. The agent uses plain HTTP. It does not use HTTPS.

## Configure the agent

The file `config/agent.yml` holds the agent settings.
Change `model_name` to use a different model. The default is `qwen3.8-ridge-16k:latest`.

The file `config/devices.yml` holds the registered devices. Each device has a name, a MAC address, and an IP address.

## Start the agent

Run the agent from the repository root.

```
bin/agent
```

The agent prints the bind address and the port.
The default port is 4567. Set `AGENT_CONFIG` to use another configuration file.

## Wake a device from the command line

```
bin/wol <name or MAC>
```

The command exits 0 on success. The command exits 1 on a send failure.
The command exits 2 on a bad argument.

## Set up ollama on the PC

The model runs on the PC through ollama. ollama binds to localhost by default.
Set `OLLAMA_HOST=0.0.0.0` on the PC, so the agent can reach the model.

## Run the client on the 3GS

The client has two forms. The terminal dashboard is for a real terminal. The
web dashboard runs as a daemon and serves an HTML page for Safari.

Both target CRuby 4.0.7. The device has no `openssl` and no `psych` extension.
The client must not require them. Load the client with `--disable-gems`.

### Web dashboard (Safari, home screen icon)

The web dashboard serves an HTML page on the 3GS. Safari opens it with no
JavaScript and no internet connection. It polls the agent over the LAN.

```
AGENT_URL=http://<mac-ip>:4567 PORT=8081 ruby --disable-gems client/bin/serve
```

Then open `http://127.0.0.1:8081/` in Safari on the 3GS. Add it to the home
screen for a full-screen icon. The default bind is `127.0.0.1`, so only the
device reads the page. The page reloads itself every 10 seconds.

### Terminal dashboard

```
AGENT_URL=http://<mac-ip>:4567 ruby --disable-gems client/bin/dashboard
```

The client reads the agent URL from the first argument or from `AGENT_URL`.

## Manual checks

No worker has access to the phone, the PC, or the LAN. Run these checks by hand.

1. On the 3GS: `ruby --disable-gems -rjson -rio/console -rnet/http -e 'puts RUBY_VERSION'` prints 4.0.7.
2. On the Mac: `bin/agent` starts. `GET /api/status` lists real devices. Record the scan duration.
3. On the Mac: `bin/wol <pc-name>` wakes the PC.
4. On the PC: ollama binds to `0.0.0.0`. The model answers through `/api/chat`.
5. On the 3GS: the client shows the device list. A free-text question gets a model reply.

Checks 3 to 5 wait until the PC is on.
