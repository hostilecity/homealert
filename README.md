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
