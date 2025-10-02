# Fastlane Match Setup Guide

This guide walks you through setting up Fastlane Match for centralized code signing.

## 📦 What is Match?

Match is fastlane's solution for sharing one code signing identity across your team:
- Stores certificates & profiles in a private git repo
- Keeps everything in sync
- Works perfectly with CI/CD
- Prevents "works on my machine" signing issues

## ⚡ Quick Start (SSH)

If you already have SSH access to GitHub:

```bash
# 1. Initialize Match
cd /path/to/Zunlo
fastlane match init
# Select: git
# Enter: git@github.com:YOUR_USERNAME/certificates.git

# 2. Verify SSH access
ssh -T git@github.com

# 3. Generate certificates
fastlane match appstore
# Enter a passphrase when prompted (save it!)

# 4. Save passphrase
echo 'export MATCH_PASSWORD="your_passphrase"' >> ~/.zshrc
source ~/.zshrc

# 5. Disable automatic signing in Xcode
# Project → Target → Signing & Capabilities → Uncheck "Automatically manage signing"

# 6. Test it
fastlane beta
```

## 🚀 Setup Steps (Detailed)

### 1. Create a Private Git Repository

**Option A: GitHub Private Repo**
```bash
# Create new private repo on GitHub
# Name: certificates (or anything you prefer)
# IMPORTANT: Must be private!
```

**Option B: Use separate branch in current repo**
```bash
git checkout -b certificates
git push -u origin certificates
git checkout main
```

### 2. Initialize Match

```bash
cd /path/to/Zunlo
fastlane match init
```

**Select storage:**
- Choose `git`
- **SSH (Recommended):** `git@github.com:YOUR_USERNAME/certificates.git`
- **HTTPS (Alternative):** `https://github.com/YOUR_USERNAME/certificates`

This creates: `fastlane/Matchfile`

### 3. Configure Matchfile

Edit `fastlane/Matchfile`:

**Using SSH (Recommended):**
```ruby
git_url("git@github.com:YOUR_USERNAME/certificates.git")

storage_mode("git")

type("appstore") # Can be: appstore, adhoc, development, enterprise

app_identifier(["net.loginode.zunloapp"])

username("marcio@loginode.net") # Your Apple ID

# Optional: Use a separate branch for certificates
# git_branch("main")

# Optional: Specific team if you have multiple
# team_id("YOUR_TEAM_ID")
```

**Using HTTPS (Alternative):**
```ruby
git_url("https://github.com/YOUR_USERNAME/certificates")
# ... rest of configuration
```

### 3a. SSH Setup (If Using SSH)

**Verify SSH access:**
```bash
# Test GitHub SSH connection
ssh -T git@github.com
# Should see: "Hi YOUR_USERNAME! You've successfully authenticated..."
```

**If SSH key not configured:**
```bash
# Generate SSH key (if needed)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add key to SSH agent
ssh-add ~/.ssh/id_ed25519

# Copy public key to clipboard
cat ~/.ssh/id_ed25519.pub | pbcopy
# Then add to GitHub: Settings → SSH and GPG keys → New SSH key
```

**Why SSH is recommended:**
- ✅ More secure than HTTPS with tokens
- ✅ Uses your existing SSH keys
- ✅ No need to manage `MATCH_GIT_BASIC_AUTHORIZATION` tokens
- ✅ Works seamlessly once SSH is configured
- ✅ Better for teams (everyone uses their own SSH keys)

### 4. Generate/Download Certificates & Profiles

**App Store (for TestFlight & App Store):**
```bash
fastlane match appstore
```

**Development (for local testing):**
```bash
fastlane match development
```

**First time run:**
- Match will ask for a **passphrase** to encrypt the repository
- **SAVE THIS PASSPHRASE** - you'll need it every time
- Store it in a password manager

**What happens:**
1. Match checks if certificates exist in git repo
2. If not, creates new ones in Apple Developer Portal
3. Downloads certificates & profiles
4. Installs them on your Mac
5. Commits them to git repo (encrypted)

