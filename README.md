# homealert

Progressive web application for home security and alert notifications.
This application allows authenticated users to monitor their home environment.

The application is built using the following technologies:
- Rails 8
- Postgres
- Google OAuth2 for authentication

Current scope:
- Allowlist-based access control for authentication
- Push notifications configured per user account
- Incoming webhooks (POST) when events are triggered

## Getting started

### Prerequisites

- Ruby 3.4.10 (via [chruby](https://github.com/postmodern/chruby) + [ruby-install](https://github.com/postmodern/ruby-install))
- PostgreSQL
- A Google OAuth2 client ([console.cloud.google.com](https://console.cloud.google.com))

### Setup

```bash
bundle install
cp .env.example .env
# Edit .env with your credentials (see Configuration below)
rails db:create db:migrate
rails server
```

## Configuration

Environment variables are loaded from `.env` in development (via `dotenv-rails`).
Copy `.env.example` to `.env` and fill in the values:

```bash
cp .env.example .env
```

### Google OAuth2

| Variable | Description |
|---|---|
| `GOOGLE_CLIENT_ID` | OAuth2 client ID from Google Cloud Console |
| `GOOGLE_CLIENT_SECRET` | OAuth2 client secret from Google Cloud Console |

In your Google Cloud Console OAuth2 client, add the following as an authorized redirect URI:

```
http://localhost:3000/auth/google_oauth2/callback
```

### Access allowlist

HomeAlert uses an email-based allowlist to restrict access to authorized accounts.
Only Google accounts whose email address appears in `ALLOWED_EMAILS` will be permitted to sign in.

| Variable | Description |
|---|---|
| `ALLOWED_EMAILS` | Comma-separated list of authorized email addresses |

**Example:**

```bash
ALLOWED_EMAILS=alice@example.com,bob@example.com
```

- Email matching is case-insensitive.
- Accounts not on the list will be redirected back to the login screen with an error.
- To add or remove access, update `ALLOWED_EMAILS` and restart the server.

### Web Push / VAPID keys

HomeAlert uses the Web Push protocol (VAPID) to deliver push notifications to subscribed devices.

| Variable | Description |
|---|---|
| `VAPID_PUBLIC_KEY` | VAPID public key (URL-safe base64) |
| `VAPID_PRIVATE_KEY` | VAPID private key (URL-safe base64) |

**Generate a key pair:**

```bash
bundle exec rails runner "key = WebPush.generate_key; puts \"VAPID_PUBLIC_KEY=#{key.public_key}\"; puts \"VAPID_PRIVATE_KEY=#{key.private_key}\""
```

Copy the two output lines directly into your `.env`:

```bash
VAPID_PUBLIC_KEY=generated-public-key
VAPID_PRIVATE_KEY=generated-private-key
```

- Keys must remain stable — changing them invalidates all existing push subscriptions.
- Keep `VAPID_PRIVATE_KEY` secret.

### Background job processing

Push notifications are dispatched asynchronously by `PushNotificationJob`. In production the Active Job backend is Solid Queue, so **a worker must be running or notifications are enqueued and never sent** — the web app keeps recording events normally, which makes the failure easy to miss.

| Variable | Description |
|---|---|
| `SOLID_QUEUE_IN_PUMA` | Set to `true` to run the Solid Queue supervisor inside the Puma process (single-server deployments) |

Development uses the in-process `:async` adapter, so no worker is needed there.

To check for a stalled queue in production:

```bash
docker exec homealert ./bin/rails runner 'puts SolidQueue::Job.where(finished_at: nil).count'
```

### Multiple devices

Each browser or installed PWA registers its own subscription, and every event is delivered to all of them. Devices are listed under **Settings → Devices**, where the browser you are currently using is badged "This device". Removing a device only unsubscribes that one.

### Push notifications on iOS

iOS requires the app to be installed as a PWA (Add to Home Screen) before push notifications are delivered. Safari 16.4+ on iOS supports Web Push for installed PWAs.

## Webhooks

All webhook endpoints are route-constrained to the hostnames `localhost` and `security-vm.hostilecity.net`. Requests on any other hostname return `404 Not Found`. No authentication or CSRF token is required.

### ReoLink doorbell (`POST /webhooks/reolink`)

The endpoint accepts JSON only. A `200 OK` is returned on success; `422 Unprocessable Entity` is returned for unrecognised event types or invalid payloads.

**Doorbell press (Visitor alert):**

```bash
curl -X POST http://localhost:3000/webhooks/reolink \
  -H 'Content-Type: application/json' \
  -d '{
    "alarm": {
      "alarmTime": "2026-08-17T17:04:34.000+0000",
      "channel": 0,
      "channelName": "doorbell",
      "device": "doorbell",
      "deviceModel": "Reolink Video Doorbell WiFi",
      "message": "A Visitor is Ringing the doorbell",
      "name": "Visitor Alert",
      "title": "Visitor message",
      "type": "VISITOR"
    }
  }'
```

**Motion detection (Person detected):**

```bash
curl -X POST http://localhost:3000/webhooks/reolink \
  -H 'Content-Type: application/json' \
  -d '{
    "alarm": {
      "alarmTime": "2026-08-17T16:59:33.000+0000",
      "channel": 0,
      "channelName": "doorbell",
      "device": "doorbell",
      "deviceModel": "Reolink Video Doorbell WiFi",
      "message": "Person Detected from doorbell",
      "name": "Person Detected from doorbell",
      "title": "Camera Alert",
      "type": "PEOPLE"
    }
  }'
```

### VPN login (`POST /webhooks/vpn_login`)

The endpoint accepts JSON only. A `200 OK` is returned on success; `422 Unprocessable Entity` is returned for unrecognised event values or invalid payloads.

Push notifications for VPN login events are **disabled by default** in user notification preferences. Users can opt in under **Settings → Push Notifications → VPN login**.

#### OpenVPN client-connect script

The webhook is designed to be called from an OpenVPN `client-connect` script. The script at `script/vpn_webhook.sh` is installed on the VPN server and uses environment variables that OpenVPN sets automatically when a client connects:

| Variable | OpenVPN env var | Description |
|---|---|---|
| `username` | `$username` | Authenticated username (from `--auth-user-pass`) |
| `common_name` | `$common_name` | Certificate common name |
| `source_ip` | `$trusted_ip` | Client's public IP address |
| `timestamp_unix` | `$time_unix` | Unix timestamp of the connection |

**Install the script on the VPN server:**

```bash
# Copy the script to the OpenVPN config directory
cp script/vpn_webhook.sh /etc/openvpn/client-connect.sh
chmod +x /etc/openvpn/client-connect.sh

# Add to your OpenVPN server config (server.conf):
# client-connect /etc/openvpn/client-connect.sh
```

**Test the endpoint manually:**

```bash
curl -X POST http://localhost:3000/webhooks/vpn_login \
  -H 'Content-Type: application/json' \
  -d "{
    \"event\":          \"vpn_login\",
    \"username\":       \"rtulino\",
    \"common_name\":    \"ryans-macbook\",
    \"source_ip\":      \"203.0.113.42\",
    \"timestamp_unix\": \"$(date +%s)\"
  }"
```

The `device_name` stored on the event is formatted as `username (common_name)` when both differ, or just the username/common_name alone when they are the same or one is absent. The `source_ip` is stored as `device_id`.
