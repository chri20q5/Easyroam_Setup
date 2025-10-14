Easyroam NetworkManager Setup Script
Copyright 2024 Original work by jahtz (https://github.com/jahtz)
Copyright 2025 Modified work by chri20q5 (https://github.com/chri20q5)

This product includes software developed by jahtz.
Original repository: https://github.com/jahtz/easyroam-linux

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

================================================================================

MODIFICATIONS IN THIS VERSION:

This version includes the following enhancements and fixes:

1. Improved CA certificate extraction from PKCS#12 files
   - Fixed issue where generic certificates were used instead of actual CA certs
   - Properly parses and cleans certificate chain data
   - Handles multiple certificates in the chain

2. Enhanced error handling and validation
   - Validates each extracted certificate and private key
   - Clear error messages at each step
   - Verifies certificate chain integrity

3. User experience improvements
   - Interactive handling of existing connections
   - Option to replace or create alongside existing profiles
   - Debug mode for troubleshooting
   - Improved output formatting

4. Security enhancements
   - Proper file permissions on private keys (600)
   - Secure directory permissions (700)

5. Better compatibility
   - Handles both legacy and modern OpenSSL versions
   - Works across multiple Linux distributions

Date of modifications: 2025-01-14