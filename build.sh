#!/usr/bin/env bash
# =============================================================================
# MoneyFlow — build.sh
# Usage: chmod +x build.sh && ./build.sh
# =============================================================================

set -euo pipefail

# ─── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "  ${CYAN}›${RESET} $*"; }
success() { echo -e "  ${GREEN}✔${RESET} $*"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
error()   { echo -e "\n  ${RED}✖ ERROR:${RESET} $*\n"; exit 1; }
step()    { echo -e "\n  ${BOLD}${CYAN}── Step $1: $2${RESET}"; }
divider() { echo -e "  ${BOLD}──────────────────────────────────────────────${RESET}"; }

# ─── Config (from your Firebase files — do NOT change these) ──────────────────
BUNDLE_ID="co.tpcreative.moneyflow.app"
ANDROID_PACKAGE="co.tpcreative.moneyflow.app"
WEB_CLIENT_ID="382775998205-0apkrdavr3oe2ia50j3vfhebt8adbh2k.apps.googleusercontent.com"
REVERSED_CLIENT_ID="com.googleusercontent.apps.382775998205-gmh0c7kk43ddmnp3ir7orbc5asp7bdjf"
FIREBASE_PROJECT_ID="moneyflow-ddc15"

# ─── Fill these in before first iOS build ─────────────────────────────────────
TEAM_ID="XXXXXXXXXX"                         # Apple Developer Team ID
PROVISIONING_PROFILE_NAME="MoneyFlow AdHoc"  # Exact name in Apple portal

# ─── Android keystore (fill in before release build) ──────────────────────────
KEYSTORE_PATH="android/app/keystore.jks"
KEYSTORE_ALIAS="moneyflow"
KEYSTORE_STORE_PASS="your_store_password"
KEYSTORE_KEY_PASS="your_key_password"

GOOGLE_SERVICES_ANDROID="google-services.json"
GOOGLE_SERVICES_IOS="GoogleService-Info.plist"

IOS_RUNNER_DIR="ios/Runner"
ANDROID_APP_DIR="android/app"

# =============================================================================
# SHARED STEPS
# =============================================================================

step_check_deps() {
  step "1" "Check dependencies"
  local ok=true
  for cmd in flutter git; do
    if command -v "$cmd" &>/dev/null; then
      success "$cmd  $(command -v $cmd)"
    else
      warn "$cmd not found — please install it"
      ok=false
    fi
  done
  $ok || error "Missing required tools above. Install them and retry."
}

step_flutter_setup() {
  step "2" "Flutter clean & pub get"
  info "flutter clean"
  flutter clean
  info "flutter pub get"
  flutter pub get
  success "Flutter ready"
}

# =============================================================================
# ANDROID STEPS
# =============================================================================

# Patches android/app/build.gradle.kts with correct package + compileSdk 35
step_android_patch_gradle() {
  local gradle="android/app/build.gradle.kts"
  if [[ ! -f "$gradle" ]]; then
    warn "$gradle not found — skipping patch"
    return
  fi

  # Fix namespace & applicationId
  sed -i '' \
    "s|namespace = \".*\"|namespace = \"$ANDROID_PACKAGE\"|g" \
    "$gradle" 2>/dev/null || \
  sed -i \
    "s|namespace = \".*\"|namespace = \"$ANDROID_PACKAGE\"|g" \
    "$gradle"

  sed -i '' \
    "s|applicationId = \".*\"|applicationId = \"$ANDROID_PACKAGE\"|g" \
    "$gradle" 2>/dev/null || \
  sed -i \
    "s|applicationId = \".*\"|applicationId = \"$ANDROID_PACKAGE\"|g" \
    "$gradle"

  # Fix compileSdk — replace flutter.compileSdkVersion or any number with 35
  sed -i '' \
    "s|compileSdk = .*|compileSdk = 35|g" \
    "$gradle" 2>/dev/null || \
  sed -i \
    "s|compileSdk = .*|compileSdk = 35|g" \
    "$gradle"

  # Fix targetSdk
  sed -i '' \
    "s|targetSdk = .*|targetSdk = 35|g" \
    "$gradle" 2>/dev/null || \
  sed -i \
    "s|targetSdk = .*|targetSdk = 35|g" \
    "$gradle"

  # Fix minSdk
  sed -i '' \
    "s|minSdk = .*|minSdk = 21|g" \
    "$gradle" 2>/dev/null || \
  sed -i \
    "s|minSdk = .*|minSdk = 21|g" \
    "$gradle"

  # Ensure google-services plugin is present
  if ! grep -q "com.google.gms.google-services" "$gradle"; then
    sed -i '' \
      "s|id(\"com.android.application\")|id(\"com.android.application\")\n    id(\"com.google.gms.google-services\")|g" \
      "$gradle" 2>/dev/null || \
    sed -i \
      "s|id(\"com.android.application\")|id(\"com.android.application\")\n    id(\"com.google.gms.google-services\")|g" \
      "$gradle"
  fi

  success "Patched $gradle  (package=$ANDROID_PACKAGE, compileSdk=35, targetSdk=35, minSdk=21)"
}

# Patches android/build.gradle.kts (root) to add google-services classpath
step_android_patch_root_gradle() {
  local root_gradle="android/build.gradle.kts"
  if [[ ! -f "$root_gradle" ]]; then
    warn "$root_gradle not found — skipping"
    return
  fi

  if ! grep -q "com.google.gms:google-services" "$root_gradle"; then
    # Prepend buildscript block before allprojects
    local tmp
    tmp=$(mktemp)
    cat > "$tmp" <<'BLOCK'
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

BLOCK
    cat "$tmp" "$root_gradle" > "${root_gradle}.new"
    mv "${root_gradle}.new" "$root_gradle"
    rm "$tmp"
    success "Added google-services classpath to $root_gradle"
  else
    success "google-services classpath already present in $root_gradle"
  fi
}

# Copies google-services.json + creates key.properties
step_android_platform_files() {
  step "3" "Android — copy platform files"

  if [[ -f "$GOOGLE_SERVICES_ANDROID" ]]; then
    cp "$GOOGLE_SERVICES_ANDROID" "$ANDROID_APP_DIR/google-services.json"
    success "google-services.json  →  $ANDROID_APP_DIR/"
    # Verify package name
    local pkg
    pkg=$(python3 -c "
import json
d = json.load(open('$ANDROID_APP_DIR/google-services.json'))
print(d['client'][0]['client_info']['android_client_info']['package_name'])
" 2>/dev/null || echo "unknown")
    if [[ "$pkg" != "$ANDROID_PACKAGE" ]]; then
      warn "Package mismatch! json has '$pkg' but expected '$ANDROID_PACKAGE'"
    else
      success "Package verified: $pkg"
    fi
  else
    warn "google-services.json not found next to build.sh — Firebase won't work"
  fi

  local key_props="android/key.properties"
  if [[ ! -f "$key_props" ]]; then
    cat > "$key_props" <<PROPS
storePassword=$KEYSTORE_STORE_PASS
keyPassword=$KEYSTORE_KEY_PASS
keyAlias=$KEYSTORE_ALIAS
storeFile=../../$KEYSTORE_PATH
PROPS
    success "Created android/key.properties"
  else
    success "android/key.properties already exists"
  fi
}

step_android_run() {
  local mode="${1:-debug}"
  step "4" "Run on Android ($mode)"
  info "flutter run --$mode"
  flutter run --"$mode"
}

step_android_build() {
  local mode="${1:-release}"
  step "4" "Build Android APK + AAB ($mode)"
  info "flutter build apk --$mode --split-per-abi"
  flutter build apk --"$mode" --split-per-abi
  success "APK  →  build/app/outputs/flutter-apk/"
  info "flutter build appbundle --$mode"
  flutter build appbundle --"$mode"
  success "AAB  →  build/app/outputs/bundle/${mode}/"
}

# =============================================================================
# iOS STEPS
# =============================================================================

# Copies GoogleService-Info.plist, creates entitlements, patches Info.plist URL scheme
step_ios_platform_files() {
  step "3" "iOS — copy platform files"

  if [[ -f "$GOOGLE_SERVICES_IOS" ]]; then
    cp "$GOOGLE_SERVICES_IOS" "$IOS_RUNNER_DIR/GoogleService-Info.plist"
    success "GoogleService-Info.plist  →  $IOS_RUNNER_DIR/"
    # Verify bundle ID
    local bid
    bid=$(/usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" \
      "$IOS_RUNNER_DIR/GoogleService-Info.plist" 2>/dev/null || echo "unknown")
    if [[ "$bid" != "$BUNDLE_ID" ]]; then
      warn "Bundle ID mismatch! plist has '$bid' but expected '$BUNDLE_ID'"
    else
      success "Bundle ID verified: $bid"
    fi
  else
    warn "GoogleService-Info.plist not found next to build.sh — Firebase won't work"
  fi

  # Runner.entitlements
  local entitlements="$IOS_RUNNER_DIR/Runner.entitlements"
  if [[ ! -f "$entitlements" ]]; then
    cat > "$entitlements" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>aps-environment</key>
  <string>development</string>
  <key>com.apple.developer.associated-domains</key>
  <array/>
</dict>
</plist>
PLIST
    success "Created Runner.entitlements"
  else
    success "Runner.entitlements already exists"
  fi

  # Patch Info.plist — add REVERSED_CLIENT_ID URL scheme for Google Sign-In
  local info_plist="$IOS_RUNNER_DIR/Info.plist"
  if [[ -f "$info_plist" ]]; then
    if ! grep -q "$REVERSED_CLIENT_ID" "$info_plist"; then
      /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$info_plist" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$info_plist" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleTypeRole string Editor" "$info_plist" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$info_plist" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $REVERSED_CLIENT_ID" "$info_plist" 2>/dev/null || true
      success "Added REVERSED_CLIENT_ID URL scheme to Info.plist"
    else
      success "URL scheme already in Info.plist"
    fi
  else
    warn "ios/Runner/Info.plist not found — skipping URL scheme patch"
  fi
}

step_ios_certs() {
  step "4" "iOS — certificates & provisioning profiles"

  local p12_files=()
  while IFS= read -r -d '' f; do p12_files+=("$f"); done \
    < <(find . -maxdepth 1 -name "*.p12" -print0 2>/dev/null)

  if [[ ${#p12_files[@]} -gt 0 ]]; then
    for p12 in "${p12_files[@]}"; do
      info "Importing: $p12"
      read -rsp "    Certificate password (leave blank if none): " cert_pass; echo
      security import "$p12" \
        -k ~/Library/Keychains/login.keychain-db \
        -P "$cert_pass" \
        -T /usr/bin/codesign \
        -T /usr/bin/security 2>/dev/null \
        || warn "Already imported or wrong password — continuing"
      success "Imported $p12"
    done
    security set-key-partition-list \
      -S apple-tool:,apple:,codesign: -s -k "" \
      ~/Library/Keychains/login.keychain-db 2>/dev/null || true
  else
    warn "No .p12 files found — place them next to build.sh"
  fi

  local profile_files=()
  while IFS= read -r -d '' f; do profile_files+=("$f"); done \
    < <(find . -maxdepth 1 -name "*.mobileprovision" -print0 2>/dev/null)

  if [[ ${#profile_files[@]} -gt 0 ]]; then
    local profiles_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
    mkdir -p "$profiles_dir"
    for profile in "${profile_files[@]}"; do
      local uuid
      uuid=$(python3 -c "
import subprocess, plistlib
data = subprocess.check_output(['security','cms','-D','-i','$profile'])
print(plistlib.loads(data)['UUID'])
" 2>/dev/null || echo "unknown-$$")
      cp "$profile" "$profiles_dir/$uuid.mobileprovision"
      success "Installed profile  →  $profiles_dir/$uuid.mobileprovision"
    done
  else
    warn "No .mobileprovision files found — place them next to build.sh"
  fi

  # ExportOptions.plist
  cat > ios/ExportOptions.plist << EXPORT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>ad-hoc</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>$BUNDLE_ID</key>
    <string>$PROVISIONING_PROFILE_NAME</string>
  </dict>
  <key>compileBitcode</key>
  <false/>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>thinning</key>
  <string>&lt;none&gt;</string>
</dict>
</plist>
EXPORT
  success "Created ios/ExportOptions.plist  (bundle: $BUNDLE_ID)"
}

step_ios_pods() {
  step "5" "iOS — pod install"
  if command -v pod &>/dev/null; then
    info "pod install --repo-update"
    (cd ios && pod install --repo-update)
    success "Pods installed"
  else
    warn "CocoaPods not found — run: sudo gem install cocoapods"
  fi
}

step_ios_run() {
  local mode="${1:-debug}"
  step "6" "Run on iOS ($mode)"
  info "flutter run --$mode"
  flutter run --"$mode"
}

step_ios_build() {
  step "6" "Build iOS IPA (release)"
  info "flutter build ios --release --no-codesign"
  flutter build ios --release --no-codesign

  info "xcodebuild archive"
  xcodebuild archive \
    -workspace ios/Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -archivePath build/ios/Runner.xcarchive \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    CODE_SIGN_STYLE=Manual \
    PROVISIONING_PROFILE_SPECIFIER="$PROVISIONING_PROFILE_NAME" \
    | xcpretty 2>/dev/null || true

  info "xcodebuild -exportArchive"
  xcodebuild -exportArchive \
    -archivePath build/ios/Runner.xcarchive \
    -exportPath build/ios/ipa \
    -exportOptionsPlist ios/ExportOptions.plist \
    | xcpretty 2>/dev/null || true

  success "IPA  →  build/ios/ipa/"
}

# =============================================================================
# PLATFORM PIPELINES  (ordered step-by-step)
# =============================================================================

run_android_debug() {
  echo -e "\n${BOLD}${GREEN}▶  Android — Run Debug${RESET}"; divider
  step_check_deps                # 1. check flutter/git
  step_flutter_setup             # 2. clean + pub get
  step_android_patch_root_gradle # 3a. root build.gradle.kts → google-services classpath
  step_android_patch_gradle      # 3b. app build.gradle.kts → package + compileSdk 35
  step_android_platform_files    # 3c. google-services.json + key.properties
  step_android_run debug         # 4. flutter run --debug
}

run_android_release() {
  echo -e "\n${BOLD}${GREEN}▶  Android — Run Release${RESET}"; divider
  step_check_deps
  step_flutter_setup
  step_android_patch_root_gradle
  step_android_patch_gradle
  step_android_platform_files
  step_android_run release
}

build_android_release() {
  echo -e "\n${BOLD}${GREEN}▶  Android — Build Release APK + AAB${RESET}"; divider
  step_check_deps
  step_flutter_setup
  step_android_patch_root_gradle
  step_android_patch_gradle
  step_android_platform_files
  step_android_build release
}

run_ios_debug() {
  echo -e "\n${BOLD}${CYAN}▶  iOS — Run Debug${RESET}"; divider
  step_check_deps              # 1. check flutter/git
  step_flutter_setup           # 2. clean + pub get
  step_ios_platform_files      # 3. GoogleService-Info.plist + entitlements + URL scheme
  step_ios_certs               # 4. .p12 + .mobileprovision + ExportOptions.plist
  step_ios_pods                # 5. pod install
  step_ios_run debug           # 6. flutter run --debug
}

run_ios_release() {
  echo -e "\n${BOLD}${CYAN}▶  iOS — Run Release${RESET}"; divider
  step_check_deps
  step_flutter_setup
  step_ios_platform_files
  step_ios_certs
  step_ios_pods
  step_ios_run release
}

build_ios_release() {
  echo -e "\n${BOLD}${CYAN}▶  iOS — Build Release IPA${RESET}"; divider
  step_check_deps
  step_flutter_setup
  step_ios_platform_files
  step_ios_certs
  step_ios_pods
  step_ios_build
}

build_both() {
  build_android_release
  build_ios_release
}

# =============================================================================
# INTERACTIVE MENU
# =============================================================================
show_menu() {
  clear
  echo -e "${BOLD}${CYAN}"
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║           MoneyFlow — Build Tool                     ║"
  echo "  ║  Package : co.tpcreative.moneyflow.app               ║"
  echo "  ║  Firebase: moneyflow-ddc15                           ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo -e "${RESET}"

  echo -e "  ${BOLD}── 🤖 Android ──────────────────────────────${RESET}"
  echo -e "  ${CYAN} 1)${RESET} Run Android   ${YELLOW}debug${RESET}"
  echo -e "       Step 1: Check deps"
  echo -e "       Step 2: flutter clean + pub get"
  echo -e "       Step 3: Patch build.gradle.kts (package + compileSdk 35)"
  echo -e "       Step 3: Copy google-services.json + key.properties"
  echo -e "       Step 4: flutter run --debug"
  echo ""
  echo -e "  ${CYAN} 2)${RESET} Run Android   ${GREEN}release${RESET}"
  echo -e "       Step 1-3: same as above"
  echo -e "       Step 4: flutter run --release"
  echo ""
  echo -e "  ${CYAN} 3)${RESET} Build Android ${GREEN}release${RESET} APK + AAB"
  echo -e "       Step 1-3: same as above"
  echo -e "       Step 4: flutter build apk + appbundle"
  echo ""

  echo -e "  ${BOLD}── 🍎 iOS ───────────────────────────────────${RESET}"
  echo -e "  ${CYAN} 4)${RESET} Run iOS       ${YELLOW}debug${RESET}"
  echo -e "       Step 1: Check deps"
  echo -e "       Step 2: flutter clean + pub get"
  echo -e "       Step 3: Copy GoogleService-Info.plist + entitlements + URL scheme"
  echo -e "       Step 4: Import .p12 cert + install .mobileprovision"
  echo -e "       Step 5: pod install"
  echo -e "       Step 6: flutter run --debug"
  echo ""
  echo -e "  ${CYAN} 5)${RESET} Run iOS       ${GREEN}release${RESET}"
  echo -e "       Step 1-5: same as above"
  echo -e "       Step 6: flutter run --release"
  echo ""
  echo -e "  ${CYAN} 6)${RESET} Build iOS     ${GREEN}release${RESET} IPA"
  echo -e "       Step 1-5: same as above"
  echo -e "       Step 6: xcodebuild archive + export IPA"
  echo ""

  echo -e "  ${BOLD}── 🚀 Both ──────────────────────────────────${RESET}"
  echo -e "  ${CYAN} 7)${RESET} Build Android + iOS ${GREEN}release${RESET}"
  echo ""
  echo -e "  ${RED} 0)${RESET} Exit"
  divider
  printf "  Select: "
  read -r choice

  case "$choice" in
    1) run_android_debug ;;
    2) run_android_release ;;
    3) build_android_release ;;
    4) run_ios_debug ;;
    5) run_ios_release ;;
    6) build_ios_release ;;
    7) build_both ;;
    0) echo -e "\n  ${CYAN}Bye!${RESET}\n"; exit 0 ;;
    *)
      warn "Invalid option — try again"
      sleep 1; show_menu; return
      ;;
  esac

  echo ""
  divider
  printf "  Back to menu? (y/n): "
  read -r again
  [[ "$again" =~ ^[Yy]$ ]] && show_menu || echo -e "\n  ${CYAN}Bye!${RESET}\n"
}

# =============================================================================
# ENTRYPOINT
# =============================================================================
main() {
  if [[ $# -eq 0 ]]; then show_menu; return; fi
  case "${1}" in
    run:android)     run_android_debug ;;
    run:android:rel) run_android_release ;;
    build:android)   build_android_release ;;
    run:ios)         run_ios_debug ;;
    run:ios:rel)     run_ios_release ;;
    build:ios)       build_ios_release ;;
    build:all)       build_both ;;
    help|--help|-h)
      echo "Usage: ./build.sh [command]  — or no args for interactive menu"
      echo ""
      echo "  run:android      Android debug   (steps 1-4)"
      echo "  run:android:rel  Android release (steps 1-4)"
      echo "  build:android    Android APK+AAB (steps 1-4)"
      echo "  run:ios          iOS debug       (steps 1-6)"
      echo "  run:ios:rel      iOS release     (steps 1-6)"
      echo "  build:ios        iOS IPA         (steps 1-6)"
      echo "  build:all        Android + iOS release"
      ;;
    *) error "Unknown command '${1}'. Run './build.sh help' for usage." ;;
  esac
}

main "$@"