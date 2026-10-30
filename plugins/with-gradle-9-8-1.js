const fs = require('fs');
const path = require('path');
const { withDangerousMod } = require('expo/config-plugins');

// Points the Gradle wrapper prebuild writes at Gradle 9.8.1, which embeds Kotlin 2.4.10.
module.exports = (config) =>
  withDangerousMod(config, [
    'android',
    async (modConfig) => {
      const file = path.join(modConfig.modRequest.platformProjectRoot, 'gradle', 'wrapper', 'gradle-wrapper.properties');
      const contents = fs.readFileSync(file, 'utf8');
      fs.writeFileSync(file, contents.replace(/gradle-[0-9.]+-bin\.zip/, 'gradle-9.8.1-bin.zip'));
      return modConfig;
    },
  ]);
