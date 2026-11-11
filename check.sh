#!/usr/bin/env bash
# Prebuilds the Android project, whose Gradle wrapper plugins/with-gradle-wrapper.js points at Gradle 9.9.1, and runs
# `./gradlew help`. Exits 1 while an Expo Gradle plugin build fails to read the Kotlin 2.4 metadata of Gradle's own
# Kotlin libraries, 0 once the build configures, and 2 when a step fails another way.
set -uo pipefail

cd "$(dirname "$0")" || exit 2

package_version() {
  node -p "require('./node_modules/$1/package.json').version" 2>/dev/null || printf 'not installed'
}

if [ ! -d node_modules ]; then
  if ! npm ci --no-audit --no-fund >install.log 2>&1; then
    tail -n 20 install.log
    echo "SUMMARY: step failed: npm ci (install.log)"
    exit 2
  fi
fi

if ! npx --no-install expo prebuild --platform android --clean --no-install >prebuild.log 2>&1; then
  tail -n 20 prebuild.log
  echo "SUMMARY: step failed: expo prebuild (prebuild.log)"
  exit 2
fi

system_name=$(uname -s) || exit 2
java_version=$(java -version 2>&1 | head -n 1) || exit 2
gradle_version=$(sed -n -E 's/^distributionUrl=.*gradle-([0-9.]+)-bin\.zip$/\1/p' android/gradle/wrapper/gradle-wrapper.properties) || exit 2
package_versions=""
for package in expo expo-modules-autolinking expo-modules-core react-native; do
  version=$(package_version "$package") || exit 2
  package_versions+=", $package $version"
done
echo "System: $system_name, $java_version, Gradle $gradle_version$package_versions"

echo '$ ./gradlew help --continue'
(cd android && ./gradlew --no-daemon --console=plain help --continue) >gradle.log 2>&1
status=$?
echo "exit $status"
if [ "$status" -eq 0 ]; then
  echo "SUMMARY: fixed: the Android build configures on Gradle $gradle_version"
  exit 0
fi

project_root=$(pwd -W 2>/dev/null || pwd) || exit 2
metadata_errors=$(grep -E "^e: .*node_modules/(expo-modules-autolinking|expo-modules-core|expo-dev-launcher)/.* was compiled with an incompatible version of Kotlin\. The actual metadata version is 2\.4" gradle.log)
failed_tasks=$(grep -E "^Execution failed for task '" gradle.log)
echo "$failed_tasks"
if [ -n "$metadata_errors" ]; then
  first=$(head -n 1 <<<"$metadata_errors")
  echo "${first//file:\/\/\/$project_root\//}"
  count=$(grep -c '' <<<"$metadata_errors")
  echo "SUMMARY: defect: Expo's Gradle plugin builds compile with a Kotlin that cannot read the Kotlin 2.4 metadata Gradle $gradle_version embeds: $count errors"
  exit 1
fi
tail -n 30 gradle.log
echo "SUMMARY: step failed: the build failed another way (gradle.log)"
exit 2
