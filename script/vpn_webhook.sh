#!/bin/sh
# OpenVPN passes variables automatically: $common_name, $trusted_ip, etc.
WEBHOOK_URL="http://security-vm.hostilecity.net/webhooks/vpn_login"

# Construct JSON payload
PAYLOAD=$(cat <<EOF
{
  "event": "vpn_login",
  "username": "$username",
  "common_name": "$common_name",
  "source_ip": "$trusted_ip",
  "timestamp_unix": "$time_unix"
}
EOF
)

# Send HTTP POST
curl -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$WEBHOOK_URL"