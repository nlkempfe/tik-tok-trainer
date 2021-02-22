# T3 - TikTokTrainer

An app to compare your dace moves to a comparison video.

## Setup Development

Make sure you have the following installed

- Ruby 2

### Initial Setup

Install gems for fastlane and cocoapods.

```bash
     $ bundle install
```

Pull Development Certificates

Make sure you include --readonly and if it prompts for keychain password that is your computers password.

```bash
     $ bundle exec fastlane match development --readonly
```

Install Pods

```bash
     $ bundle exec pod install
```

Open the project by the xcworkspace not the xcodeproj.

Optional open using CLI:

```bash
     $ open TikTokTrainer.xcworkspace
```

Click the name of the project with the blue icon on the left.

Click signing & capibilities.

Uncheck automatic provisioning.

Select match development ... as the provisioning profile.

