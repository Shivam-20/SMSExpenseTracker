# iOS Build & Distribution from Ubuntu — Full Guide

This document explains what is possible **from Ubuntu only**, what requires macOS, and provides a complete, beginner-friendly workflow that uses Ubuntu for development and management while delegating actual build & codesign steps to macOS CI runners (GitHub Actions macos-latest, MacStadium, MacinCloud, etc.). It contains step-by-step commands, example Fastlane lanes, and a full GitHub Actions workflow that will build, sign, and produce an .ipa using a macOS runner; it also explains how to fetch artifacts and attempt device install from Ubuntu with caveats.

---

## Short summary / TL;DR

- You cannot run Xcode or produce a properly signed iOS archive entirely on Ubuntu because Xcode (and Apple code signing tools / Keychain) run only on macOS.
- What you *can* do on Ubuntu: develop, run linters/tests that don't require Xcode, prepare Fastlane and CI config, create App Store Connect API keys, manage match certificate repos, and trigger CI that runs on macOS to build and sign.
- Recommended workflow for Ubuntu users: use Ubuntu for coding + CI on macOS to build/sign + TestFlight (or artifact download) for device installs.

---

## Goals of this guide

1. Show how to set up your Ubuntu machine for iOS project development tasks that are possible on Linux.  
2. Show how to prepare Fastlane config and GitHub Actions so the **actual build/sign** runs on a macOS runner.  
3. Show how to retrieve artifacts to Ubuntu and attempt device install (with clear caveats and alternatives).

---

## Prerequisites

- Apple Developer Program membership (paid) for TestFlight/App Store/Ad‑Hoc distribution.  
- A GitHub repository for your app.  
- Ubuntu machine with network access and basic dev tools.  
- Access to a macOS environment at least once for initial signing setup (or a paid macOS cloud provider such as MacinCloud / MacStadium) — this is *strongly recommended* because creating certificates/profiles initially usually requires Xcode/Keychain or developer portal interactions that are easiest from macOS.  
- Familiarity with Git and GitHub (or willingness to follow the commands below).

---

## What you can (and cannot) do on Ubuntu

Can do entirely on Ubuntu:
- Edit code, run non-Xcode unit tests (e.g., JS/Node unit tests for React Native JS layer), linting, static analysis.  
- Install and configure Fastlane (Ruby) to manage lanes, and write the Fastfile/Appfile/Matchfile.  
- Create App Store Connect API keys (in the web UI) and base64-encode them to store in CI secrets.  
- Create a private certificate repository (to store encrypted certs with match) and push commits.  
- Create GitHub Actions workflows and push them to your repo.

Cannot do (or very limited / unreliable) on Ubuntu:
- Run Xcode, xcodebuild archive, or interact with macOS Keychain for code signing.  
- Use official Apple tools to sign and notarize apps locally on Linux.  
- Reliably install modern iOS releases directly to a device from Ubuntu (installing .ipa on-device from Linux is often broken or unsupported for modern iOS versions; TestFlight or macOS-based tools are recommended).

---

## High-level recommended approach

1. Use Ubuntu for development and CI configuration.  
2. Use GitHub Actions with `runs-on: macos-latest` (or another macOS CI provider) for build & signing steps.  
3. Use Fastlane + match to manage certificates and provisioning (store encrypted certs in a private GitHub repo).  
4. CI retrieves certs, builds, exports .ipa and either uploads to TestFlight or saves artifacts.  
5. From Ubuntu you can download the artifact or install (if feasible) with libimobiledevice-based tools — otherwise use TestFlight for deploys.

---

## 1) Setup Ubuntu development environment (Ruby + Fastlane)

Recommended: use rbenv to manage Ruby, then Bundler to lock Fastlane.

Commands (example):

```bash
# Install build deps
sudo apt update
sudo apt install -y build-essential git curl autoconf bison libssl-dev libyaml-dev libreadline-dev zlib1g-dev libsqlite3-dev sqlite3

# Install rbenv and ruby-build
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
cd ~/.rbenv && src/configure && make -C src
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# Install a modern Ruby (pick a stable 3.x version)
rbenv install 3.1.2
rbenv global 3.1.2

# Install bundler
gem install bundler --no-document

# In your project root create a Gemfile to lock fastlane
cat > Gemfile <<'GEOF'
source 'https://rubygems.org'
gem 'fastlane'
GEOF

bundle install --jobs 4 --retry 3
```

