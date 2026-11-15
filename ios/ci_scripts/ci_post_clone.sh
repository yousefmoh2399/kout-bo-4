#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# The default execution directory of this script is the ci_scripts directory.
# Navigate to the root of the repository
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Install Flutter using git (shallow clone of stable branch)
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

# Pre-cache iOS engine artifacts
flutter precache --ios

# Install Flutter dependencies
flutter pub get

# Generate iOS build configuration and ephemeral Swift Packages (FlutterGeneratedPluginSwiftPackage)
flutter build ios --config-only --no-codesign

# If a Podfile exists in the future, install CocoaPods dependencies
if [ -f "ios/Podfile" ]; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
    cd ios && pod install
    cd ..
fi

exit 0
