#!/bin/bash

# +---------------------------------------------+ #
# | Setup easyroam with NetworkManager on linux | #
# | Originally developed by https://github.com/jahtz       | #
# | Modified by chri20q5 for improved CA certificate extraction | #
# +---------------------------------------------+ #

# easyroam: https://www.easyroam.de/
# DFN: https://www.dfn.de/

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cat <<'EOF'
-----------------------------------------------------------------------------
 easyroam_nm.sh - Easyroam NetworkManager Auto-Setup Script

 This script automates the setup of an eduroam connection on Linux systems using 
 NetworkManager. It imports your Easyroam client certificate (provided as a 
 PKCS#12 (.p12) license file) and configures the necessary network profile for 
 secure wireless authentication.

 Result:
   After running this script, you will have:
    - Your PKCS#12 (.p12) client certificate imported into NetworkManager.
    - A new eduroam Wi-Fi profile configured and ready to use.

 Where to get your .p12 license file:
   The .p12 (PKCS#12) license/certificate file can be downloaded from
   https://www.easyroam.de

 For further instructions, please refer to the README.md file found in
 this repository.

-----------------------------------------------------------------------------
EOF

echo
read -n 1 -s -r -p "Press any key to continue..."
echo

# DEFAULT VALUES
PKPW=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 15)  # random password
OUTDIR="$( getent passwd "$USER" | cut -d: -f6 )/.cert/easyroam"
LEGACY="-legacy"
DEBUG=false
CONNECTION_NAME="easyroam"
REPLACE_EXISTING=false

# DEPENDENCY CHECK
check_dependency() {
    echo -n "$1... "
    if ! type "$1" &> /dev/null; then
        echo "Not found!"
        exit 1
    fi
    echo "Ok"
}

echo "Checking dependencies:"
check_dependency "nmcli"
check_dependency "openssl"
check_dependency "awk"

# PROMPTS
echo
echo -e "Select PKCS12 (.p12) bundle file:"
read -e p12file
if [[ -z "$p12file" || ! -f "$p12file" || "${p12file##*.}" != "p12" ]]; then
    echo "Invalid PKCS12 file path!"
    exit 1
fi

echo
echo -e "Set output directory [Default: $OUTDIR]:"
read -e outputdir_new
outputdir="${outputdir_new:-$OUTDIR}"
p12name=$(basename "$p12file")

# Enable debug mode option
echo
echo -e "Enable debug mode? (shows detailed certificate info) [y/N]:"
read -n 1 debug_choice
echo
if [[ "$debug_choice" == "y" || "$debug_choice" == "Y" ]]; then
    DEBUG=true
fi

# Check for existing eduroam/easyroam connections
echo
echo "=== Checking for existing eduroam connections ==="
existing_connections=$(nmcli -t -f NAME connection show | grep -i "eduroam\|easyroam" || true)

if [[ -n "$existing_connections" ]]; then
    echo "Found existing connections:"
    echo "$existing_connections" | while read conn; do
        echo "  - $conn"
    done
    echo
    echo "What would you like to do?"
    echo "  1) Replace existing connection (delete and recreate)"
    echo "  2) Create new connection with different name (keep existing)"
    echo "  3) Exit"
    echo
    read -p "Choice [1-3]: " choice
    
    case $choice in
        1)
            REPLACE_EXISTING=true
            # Ask which connection to replace if multiple exist
            conn_count=$(echo "$existing_connections" | wc -l)
            if [[ $conn_count -gt 1 ]]; then
                echo
                echo "Multiple connections found. Which one to replace?"
                select conn in $existing_connections "Cancel"; do
                    if [[ "$conn" == "Cancel" ]]; then
                        echo "Exiting."
                        exit 0
                    elif [[ -n "$conn" ]]; then
                        CONNECTION_NAME="$conn"
                        break
                    else
                        echo "Invalid option $REPLY"
                    fi
                done
            else
                CONNECTION_NAME="$existing_connections"
            fi
            echo "Will replace connection: $CONNECTION_NAME"
            ;;
        2)
            REPLACE_EXISTING=false
            echo
            echo "Enter name for new connection [Default: easyroam-new]:"
            read new_conn_name
            CONNECTION_NAME="${new_conn_name:-easyroam-new}"
            
            # Check if chosen name already exists
            if nmcli connection show "$CONNECTION_NAME" >/dev/null 2>&1; then
                echo "Error: Connection '$CONNECTION_NAME' already exists!"
                echo "Please choose a different name or restart and choose option 1."
                exit 1
            fi
            echo "Will create new connection: $CONNECTION_NAME"
            ;;
        3|*)
            echo "Exiting."
            exit 0
            ;;
    esac