### 5. Save Passphrase Securely

**Option A: Environment Variable (Recommended)**

Add to `~/.zshrc` or `~/.bash_profile`:
```bash
export MATCH_PASSWORD="your_passphrase_here"
```

Then:
```bash
source ~/.zshrc
```

**Option B: Keychain**
```bash
# Match will ask and can save to macOS Keychain
```

### 6. Disable Automatic Signing in Xcode

**For each target (Zunlo, AdStack, etc.):**

1. Open `Zunlo.xcodeproj` in Xcode
2. Select target (e.g., "Zunlo")
3. Go to **Signing & Capabilities**
4. **Uncheck** "Automatically manage signing"
5. Manually select provisioning profiles:
   - **Debug Configuration:**
     - Provisioning Profile: `match Development net.loginode.zunloapp`
   - **Release Configuration:**
     - Provisioning Profile: `match AppStore net.loginode.zunloapp`

Repeat for all targets/extensions.

### 7. Update Fastfile

Add Match to your deployment lanes:

```ruby
platform :ios do
  desc "Build and upload to TestFlight"
  lane :beta do
    # Get correct signing from Match
    match(
      type: "appstore",
      readonly: true  # Don't create new certs
    )

    increment_build_number(xcodeproj: "Zunlo.xcodeproj")

    build_app(
      scheme: "Zunlo",
      export_method: "app-store",
      configuration: "Release",
      clean: true,
      output_directory: "./build",
      output_name: "Zunlo.ipa"
    )

    upload_to_testflight(
      api_key: configure_api_key,
      skip_waiting_for_build_processing: true
    )
  end

  desc "Build and upload to TestFlight with external testing"
  lane :beta_external do
    match(type: "appstore", readonly: true)

    increment_build_number(xcodeproj: "Zunlo.xcodeproj")

    build_app(
      scheme: "Zunlo",
      export_method: "app-store",
      configuration: "Release",
      clean: true,
      output_directory: "./build",
      output_name: "Zunlo.ipa"
    )

    upload_to_testflight(
      api_key: configure_api_key,
      skip_waiting_for_build_processing: false,
      distribute_external: true,
      notify_external_testers: true,
      changelog: "Bug fixes and improvements"
    )
  end

  desc "Build for App Store submission"
  lane :release do
    validate_metadata

    match(type: "appstore", readonly: true)

    increment_build_number(xcodeproj: "Zunlo.xcodeproj")

    build_app(
      scheme: "Zunlo",
      export_method: "app-store",
      configuration: "Release",
      clean: true,
      output_directory: "./build",
      output_name: "Zunlo.ipa"
    )

    deliver(
      api_key: configure_api_key,
      skip_metadata: false,
      skip_screenshots: false,
      force: true,
      run_precheck_before_submit: false,
      submit_for_review: false
    )
  end
end
```

### 8. Test It

```bash
fastlane beta
```

## 🔐 Security Best Practices

### .gitignore

Ensure these are in `.gitignore`:
```
# Certificates & profiles (managed by Match)
fastlane/*.cer
fastlane/*.p12
fastlane/*.mobileprovision

# Never commit Match passphrase
.env

# Don't commit API keys
fastlane/api_keys/*.p8
```

### Environment Variables

**Required for all setups:**
```bash
export MATCH_PASSWORD="your_passphrase"
```

**Only required for HTTPS (not needed with SSH):**
```bash
export MATCH_GIT_BASIC_AUTHORIZATION="base64_encoded_github_token"
```

To generate `MATCH_GIT_BASIC_AUTHORIZATION`:
```bash
# Create GitHub Personal Access Token with 'repo' access
# Then encode: username:token
echo -n "your_github_username:your_token" | base64
```

## 👥 Team Setup

When a new team member joins:

```bash
# Clone the project
git clone https://github.com/YOUR_ORG/zunlo.git

# Install certificates from Match
fastlane match development
fastlane match appstore

# Enter the shared Match passphrase
```

