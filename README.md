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
bundle exec rails runner "puts WebPush.generate_key_pair.inspect"
```

Copy the output values into your `.env`:

```bash
VAPID_PUBLIC_KEY=generated-public-key
VAPID_PRIVATE_KEY=generated-private-key
```

- Keys must remain stable — changing them invalidates all existing push subscriptions.
- Keep `VAPID_PRIVATE_KEY` secret.

### Push notifications on iOS

iOS requires the app to be installed as a PWA (Add to Home Screen) before push notifications are delivered. Safari 16.4+ on iOS supports Web Push for installed PWAs.

## Webhooks

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
