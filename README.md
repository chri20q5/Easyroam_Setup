# Easyroam Setup Script for Linux

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

Automated setup script for connecting to eduroam using easyroam certificates on Linux with NetworkManager.

##  About

This script is a modified version of the [original easyroam setup script](https://github.com/jahtz/easyroam-linux) by [@jahtz](https://github.com/jahtz), enhanced with improved CA certificate extraction and better error handling.

###  Key Modifications

-  **Fixed CA certificate extraction**: Properly parses CA certificates from .p12 files, resolving issues where generic certificates were being used
-  **Enhanced validation**: Validates each extracted certificate and key
-  **Better error handling**: Clear error messages at each step
-  **Smart connection handling**: Choose to replace or keep existing connections
-  **Debug mode**: Optional detailed output for troubleshooting
-  **Security improvements**: Proper file permissions on private keys
-  **Multi-certificate support**: Handles certificate chains with multiple intermediate CAs

## Prerequisites

- Linux system with NetworkManager
- OpenSSL installed
- Wireless network interface
- Your easyroam .p12 certificate file

### Check if you have the requirements:

```bash
# Check NetworkManager
nmcli --version

# Check OpenSSL
openssl version

# Check wireless interfaces
ls /sys/class/net/*/wireless
```

##  Quick Start

### 1. Get your .p12 certificate

1. Visit [easyroam.de](https://www.easyroam.de)
2. Log in with your university credentials
3. Click on Linux (Manual setup for Linux Devices) and name the profile
3. Download your certificate (.p12 file)

### 2. Download and run the script

```bash
# Download the script
wget https://raw.githubusercontent.com/chri20q5/Easyroam_Setup/main/easyroam_setup.sh

# Make it executable
chmod +x easyroam_setup.sh

# Run it
./easyroam_setup.sh
```

### 3. Follow the prompts

The script will guide you through:
- Selecting your .p12 file
- Choosing where to store certificates
- Handling existing connections (if any)
- Selecting your WiFi interface
- Setting up the connection

### 4. Success (hopefully)
If everything went correct, you can now connect to the eduroam network in your wifi manager

##  Detailed Usage

### First Time Setup

If you don't have any existing eduroam connections, the script will:
1. Extract certificates from your .p12 file
2. Create a new connection named "easyroam"
3. Configure it to connect to eduroam automatically

### Already Have an Eduroam Connection?

The script will detect existing connections and offer choices:

#### Option 1: Replace Existing
- Deletes your old connection
- Creates a new one with the same name
- All settings updated with new certificates
- **Choose this if**: Your old connection isn't working

#### Option 2: Keep Both
- Creates a new connection with a different name
- Keeps your existing connection intact
- You can switch between them for testing
- **Choose this if**: You want to test before fully switching

#### Option 3: Exit
- No changes made to your system

### Example: Testing Alongside Existing Connection

```bash
# Run the script
./easyroam_setup.sh

# When prompted, choose Option 2
# Name it something like: easyroam-test

# After setup, connect to test it
nmcli connection up easyroam-test

# Watch logs for any issues
journalctl -u NetworkManager -f

# If it works, you can delete the old one
nmcli connection delete old-connection-name
```

##  Troubleshooting

### Enable Debug Mode

When running the script, enable debug mode to see detailed information:

```bash
./easyroam_setup.sh
# When prompted: "Enable debug mode? [y/N]:" press 'y'
```

### Common Issues

####  "No CA certificates found"

**Solution**: Your .p12 file might be corrupted or in an unsupported format. Try downloading it again from easyroam.de.

####  "Could not extract client certificate"

**Solution**: This could be an OpenSSL version issue. The script automatically tries both legacy and modern formats. If both fail, check:
```bash
openssl version
# Should be 1.1.0 or newer
```

####  Connection authenticates but no internet

**Solution**: This is usually a network issue, not a certificate issue. Check:
```bash
# Verify you're connected
nmcli connection show --active

# Check IP address
ip addr show

# Try pinging the gateway
ip route | grep default
ping <gateway-ip>
```

####  "Authentication failed" in logs

**Solution**: 
1. Verify your certificate is valid and not expired:
   ```bash
   openssl x509 -in ~/.cert/easyroam/easyroam_client_cert.pem -noout -dates
   ```
2. Check the identity (CN) matches what's expected:
   ```bash
   openssl x509 -in ~/.cert/easyroam/easyroam_client_cert.pem -noout -subject
   ```

### View Connection Logs

```bash
# Real-time logs
journalctl -u NetworkManager -f

# Recent logs
journalctl -u NetworkManager -n 100

# Search for specific errors
journalctl -u NetworkManager | grep -i "auth\|cert\|tls"
```

### Manual Connection Testing

```bash
# List all connections
nmcli connection show

# Try connecting manually
nmcli connection up easyroam

# Check connection details
nmcli connection show easyroam

# Check active connections
nmcli connection show --active
```

##  Managing Multiple Connections

### List All Connections

```bash
nmcli connection show | grep eduroam
```

### Switch Between Connections

```bash
# Disconnect current
nmcli connection down easyroam-old

# Connect to new
nmcli connection up easyroam-new
```

### Delete Old Connection

```bash
# After confirming new one works
nmcli connection delete easyroam-old
```

### Compare Configurations

Use the included helper script:

```bash
./compare_eduroam_profiles.sh
```

##  File Locations

### Certificates

By default, certificates are stored in:
```
~/.cert/easyroam/
├── easyroam_client_cert.pem    # Your client certificate
├── easyroam_client_key.pem     # Your private key (encrypted)
├── easyroam_root_ca.pem        # CA certificate chain
└── your-certificate.p12         # Original file (backup)
```

### NetworkManager Configuration

Connection profiles are stored in:
```
/etc/NetworkManager/system-connections/easyroam.nmconnection
```

### File Permissions

The script automatically sets secure permissions:
- Directory: `700` (only you can access)
- Certificates: `644` (readable by all, writable by you)
- Private key: `600` (only you can access)

### Tested Distributions

- Fedora 41, 42

##  Advanced Usage

### Custom Certificate Directory

```bash
# When prompted for output directory, specify:
/custom/path/to/certs
```

##  Contributing

Contributions are welcome! Here's how you can help:

### Reporting Issues

1. Enable debug mode when running the script
2. Save the complete output
3. [Open an issue](https://github.com/chri20q5/Easyroam_Setup/issues) with:
   - Your Linux distribution and version
   - OpenSSL version
   - NetworkManager version
   - Complete debug output (remove sensitive info!)

### Submitting Improvements

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Make your changes
4. Test on at least one Linux distribution
5. Commit with clear messages (`git commit -am 'Add improvement'`)
6. Push to the branch (`git push origin feature/improvement`)
7. Open a Pull Request

### Testing

Before submitting:
- Test with the test script first
- Test on a fresh system if possible
- Verify both "replace" and "keep both" options work
- Check debug mode produces useful output

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

Original work Copyright (c) 2024 jahtz  
Modified work Copyright (c) 2025 chri20q5

##  Credits

### Original Author
- **[@jahtz](https://github.com/jahtz)** - Original easyroam-linux script
- Repository: [jahtz/easyroam-linux](https://github.com/jahtz/easyroam-linux)

### Modifications
- **[@chri20q5](https://github.com/chri20q5)** - CA certificate extraction improvements and enhanced error handling (with the help of Claude sonnet 4.5)

##  Useful Links

- [Easyroam Official Website](https://www.easyroam.de/)
- [DFN Homepage](https://www.dfn.de/)
- [Original Script Repository](https://github.com/jahtz/easyroam-linux)
- [NetworkManager Documentation](https://networkmanager.dev/)
- [eduroam Homepage](https://eduroam.org/)
- [OpenSSL Documentation](https://www.openssl.org/docs/)

##  Disclaimer

This script is provided as-is for educational and convenience purposes. Always:
- Verify certificate authenticity
- Follow your university's IT security policies
- Keep your .p12 file secure and private
- Regularly update your certificates when they expire

##  Support

- **GitHub Issues**: [Report a bug or request a feature](https://github.com/chri20q5/Easyroam_Setup/issues)
- **Original Script Issues**: [jahtz/easyroam-linux](https://github.com/jahtz/easyroam-linux/issues)
- **easyroam Support**: Check your university's IT help desk

---

**Made for students struggling with eduroam on Linux**
