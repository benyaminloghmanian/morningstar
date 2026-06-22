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
CERT_DIR="/root/cert/${FQDN}"
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
  "https://api.cloudflare.com/client/v4/zones/${CFZONEID}/dns_records?type=A&name=${FQDN}" \
  -H "Authorization: Bearer ${CFTOKEN}" \
  -H "Content-Type: application/json" \
  | jq -r '.result[0].id // empty')

payload="{\"type\":\"A\",\"name\":\"${FQDN}\",\"content\":\"${PIP_Address}\",\"proxied\":false}"

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
SSHKEY=$(cat /root/.ssh/authorized_keys)
printf "no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo 'Please login as the user \\\\\"${ADMINUSER}\\\\\" rather than the user \\\\\"root\\\\\".';echo;sleep 10;exit 142\" ${SSHKEY}\n" > /root/.ssh/authorized_keys

# Create admin user
useradd -m -s /bin/bash $ADMINUSER
usermod -aG sudo $ADMINUSER
mkdir -p /home/$ADMINUSER/.ssh
echo "${SSHKEY}" | tee /home/$ADMINUSER/.ssh/authorized_keys
chmod 700 /home/$ADMINUSER/.ssh/
chmod 600 /home/$ADMINUSER/.ssh/authorized_keys
chown -R $ADMINUSER:$ADMINUSER /home/$ADMINUSER/.ssh
echo "${ADMINUSER} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$ADMINUSER
sudo chmod 440 /etc/sudoers.d/$ADMINUSER

# Install x-ui non-interactively 
curl -fsSL https://raw.githubusercontent.com/MHSanaei/3x-ui/main/install.sh -o /tmp/install.sh
bash /tmp/install.sh </dev/null || true

# Issue Let's Encrypt cert via acme.sh (standalone mode, needs :80 free)
curl -fsSL https://get.acme.sh | sh -s email=admin@"$FQDN"
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
mkdir -p "$CERT_DIR"
~/.acme.sh/acme.sh --issue -d "$FQDN" --standalone --keylength ec-256
~/.acme.sh/acme.sh --installcert -d "$FQDN" --ecc --key-file "$CERT_DIR/privkey.pem" --fullchain-file "$CERT_DIR/fullchain.pem"

# Configure x-ui via CLI
x-ui stop
/usr/local/x-ui/x-ui setting -username "5CogXckNx5" -password "HFYzCsxg7q"
/usr/local/x-ui/x-ui setting -port 13000
/usr/local/x-ui/x-ui setting -webBasePath "zQGMx3X967"
/usr/local/x-ui/x-ui cert -webCert "$CERT_DIR/fullchain.pem" -webCertKey "$CERT_DIR/privkey.pem"
x-ui start
/usr/local/x-ui/x-ui setting -show true

# Clean after cloud-init.sh
rm -f /tmp/cloud-init.sh /var/log/cloud-init.log /var/log/cloud-init-output.log
rm -rf /var/lib/cloud/
cloud-init clean --logs --seed
cat /dev/null > ~/.bash_history && history -c
rm -f /tmp/install.sh

# Change SSH port
echo "Port 733" | sudo tee /etc/ssh/sshd_config.d/port.conf
systemctl disable --now ssh.socket 2>/dev/null
systemctl enable --now ssh.service
systemctl restart ssh

# "He who does God's will, will live forever." ~ Semper Fi, Secula Seculorum