Notes:
- Using system Ruby via `apt` is possible but may give older Ruby; rbenv is recommended for predictable behavior.
- After `bundle install` you can run fastlane with `bundle exec fastlane <lane>`.

---

## 2) Create an App Store Connect API Key (from any OS)

1. In App Store Connect → Users and Access → Keys → Create API Key. Give it the "App Manager" role or appropriate role for TestFlight uploads. Download the `.p8` file.  
2. Save the key id and issuer id (you'll add them to CI secrets).  
3. Base64-encode the .p8 to store in a GitHub secret (avoid raw files in the web UI):

```bash
base64 -w 0 AuthKey_ABC123.p8 > AuthKey_ABC123.p8.base64
# copy the single-line content and add to GitHub secret APP_STORE_CONNECT_KEY
```

Secrets to store in GitHub (names are examples):
- APP_STORE_CONNECT_KEY (base64-encoded .p8 file)  
- APP_STORE_CONNECT_KEY_ID  
- APP_STORE_CONNECT_ISSUER_ID

(You can add other secrets later: MATCH_PASSWORD, CERTS_REPO_TOKEN, etc.)

---

## 3) Create the private certificate repository for match

- In GitHub create a private repo (example: `your-org/ios-certificates`) to store encrypted signing artifacts that `fastlane match` will manage. Keep it private.
- Note: match will store encrypted files (using `MATCH_PASSWORD`). You must run match (initial creation) from a macOS environment (or a macOS CI runner temporarily) since certificate/profile creation typically needs Apple Developer portal interaction and Keychain.

---

## 4) Create initial certificates & provisioning profiles (macOS required)

**Important:** this step normally requires macOS (Keychain + Xcode or interactive fastlane) and Apple ID 2FA handling. Options:

Option A — Use a mac (recommended):
- On a Mac, install fastlane, configure your `Matchfile` with the `git_url` to the certs repo, and run:

```bash
export MATCH_GIT_URL="https://github.com/your-org/ios-certificates.git"
# run the initial creation (will ask Apple ID + 2FA)
bundle exec fastlane match development --git_url "$MATCH_GIT_URL"
bundle exec fastlane match appstore --git_url "$MATCH_GIT_URL"
```

- Choose a strong `MATCH_PASSWORD` when prompted; this password is used to encrypt the certs in the repo and must be put into your CI secrets.

Option B — Use a macOS cloud provider temporarily (MacinCloud / MacStadium):
- Sign up for a temporary macOS VM, run the commands above, then disconnect.

Option C — Try creating certs with an ephemeral GitHub Actions macos runner (advanced):
- It's possible to create a one-off workflow that runs on `macos-latest` and runs `fastlane match` without `readonly`. However, you will need to provide Apple ID credentials and be ready for 2FA — this is more complex and not recommended for beginners. Prefer Option A or B.

---

## 5) Fastlane config examples (Appfile / Matchfile / Fastfile)

Place `fastlane` directory at your repo root and add these example files (edit placeholders).

fastlane/Appfile:

```ruby
app_identifier("com.example.app")
apple_id("you@company.com")
team_id("YOUR_TEAM_ID") # optional
```

fastlane/Matchfile:

```ruby
git_url("https://github.com/your-org/ios-certificates.git")
# Optional: storage_mode("git")
```

fastlane/Fastfile (example lanes used by CI):

```ruby
default_platform(:ios)

platform :ios do
  desc "CI: build and upload to TestFlight"
  lane :ci do
    api_key = app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_filepath: "./AuthKey.p8"
    )

    # Fetch signing (readonly: true in CI)
    match(type: "appstore", readonly: true, git_url: ENV["MATCH_GIT_URL"]) 

    build_app(
      workspace: ENV["WORKSPACE"] || "YourApp.xcworkspace",
      scheme: ENV["SCHEME"] || "YourScheme",
      export_method: "app-store",
      output_directory: "./build",
      clean: true
    )

    upload_to_testflight(api_key: api_key)
  end

  desc "Build an Ad-Hoc IPA (for device installs)"
  lane :adhoc do
    match(type: "adhoc", readonly: true, git_url: ENV["MATCH_GIT_URL"]) 
    build_app(
      workspace: ENV["WORKSPACE"] || "YourApp.xcworkspace",
      scheme: ENV["SCHEME"] || "YourScheme",
      export_method: "ad-hoc",
      output_directory: "./build",
      clean: true
    )
    UI.message("IPA created in ./build")
  end
end
```

Notes: `app_store_connect_api_key` expects the `.p8` on disk; CI will decode the base64 secret into `./AuthKey.p8` before fastlane runs.

---

## 6) GitHub Actions workflow (full example)

Add `.github/workflows/ci-macos.yml` to your repo; this job runs on macOS and performs the signed build.

```yaml
name: iOS Build & TestFlight
on:
  push:
    branches: [ master, main ]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.1'

      - name: Install bundle
        run: |
          gem install bundler
          bundle install --jobs 4 --retry 3

      - name: Configure git for certificates repo
        run: |
          # Use a PAT stored in CERTS_REPO_TOKEN so match can clone the private certs repo
          git config --global url."https://x-access-token:${{ secrets.CERTS_REPO_TOKEN }}@github.com/".insteadOf "https://github.com/"

      - name: Decode App Store Connect key
        env:
          APP_STORE_CONNECT_KEY: ${{ secrets.APP_STORE_CONNECT_KEY }}
        run: |
          echo "$APP_STORE_CONNECT_KEY" | base64 --decode > ./AuthKey.p8

      - name: Run fastlane CI lane
        env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_URL: https://github.com/your-org/ios-certificates.git
          APP_STORE_CONNECT_KEY_ID: ${{ secrets.APP_STORE_CONNECT_KEY_ID }}
          APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
          WORKSPACE: YourApp.xcworkspace
          SCHEME: YourScheme
        run: |
          bundle exec fastlane ios ci

      - name: Upload IPA artifact
        uses: actions/upload-artifact@v4
        with:
          name: ios-ipa
          path: ./build/*.ipa
```

Secrets to add to the repository (Repository → Settings → Secrets):
- CERTS_REPO_TOKEN — PAT (or deploy key token) that can read the private `ios-certificates` repo.  
- MATCH_PASSWORD — the password you chose when creating match entries.  
- APP_STORE_CONNECT_KEY (base64-encoded .p8)  
- APP_STORE_CONNECT_KEY_ID  
- APP_STORE_CONNECT_ISSUER_ID

Notes:
- The `git config` trick replaces `https://github.com` fetches with an x-access-token URL so the runner can read the private certs repo. Keep this token minimal-scope and rotate regularly.
- `readonly: true` prevents CI from attempting to create or push certs; initial cert creation must be done once by you on macOS (or via a controlled macOS job that you trust).

---

## 7) Downloading build artifacts to Ubuntu

After the workflow runs, the `.ipa` is saved as an artifact. You can download it via the GitHub web UI or the GitHub CLI on Ubuntu:

```bash
# List recent workflow runs
gh run list --repo YOUR_USER/YOUR_REPO --limit 10

# Download artifact from a run (replace RUN_ID and artifact name)
gh run download <run-id> --name ios-ipa --repo YOUR_USER/YOUR_REPO

# or use the web UI to download the 'ios-ipa' artifact
```

You will get a `.ipa` file in your Ubuntu machine. Keep in mind the .ipa is signed for the provisioning profile you used (ad-hoc or app-store).

---

## 8) Installing the .ipa onto a physical iPhone from Ubuntu (caveats)

Short answer: unreliable for modern iOS. Apple officially expects installs via Xcode / TestFlight / Apple Configurator (macOS) or MDM. Third-party Linux tools exist but often fail on recent iOS versions.

If you still want to try from Ubuntu:

1. Install libimobiledevice tools (may be outdated on some distros):

```bash
sudo apt update
sudo apt install -y libimobiledevice6 libimobiledevice-utils usbmuxd libplist-utils
# ideviceinstaller package may not exist on your distro; if not, build from source
```

2. (Optional) Build & install ideviceinstaller if not packaged:

```bash
# Install build deps
sudo apt install -y autoconf automake libtool pkg-config libusb-1.0-0-dev libplist-dev libusbmuxd-dev libimobiledevice-dev

git clone https://github.com/libimobiledevice/ideviceinstaller.git
cd ideviceinstaller
./autogen.sh
make
sudo make install
```

3. Connect your device via USB and run:

```bash
idevice_id -l                 # lists attached device UDIDs
ideviceinfo                   # shows info (works if pairing ok)
ideviceinstaller -i ./YourApp.ipa
```

Warnings:
- `ideviceinstaller` and `libimobiledevice` may not work on latest iOS releases due to protocol/Apple changes. Use TestFlight or macOS tools if the install fails.  
- The .ipa must be signed with an Ad‑Hoc or Development provisioning profile that includes the device UDID. If the .ipa is signed for App Store, it cannot be installed directly to device with ideviceinstaller.

Recommendation: prefer TestFlight (upload with `upload_to_testflight`) and install via the TestFlight app on the iPhone.

---

## 9) Alternative: remote macOS runner you control

If you cannot use GitHub Actions macos runner for any reason, consider renting a macOS VM from MacinCloud or MacStadium and run the fastlane lanes there (trigger via SSH) — the full signing process works on a mac and avoids the ideviceinstaller pitfalls.

---

## 10) Security & best practices

- Never commit private certificates or keys to your main app repo. Use `fastlane match` which encrypts them and stores in a separate private repo.  
- Use `readonly: true` in CI to prevent accidental certificate changes from CI.  
- Store secrets in GitHub Secrets or your CI secret store; do not echo secrets in logs.  
- Use an App Store Connect API key (.p8) for CI uploads rather than interactive Apple ID + password.  

---

## 11) Troubleshooting common errors

- "No matching provisioning profile" → Ensure `app_identifier` in Appfile matches your Xcode bundle identifier and that profile includes the bundle id. Regenerate profiles via match on a mac if needed.  
- Fastlane match clone fails → Check `CERTS_REPO_TOKEN` has repo read access and that `MATCH_PASSWORD` is correct.  
- 2FA prompts in CI → Do initial fastlane/match runs interactively on a mac; use API key for uploads.

---

## 12) Example quick checklist to go from Ubuntu dev to TestFlight

1. On Ubuntu: implement code, push to GitHub.  
2. Create `fastlane/` files and push them.  
3. Create private `ios-certificates` repo.  
4. On a Mac (or via MacinCloud): run `bundle exec fastlane match appstore` and `match development` at least once to populate certs repo (store `MATCH_PASSWORD` as secret).  
5. Add the App Store Connect API key and other secrets to GitHub.  
6. Push the GitHub Actions workflow above.  
7. Open a PR or push to `main/master` to trigger CI; CI will build and upload to TestFlight.  
8. Download artifact or install via TestFlight.

---

## 13) If you want, I can (pick one):
- Add a `fastlane/` starter (Appfile + Matchfile + Fastfile) to your repo with your workspace/scheme and bundle id filled in (I will need them).  
- Add a `.github/workflows/ci-macos.yml` workflow to your repo and fill environment variables (I will need your `MATCH_GIT_URL` and secret names).  
- Create a small temporary macOS Actions job to run initial `match` (advanced; you'll need to provide Apple ID credentials and handle 2FA) — not recommended for beginners.

---

## 14) References and further reading

- Fastlane docs: https://docs.fastlane.tools  
- match docs: https://docs.fastlane.tools/actions/match/  
- Upload to TestFlight: https://docs.fastlane.tools/actions/upload_to_testflight/  
- GitHub Actions macOS runner: https://docs.github.com/actions/using-github-hosted-runners/about-github-hosted-runners  
- libimobiledevice (Linux tooling): https://libimobiledevice.org/

---

End of guide.

If you want this file modified or want me to also create the fastlane templates and GitHub Actions YAML inside this repo now, say which lane names / workspace / scheme / bundle identifier to use and I will add them next.
