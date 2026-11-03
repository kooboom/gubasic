# 중계 서버를 자기 서버에 올리기

[English](RELAY_SERVER.md)

GuBASIC의 `Room`(LANGUAGE 11.12절)은 중계 서버를 거쳐 프로그램끼리 메시지를 주고받습니다. 개발하는 동안에는 데스크톱 IDE가 자기 컴퓨터에 중계 서버를 저절로 켭니다. 다른 사람들이 폰으로, 어디서나 쓰는 앱이라면 중계 서버는 자기 서버에서 돌고, `Room.Server`가 그 서버를 가리킵니다. 공개 중계 서버는 없습니다(DESIGN D136).

중계 서버는 이 저장소의 `packages/gubasic_relay`입니다. 방을 메모리에만 두고, 바꿀 수 있는 제한이 있는 Dart로 쓴 작은 프로그램입니다. 프로토콜은 [ROOM_PROTOCOL.ko.md](ROOM_PROTOCOL.ko.md)에 공개되어 있습니다. 아래의 `relay.example.com`은 자기 서버 이름을 대신하는 것이므로, 나오는 곳마다 자기 이름을 적습니다.

## 필요한 것

- systemd가 있는 Linux 서버(Ubuntu, Debian 등), x64 또는 arm64, `sudo`를 쓸 수 있어야 합니다.
- 그 서버의 주소를 가리키는 이름 `relay.example.com`.
- 앞에 Apache 2.4.47 이상과 [Let's Encrypt](https://letsencrypt.org/getting-started/) 인증서. 앱이 `wss://`로 연결하기 위해서입니다. `https`로 열린 페이지는 `ws://`를 열지 못합니다.

## 설치

원하는 릴리스의 `deploy` 폴더를 받거나 저장소를 복제한 뒤:

```sh
cd gubasic/packages/gubasic_relay/deploy
sudo ./install.sh
```

스크립트가 하는 일:

1. 릴리스의 `gubasic-relay-linux-x64`(또는 `-arm64`)를 받아 릴리스의 `SHA256SUMS.txt`와 맞는지 확인합니다(`--from-source DIR`를 주면 대신 `DIR`의 저장소에서 Dart로 빌드합니다).
2. 시스템 사용자 `gubasic-relay`를 만들고, 프로그램을 `/opt/gubasic-relay`에, 설정을 `/etc/gubasic-relay/relay.yaml`에 둡니다.
3. systemd 서비스 `gubasic-relay`를 등록하고 켭니다. 서버 안의 프로그램만 닿는 `127.0.0.1:7071`에서 듣습니다.
4. Apache에 넣을 줄을 보여 줍니다.

## 앞에 Apache

모듈을 켠 뒤, `relay.example.com`의 `<VirtualHost *:443>`에 넣습니다(파일 전체는 `deploy/apache-relay.conf.example`):

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

`upgrade=websocket`이 WebSocket 업그레이드를 넘겨 주고([Apache, mod_proxy](https://httpd.apache.org/docs/2.4/mod/mod_proxy.html#proxypass)), `ProxyTimeout`은 조용한 방의 연결을 열어 둡니다.

## 확인

```sh
curl https://relay.example.com/room/health
```

`{"gubasicRelay":"0.6.0","rooms":0}`으로 답합니다. 그다음 앱의 `Room.Server`를 속성 창에서 `wss://relay.example.com/room`으로 정하고, 내보내서 방을 만들어 봅니다. 같은 Apache가 내보낸 웹 앱도 서비스한다면 `Room.Server`에 경로만 `/room`으로 적어도 됩니다. 그러면 앱이 자기를 준 서버를 씁니다.

## 설정

`/etc/gubasic-relay/relay.yaml`. 바꾼 뒤에는 `sudo systemctl restart gubasic-relay`.

| 설정 | 기본값 | 뜻 |
|---|---|---|
| `allowedOrigins` | `[]` | 연결해도 되는 웹 페이지의 주소(`https://quiz.example.com`). **채워 넣으세요:** 비어 있으면 웹의 어느 페이지든 내 서버를 쓸 수 있습니다. 웹 페이지가 아닌 프로그램은 Origin을 보내지 않으므로 이것으로 막히지 않습니다 |
| `key` | 없음 | 모든 프로그램이 내야 하는 낱말. 앱 안에 그대로 들어가므로 비밀이 아닙니다. 남의 앱을 막는 문이지, 내 앱을 들여다보는 사람을 막지는 못합니다 |
| `maxRooms`, `maxMembers` | 50, 50 | 동시에 열린 방, 방 하나의 인원 |
| `maxMessageBytes` | 16384 | 메시지 크기. 더 크면 거부하고, 세 번째에는 연결을 닫습니다 |
| `messagesPerSecond` | 20 | 멤버 한 사람이. 세 배가 되면 연결을 닫습니다 |
| `joinAttemptsPerMinute` | 30 | 한 주소에서. 방 코드 추측을 막습니다 |
| `idleMinutes`, `maxRoomMinutes` | 30, 360 | 조용한 방은 끝나고, 어떤 방이든 6시간 뒤에 끝납니다 |
| `logMessages` | `false` | `true`일 때만 메시지 본문을 기록합니다 |
| `bind`, `port` | `127.0.0.1`, `7071` | 듣는 곳. Apache 뒤라면 `127.0.0.1` 그대로 둡니다 |

디스크에는 아무것도 남기지 않습니다. 방은 메모리에만 있고, 방이 끝나면 그 메시지도 사라집니다. 기록(`journalctl -u gubasic-relay`)에는 방이 열리고 닫힌 때와 거부한 것이 남고, 별명과 메시지는 남지 않습니다.

## 업데이트

설치 스크립트를 다시 실행합니다. 새 릴리스를 적으면(`--version v0.6.1`) 그것으로 바꿉니다. 설정은 그대로이고 서비스가 다시 켜집니다. 그때 열려 있던 방은 끝납니다.

## 제거

```sh
sudo ./install.sh --uninstall          # /etc/gubasic-relay/relay.yaml은 남김
sudo ./install.sh --uninstall --purge  # 그것도 지움
```

그다음 Apache에서 `ProxyPass` 줄을 뺍니다.
