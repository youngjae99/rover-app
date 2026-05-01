# Code signing + notarization

This guide is the recipe for switching `Rover.app` from ad-hoc signing
(today's default — Gatekeeper requires a right-click → Open) to full
**Developer ID + Apple notarization** so the DMG installs cleanly with
a normal double-click on any Mac.

The release workflow (`.github/workflows/release.yml`) is already
wired for both modes. As long as the six secrets below are absent, the
workflow keeps producing ad-hoc DMGs. Once you fill them in, the next
tag push automatically signs + notarizes + staples.

---

## 0. Prerequisites

- An [Apple Developer Program](https://developer.apple.com/programs/)
  membership ($99/year, individual or organization).
- macOS 14 or later (matches the CI runner so the local recipe works
  too).
- Command Line Tools (`xcode-select --install`).

---

## 1. Issue a Developer ID Application certificate

This certificate is the identity codesign uses to claim "yes, this
binary really came from me".

1. Open **Keychain Access → Certificate Assistant → Request a
   Certificate From a Certificate Authority…**
2. Fill in your email + name. Choose **Saved to disk**. Save the
   `.certSigningRequest` (CSR) somewhere.
3. Sign in to https://developer.apple.com/account/resources/certificates/list
4. Click **+** → **Developer ID Application** → upload the CSR. Apple
   issues a `.cer` file.
5. Double-click the `.cer` to install it into Keychain Access (login
   keychain).

Then export it as a `.p12` so CI can import it:

1. In Keychain Access, expand the new "Developer ID Application: Your
   Name" entry to reveal its private key.
2. Select **both** the certificate row **and** the private key row at
   once.
3. Right-click → **Export 2 items… → .p12**. Pick a password (you'll
   need it again as `APPLE_DEVELOPER_ID_CERT_PASSWORD`).

The exact identity string codesign expects looks like:

```
Developer ID Application: Your Name (TEAMID1234)
```

Find yours with:

```bash
security find-identity -v -p codesigning
```

That string becomes `APPLE_DEVELOPER_ID_IDENTITY`.

---

## 2. Create a Notary API key

Notarization is gated behind App Store Connect API keys (not the
older `altool` username/password flow — that's deprecated).

1. Go to https://appstoreconnect.apple.com/access/api
2. Switch to the **Keys** tab.
3. Generate a new key with the **Developer** role. Apple gives you:
   - A `.p8` file (downloadable **once** — re-issue if you lose it)
   - A **Key ID** (10 chars, e.g. `ABCDE12345`)
   - An **Issuer ID** (UUID, shown above the key list)

Test it locally before adding to CI:

```bash
xcrun notarytool history \
  --key /path/to/AuthKey_ABCDE12345.p8 \
  --key-id ABCDE12345 \
  --issuer 12345678-1234-1234-1234-123456789012
```

Empty list = working. Anything else = check the error.

---

## 3. Encode for GitHub Secrets

GitHub Secrets store strings. The `.p12` and `.p8` are binary, so
base64 them first:

```bash
base64 < ~/Downloads/RoverDeveloperID.p12 | pbcopy   # paste into APPLE_DEVELOPER_ID_CERT_P12_BASE64
base64 < ~/Downloads/AuthKey_ABCDE12345.p8 | pbcopy  # paste into APPLE_NOTARY_API_KEY_P8_BASE64
```

> Use plain `base64` (no `-w 0` on macOS — its `base64` doesn't have
> that flag and a wrapped value is fine since GitHub joins lines on
> read).

---

## 4. Set the six GitHub Secrets

Go to **Settings → Secrets and variables → Actions → New repository
secret** in the rover-app repo and add all six:

| Secret name | Value |
|---|---|
| `APPLE_DEVELOPER_ID_CERT_P12_BASE64` | base64 of the `.p12` |
| `APPLE_DEVELOPER_ID_CERT_PASSWORD` | the password you chose at step 1 |
| `APPLE_DEVELOPER_ID_IDENTITY` | `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_NOTARY_API_KEY_P8_BASE64` | base64 of the `.p8` |
| `APPLE_NOTARY_API_KEY_ID` | 10-char key ID |
| `APPLE_NOTARY_API_ISSUER_ID` | issuer UUID |

The workflow's `Detect signing secrets` step requires **all six**.
Missing any one falls back to the ad-hoc path silently.

---

## 5. Cut a release

```bash
git tag v0.3.0
git push origin v0.3.0
```

The workflow will:

1. Decode + import the cert into a temporary keychain.
2. Build `Rover.app` with `--options=runtime --timestamp` and the
   Developer ID identity (`build.sh` / `package.sh` flip into Developer
   ID mode when `CODESIGN_IDENTITY` is set).
3. Sign the DMG.
4. `xcrun notarytool submit Rover.dmg --wait` (typically ~5 minutes).
5. `xcrun stapler staple Rover.dmg` so first-launch checks work even
   offline.
6. `spctl -a -t open` against the DMG — what an end user's machine
   will run when they double-click.
7. Delete the temp keychain + key files.
8. Upload the DMG to the GitHub Release.

If notarization fails, `notarytool submit --wait` exits non-zero and
the workflow stops before publishing — so a broken release never
ships.

---

## 6. Local signed builds (optional)

You can reproduce the CI sign + notarize locally:

```bash
cd RoverApp
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_KEY_PATH=~/Downloads/AuthKey_ABCDE12345.p8
export NOTARY_KEY_ID=ABCDE12345
export NOTARY_ISSUER_ID=12345678-1234-1234-1234-123456789012
./package.sh
```

`package.sh` will sign, notarize, and staple in place. Without the
notary env vars it'll sign and skip the notarization step (the DMG
will still trip Gatekeeper).

---

## Troubleshooting

**`security: SecKeychainItemImport: User interaction is not allowed.`**
The keychain isn't unlocked. The workflow handles this; locally, run
`security unlock-keychain` first.

**`The signature of the binary is invalid.` during notarytool**
Usually means a nested bundle (the SPM resource bundle at
`Rover.app/RoverApp_RoverApp.bundle`) isn't signed. `build.sh` signs
it explicitly when `CODESIGN_IDENTITY` is set — make sure that path
fired.

**`A new agreement must be signed`**
Apple bumped a Developer Program agreement; the account holder needs
to log in to App Store Connect and accept it. Notarization is blocked
until then.

**Notarization succeeds but Gatekeeper still complains**
Did the DMG get stapled? Run `xcrun stapler validate Rover.dmg`. If it
says "does not have a ticket stapled", the staple step didn't run —
re-run notarytool with `--wait` and re-staple.