That's it! They now have the same signing setup.

## 🤖 CI/CD Setup

### Option A: Using SSH (Recommended)

**GitHub Actions example:**
```yaml
env:
  MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}

steps:
  - name: Setup SSH for Match
    uses: webfactory/ssh-agent@v0.8.0
    with:
      ssh-private-key: ${{ secrets.MATCH_SSH_PRIVATE_KEY }}

  - name: Add GitHub to known hosts
    run: ssh-keyscan github.com >> ~/.ssh/known_hosts

  - name: Install certificates
    run: fastlane match appstore --readonly

  - name: Build and upload
    run: fastlane beta
```

**Setup steps:**
1. Generate a deploy key for your certificates repo (or use existing SSH key)
2. Add public key to certificates repo: Settings → Deploy keys → Add deploy key
3. Add private key to secrets: Settings → Secrets → New secret (`MATCH_SSH_PRIVATE_KEY`)
4. Add `MATCH_PASSWORD` to secrets

### Option B: Using HTTPS with Token

**GitHub Actions example:**
```yaml
env:
  MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
  MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_AUTH }}

steps:
  - name: Install certificates
    run: fastlane match appstore --readonly

  - name: Build and upload
    run: fastlane beta
```

**Setup steps:**
1. Generate GitHub Personal Access Token with `repo` access
2. Base64 encode: `echo -n "username:token" | base64`
3. Add to secrets: `MATCH_GIT_BASIC_AUTHORIZATION`

## 🔧 Troubleshooting

### "Certificate not found"

```bash
# Force regenerate certificates
fastlane match appstore --force_for_new_devices
```

### "Profile doesn't match certificate"

```bash
# Nuke everything and start fresh (CAREFUL!)
fastlane match nuke development
fastlane match nuke appstore

# Then regenerate
fastlane match appstore
```

### Update certificates after adding device

```bash
# For development profiles
fastlane match development --force_for_new_devices
```

### Rotate certificates

```bash
# If certificate expires or is compromised
fastlane match appstore --force
```

## 📚 Additional Resources

- [Match Documentation](https://docs.fastlane.tools/actions/match/)
- [Codesigning Guide](https://codesigning.guide/)
- [Match Best Practices](https://docs.fastlane.tools/codesigning/getting-started/)

## 🆘 Common Issues

### Issue: "Could not decrypt git repository"
**Solution:** Check `MATCH_PASSWORD` environment variable
```bash
echo $MATCH_PASSWORD  # Should output your passphrase
```

### Issue: "Git authentication failed" (SSH)
**Solutions:**
1. **Verify SSH connection:**
   ```bash
   ssh -T git@github.com
   ```
2. **Add SSH key to agent:**
   ```bash
   ssh-add ~/.ssh/id_ed25519  # or your key path
   ssh-add -l  # List loaded keys
   ```
3. **Check SSH key permissions:**
   ```bash
   chmod 600 ~/.ssh/id_ed25519
   chmod 644 ~/.ssh/id_ed25519.pub
   ```
4. **Ensure key is added to GitHub:**
   - Go to GitHub Settings → SSH and GPG keys
   - Verify your public key is listed

### Issue: "Git authentication failed" (HTTPS)
**Solution:** Generate GitHub Personal Access Token with `repo` access

### Issue: "Permission denied (publickey)" (SSH)
**Solutions:**
1. **Generate new SSH key:**
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```
2. **Add to SSH agent:**
   ```bash
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   ```
3. **Add public key to GitHub**

### Issue: Xcode can't find profile
**Solution:** Run `fastlane match appstore` to reinstall

### Issue: Certificate expired
**Solution:** Run `fastlane match appstore --force` to renew

### Issue: "Could not find action, lane or variable 'match'"
**Solution:** Ensure fastlane is up to date
```bash
bundle update fastlane
# or
gem update fastlane
```
