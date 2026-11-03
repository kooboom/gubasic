# Putting the relay server on your own server

[한국어](RELAY_SERVER.ko.md)

GuBASIC's `Room` (LANGUAGE §11.12) passes messages between programs through a relay server. While you develop, the desktop IDE runs one on your computer by itself. For an app other people use, from their phones and from anywhere, the relay server runs on a server of yours, and `Room.Server` names it. There is no public relay server (DESIGN D136).

The relay server is `packages/gubasic_relay` in this repository: a small program in Dart that keeps rooms in memory only, with limits you can change. Its protocol is published in [ROOM_PROTOCOL.md](ROOM_PROTOCOL.md). Below, `relay.example.com` stands for your server's name: write yours wherever it appears.

## What you need

- A Linux server with systemd (Ubuntu, Debian and the like), on x64 or arm64, where you can use `sudo`.
- A name for it, `relay.example.com`, pointing to its address.
- Apache 2.4.47 or later in front of it, with a certificate from [Let's Encrypt](https://letsencrypt.org/getting-started/), so that apps connect with `wss://`. A page served over `https` cannot open `ws://`.

## Installing

Download the folder `deploy` of the release you want (or clone the repository), then:

```sh
cd gubasic/packages/gubasic_relay/deploy
sudo ./install.sh
```

The script:

1. downloads the release's `gubasic-relay-linux-x64` (or `-arm64`) and checks it against the release's `SHA256SUMS.txt` (with `--from-source DIR` it builds it with Dart from the repository in `DIR` instead);
2. makes a system user `gubasic-relay`, puts the program in `/opt/gubasic-relay` and the settings in `/etc/gubasic-relay/relay.yaml`;
3. registers the systemd service `gubasic-relay` and starts it, on `127.0.0.1:7071`, where only programs on the server reach it;
4. shows the lines to add to Apache.

## Apache in front

Enable the modules, then add to the `<VirtualHost *:443>` of `relay.example.com` (the whole file is `deploy/apache-relay.conf.example`):

```apache
ProxyPass        "/room" "http://127.0.0.1:7071/room" upgrade=websocket
ProxyPassReverse "/room" "http://127.0.0.1:7071/room"
ProxyTimeout 300
```

```sh
sudo a2enmod ssl proxy proxy_http
sudo certbot --apache -d relay.example.com
sudo systemctl reload apache2
```

`upgrade=websocket` passes the WebSocket upgrade on ([Apache, mod_proxy](https://httpd.apache.org/docs/2.4/mod/mod_proxy.html#proxypass)); `ProxyTimeout` keeps a quiet room's connection open.

## Checking

```sh
curl https://relay.example.com/room/health
```

answers `{"gubasicRelay":"0.6.0","rooms":0}`. Then set `Room.Server` in your app to `wss://relay.example.com/room` (in the Properties window), export it, and try a room. When the same Apache also serves the exported web app, `Room.Server` can be the path alone, `/room`: the app then uses the server it came from.

## Settings

`/etc/gubasic-relay/relay.yaml`; after a change, `sudo systemctl restart gubasic-relay`.

| Setting | Default | Meaning |
|---|---|---|
| `allowedOrigins` | `[]` | The web pages allowed to connect, by address (`https://quiz.example.com`). **Fill it in:** empty allows any page on the web to use your server. Programs that are not web pages send no Origin and are not refused by it |
| `key` | none | A word every program must give. It goes into your apps as it is, so it is not a secret: it keeps strangers' apps out, not people who look inside yours |
| `maxRooms`, `maxMembers` | 50, 50 | Rooms open at once; members in a room |
| `maxMessageBytes` | 16384 | A message's size; bigger ones are refused, and the third closes the connection |
| `messagesPerSecond` | 20 | From one member; three times as many closes the connection |
| `joinAttemptsPerMinute` | 30 | From one address, against guessing room codes |
| `idleMinutes`, `maxRoomMinutes` | 30, 360 | A quiet room ends; any room ends after six hours |
| `logMessages` | `false` | Message bodies are written to the log only when this is `true` |
| `bind`, `port` | `127.0.0.1`, `7071` | Where it listens; behind Apache, keep `127.0.0.1` |

Nothing is kept on disk: rooms live in memory, and a room's messages are gone when it ends. The log (`journalctl -u gubasic-relay`) says when rooms open and close and what was refused, without nicknames or messages.

## Updating

Run the installer again, with a newer release if you name one (`--version v0.6.1`): the settings are kept, and the service starts again. Rooms open at that moment end.

## Removing

```sh
sudo ./install.sh --uninstall          # keeps /etc/gubasic-relay/relay.yaml
sudo ./install.sh --uninstall --purge  # removes it too
```

Then take the `ProxyPass` lines out of Apache.
