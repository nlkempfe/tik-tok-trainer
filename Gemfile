source "https://rubygems.org"

gem "fastlane"
gem "xcode-install", "~> 2.6"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
