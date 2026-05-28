#!/usr/bin/env bash
#
# setup-signing.sh — Create a stable self-signed code-signing certificate
# for Anini in your login Keychain.
#
# Why this is needed: macOS Privacy & Security (TCC) ties permissions
# (Screen Recording, Automation, etc.) to the app's code signature.
# Xcode's default "ad-hoc" signing produces a fresh signature on every
# rebuild — so permissions silently break after each build.
#
# A stable self-signed cert solves this. The cert lives only on YOUR
# Mac, only in YOUR login Keychain, and is trusted only for code signing.
#
# Run this once per Mac. Safe to re-run — it will detect an existing cert.

set -e

CERT_NAME="Anini Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

echo "================================================================"
echo "  Anini code-signing setup"
echo "================================================================"
echo ""

# 1. Check if cert already exists
if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo "✓ Cert '$CERT_NAME' already exists in your Keychain."
    echo "  You're all set — no action needed."
    exit 0
fi

echo "Creating new self-signed certificate: $CERT_NAME"
echo ""

# 2. Generate cert + key in a temp dir
WORK=$(mktemp -d)
trap "rm -rf '$WORK'" EXIT
cd "$WORK"

cat > config.cnf <<'EOF'
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_codesign
prompt = no

[req_distinguished_name]
CN = Anini Local Signing
O  = Anini

[v3_codesign]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

echo "  → Generating RSA key pair and certificate (10-year validity)..."
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem \
    -days 3650 -nodes -config config.cnf >/dev/null 2>&1

echo "  → Packaging into PKCS12 with Apple-friendly algorithms..."
openssl pkcs12 -export -out anini.p12 \
    -inkey key.pem -in cert.pem \
    -name "$CERT_NAME" \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
    -passout pass:anini >/dev/null 2>&1

# 3. Import to login keychain
echo "  → Importing into your login Keychain..."
security import anini.p12 -k "$KEYCHAIN" -P "anini" \
    -T /usr/bin/codesign -T /usr/bin/security >/dev/null 2>&1

# 4. Trust it for code signing (will prompt for keychain password)
echo ""
echo "  → Now trusting the cert for code signing."
echo "    macOS will ask for your Mac login password — type it when prompted."
echo ""
# Use trustAsRoot (not trustRoot) so the trust setting is narrowly scoped:
# trustAsRoot lets codesign accept this self-signed leaf for the codeSign
# policy only, without elevating it to a fully-trusted root CA for anything
# else macOS might consult the user trust store for.
security add-trusted-cert -r trustAsRoot -p codeSign \
    -k "$KEYCHAIN" cert.pem

# 5. Verify
echo ""
if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo "================================================================"
    echo "  ✓ Done! '$CERT_NAME' is ready to use."
    echo "================================================================"
    echo ""
    echo "Next steps:"
    echo "  1. Run:  xcodegen generate"
    echo "  2. Open Anini.xcodeproj in Xcode"
    echo "  3. Press Cmd+B to build"
    echo "  4. Launch the app from Finder or Spotlight"
    echo ""
else
    echo "✗ Something went wrong — cert not found after import."
    echo "  Try running this script again, or set it up manually in Keychain Access:"
    echo "  Keychain Access → Certificate Assistant → Create a Certificate…"
    echo "  Use name '$CERT_NAME', type 'Self Signed Root', certificate type 'Code Signing'"
    exit 1
fi