else
    echo "No existing eduroam connections found."
    echo "Will create new connection: $CONNECTION_NAME"
fi
echo "=================================================="
echo

interfaces=()  # select wireless network interfaces
for iface in $(ls /sys/class/net/); do
    if [ -d "/sys/class/net/$iface/wireless" ]; then
        interfaces+=("$iface")
    fi
done

if [[ ${#interfaces[@]} -eq 0 ]]; then
    echo "Error: No wireless interfaces found!"
    exit 1
fi

interface=""
echo -e "Select wifi interface to configure"
PS3="Interface: "
select opt in "${interfaces[@]}" "Exit"; do
    case $opt in
        "Exit")
            exit 0
            ;;
        "")
            echo "Invalid option $REPLY"
            ;;
        *)
            interface="$opt"
            break
            ;;
    esac
done

# LOGIC
echo
echo -n -e "Create output directory... "
if [[ ! -d "$outputdir" ]]; then
    mkdir -p "$outputdir" || { echo "Failed to create directory."; exit 1; }
fi
echo "Done"

echo -n "Copy PKCS12 file... "
cp "$p12file" "$outputdir" || { echo "Failed to copy PKCS12 file."; exit 1; }
echo "Done"
cd "$outputdir" || { echo "Failed to change directory."; exit 1; }

# Debug: Show PKCS12 contents
if [[ "$DEBUG" == true ]]; then
    echo -e "\n=== DEBUG: PKCS#12 Bundle Contents ==="
    openssl pkcs12 -in "$p12name" -info -noout -passin pass: "$LEGACY" 2>/dev/null || \
        openssl pkcs12 -in "$p12name" -info -noout -passin pass: 2>/dev/null
    echo "=== END DEBUG ==="
    echo
fi

echo -n "Build client certificate... "
openssl pkcs12 -in "$p12name" "$LEGACY" -nokeys -passin pass: 2>/dev/null | openssl x509 > easyroam_client_cert.pem
if [[ $? -ne 0 ]]; then
    LEGACY=""
    openssl pkcs12 -in "$p12name" "$LEGACY" -nokeys -passin pass: 2>/dev/null | openssl x509 > easyroam_client_cert.pem
    if [[ $? -ne 0 ]]; then
        echo "Failed to build client certificate."
        exit 1
    fi
fi

# Verify client certificate was created properly
if [[ ! -s easyroam_client_cert.pem ]]; then
    echo "FAIL: Client certificate file is empty."
    exit 1
fi

if ! openssl x509 -in easyroam_client_cert.pem -noout 2>/dev/null; then
    echo "FAIL: Client certificate is invalid."
    exit 1
fi
echo "Done"

cn=$(openssl x509 -noout -subject -in easyroam_client_cert.pem | sed -n 's/^.*CN=\([^,]*\).*$/\1/p')

if [[ "$DEBUG" == true ]]; then
    echo "  Identity (CN): $cn"
fi

echo -n "Build private key... "
openssl pkcs12 "$LEGACY" -in "$p12name" -nodes -nocerts -passin pass: 2>/dev/null | openssl rsa -aes256 -passout pass:"$PKPW" -out easyroam_client_key.pem -legacy 2>/dev/null
if [[ $? -ne 0 ]]; then
    openssl pkcs12 "$LEGACY" -in "$p12name" -nodes -nocerts -passin pass: 2>/dev/null | openssl rsa -aes256 -passout pass:"$PKPW" -out easyroam_client_key.pem 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "Failed to build private key."
        exit 1
    fi
fi

# Verify private key
if [[ ! -s easyroam_client_key.pem ]]; then
    echo "FAIL: Private key file is empty."
    exit 1
fi
echo "Done"

echo -n "Build RootCA certificate chain... "

# Extract CA certificates from PKCS12 bundle
# This extracts the raw output including bag attributes
openssl pkcs12 -in "$p12name" "$LEGACY" -cacerts -nokeys -passin pass: 2>/dev/null > temp_ca_raw.pem

if [[ $? -ne 0 ]]; then
    echo "FAIL: Could not extract CA certificates from PKCS#12 file."
    rm -f temp_ca_raw.pem
    exit 1
fi

# Clean up the output: remove bag attributes, subject/issuer lines, and empty lines
# Keep only the PEM certificate blocks
awk '
    /BEGIN CERTIFICATE/,/END CERTIFICATE/ {
        print
    }
' temp_ca_raw.pem > easyroam_root_ca.pem

