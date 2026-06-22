#!/bin/bash
CALLSIGN=""
CFTOKEN=""
CFZONEID=""

while [ $# -gt 0 ]; do
    case "$1" in
        --CALLSIGN) CALLSIGN="$2"; shift 2 ;;
        --CFTOKEN)  CFTOKEN="$2";  shift 2 ;;
        --CFZONEID) CFZONEID="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# enforce mandatory
if [ -z "$CALLSIGN" ] || [ -z "$CFTOKEN" ] || [ -z "$CFZONEID" ]; then
    echo "Usage: $0 --CALLSIGN <value> --CFTOKEN <value> --CFZONEID <value>" >&2
    exit 1
fi

# Variables
TZ="Europe/Berlin"
HOSTNAME="srv-ubuntu-${CALLSIGN}"
FQDN="${HOSTNAME}.ms.eubits.com"
PIP_Address=$(curl -4 -s https://api.ipify.org)
ADMINUSER="${HOSTNAME}-root"

# Timezone
timedatectl set-timezone $TZ

# MOTD
chmod -x /etc/update-motd.d/00-header
chmod -x /etc/update-motd.d/10-help-text
chmod -x /etc/update-motd.d/50-motd-news
chmod -x /etc/update-motd.d/90-updates-available
chmod -x /etc/update-motd.d/91-contract-ua-esm-status
curl -s -L https://raw.githubusercontent.com/benyaminloghmanian/morningstar/main/motd -o /etc/update-motd.d/00-ms-motd && chmod +x /etc/update-motd.d/00-ms-motd

# CF DNS
record_id=$(curl -s -X GET \
  "https://api.cloudflare.com/client/v4/zones/${CFZONEID}/dns_records?type=A&name=${HOSTNAME}" \
  -H "Authorization: Bearer ${CFTOKEN}" \
  -H "Content-Type: application/json" \
  | jq -r '.result[0].id // empty')

payload="{\"type\":\"A\",\"name\":\"${HOSTNAME}\",\"content\":\"${PIP_Address}\",\"proxied\":false}"

if [ -n "$record_id" ]; then
  # Exists -> update
  curl -s -X PUT \
    "https://api.cloudflare.com/client/v4/zones/${CFZONEID}/dns_records/${record_id}" \
    -H "Authorization: Bearer ${CFTOKEN}" \
    -H "Content-Type: application/json" \
    --data "$payload"
else
  # Doesn't exist -> create
  curl -s -X POST \
    "https://api.cloudflare.com/client/v4/zones/${CFZONEID}/dns_records" \
    -H "Authorization: Bearer ${CFTOKEN}" \
    -H "Content-Type: application/json" \
    --data "$payload"
fi | jq '.result | {id,name,content}'

# Disallow direct root login
printf "no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo 'Please login as the user \\\"${ADMINUSER}\\\" rather than the user \\\"root\\\".';echo;sleep 10;exit 142\" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOp0nSfBbg6QGXSpFcQAcY/scXVlBN0/MyGcIOgokX2Y" > /root/.ssh/authorized_keys

# Create admin user
useradd -m -s /bin/bash $ADMINUSER
usermod -aG sudo $ADMINUSER
mkdir -p /home/$ADMINUSER/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOp0nSfBbg6QGXSpFcQAcY/scXVlBN0/MyGcIOgokX2Y ben@Bens-Mac.local' | tee /home/$ADMINUSER/.ssh/authorized_keys
chmod 700 /home/$ADMINUSER/.ssh/
chmod 600 /home/$ADMINUSER/.ssh/authorized_keys
chown -R $ADMINUSER:$ADMINUSER /home/$ADMINUSER/.ssh
echo "${ADMINUSER} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$ADMINUSER
sudo chmod 440 /etc/sudoers.d/$ADMINUSER