# Verify we got valid CA certificate(s)
if [[ ! -s easyroam_root_ca.pem ]]; then
    echo "FAIL: No CA certificates found in PKCS#12 file."
    if [[ "$DEBUG" == true ]]; then
        echo "  Raw CA extraction output:"
        cat temp_ca_raw.pem
    fi
    rm -f temp_ca_raw.pem
    exit 1
fi

# Verify the first certificate in the chain is valid
if ! openssl x509 -in easyroam_root_ca.pem -noout 2>/dev/null; then
    echo "FAIL: Extracted CA certificate is invalid."
    if [[ "$DEBUG" == true ]]; then
        echo "  Content of easyroam_root_ca.pem:"
        cat easyroam_root_ca.pem
    fi
    rm -f temp_ca_raw.pem
    exit 1
fi

# Count how many certificates are in the chain
cert_count=$(grep -c "BEGIN CERTIFICATE" easyroam_root_ca.pem)

if [[ "$DEBUG" == true ]]; then
    echo "Done ($cert_count certificate(s) in chain)"
    echo "  CA Certificate Details:"
    
    # Split and show each certificate in the chain
    csplit -s -z easyroam_root_ca.pem '/-----BEGIN CERTIFICATE-----/' '{*}' 2>/dev/null
    for cert_file in xx*; do
        if [[ -s "$cert_file" ]]; then
            echo "  ---"
            openssl x509 -in "$cert_file" -noout -subject -issuer 2>/dev/null
        fi
        rm -f "$cert_file"
    done
else
    echo "Done ($cert_count certificate(s))"
fi

# Clean up temporary file
rm -f temp_ca_raw.pem

# Set proper file permissions
echo -n "Setting file permissions... "
chmod 700 "$outputdir"
chmod 644 "$outputdir/easyroam_client_cert.pem"
chmod 644 "$outputdir/easyroam_root_ca.pem"
chmod 600 "$outputdir/easyroam_client_key.pem"
chmod 600 "$outputdir/$p12name"
echo "Done"

# Delete existing nm configurations if replacing
if [[ "$REPLACE_EXISTING" == true ]]; then
    echo -n "Delete existing connection '$CONNECTION_NAME'... "
    nmcli connection delete "$CONNECTION_NAME" >/dev/null 2>&1
    echo "Done"
fi

# Create new nm network profile
echo -n "Create new NetworkManager profile '$CONNECTION_NAME'... "
nmcli_output=$(nmcli connection add type wifi ifname "$interface" con-name "$CONNECTION_NAME" ssid eduroam \
    wifi-sec.key-mgmt wpa-eap 802-1x.eap tls 802-1x.identity "$cn" \
    802-1x.client-cert "$outputdir/easyroam_client_cert.pem" \
    802-1x.ca-cert "$outputdir/easyroam_root_ca.pem" \
    802-1x.private-key "$outputdir/easyroam_client_key.pem" \
    802-1x.private-key-password "$PKPW" 2>&1)

if [[ $? -ne 0 ]]; then
    echo "FAIL"
    echo "Could not create network configuration."
    if [[ "$DEBUG" == true ]]; then
        echo "  NetworkManager error:"
        echo "  $nmcli_output"
    fi
    exit 1
fi
echo "Done"

echo
echo "=============================================="
echo "SUCCESS: eduroam configuration completed!"
echo "=============================================="
echo
echo "Connection name: $CONNECTION_NAME"
echo "SSID: eduroam"
echo "Identity: $cn"
echo "Interface: $interface"
echo "Certificates stored in: $outputdir"
echo

# Show all eduroam connections
echo "=== All eduroam Connections ==="
nmcli connection show | head -1
nmcli connection show | grep -i "eduroam\|easyroam" || echo "No connections found"
echo "================================"
echo

if [[ "$REPLACE_EXISTING" == false ]] && [[ -n "$existing_connections" ]]; then
    echo "You now have multiple eduroam connections."
    echo
    echo "To use the new connection:"
    echo "  nmcli connection up $CONNECTION_NAME"
    echo
    echo "To switch back to an old connection:"
    echo "  nmcli connection down $CONNECTION_NAME"
    echo "  nmcli connection up <old-connection-name>"
    echo
fi

echo "To connect automatically to eduroam:"
echo "  The connection will activate when eduroam is in range"
echo
echo "To manually connect:"
echo "  nmcli connection up $CONNECTION_NAME"
echo
echo "To check connection status:"
echo "  nmcli connection show --active"
echo
echo "To view logs (in case of issues):"
echo "  journalctl -u NetworkManager -f"
echo

if [[ "$DEBUG" == false ]]; then
    echo "Tip: Run with debug mode enabled if you encounter issues"
    echo
fi

echo "You should now be able to connect to eduroam!"
echo
