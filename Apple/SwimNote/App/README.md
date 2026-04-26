# SwimNote Apple App Target Notes

This Swift package contains the native SwiftUI app and core modules. Open `Package.swift` in Xcode to run the macOS executable target during local development.

For an App Store archive, create an iOS/macOS multiplatform app target in Xcode that uses:

- App entry point: `Sources/SwimNoteApp/NativeSwimNoteApp.swift`
- Bundle resources: `Sources/SwimNoteCore/Resources`
- Info plist: `App/Info.plist`
- Entitlements: `App/SwimNote.entitlements`
- iCloud container: `iCloud.com.swimnote.app`

The package is structured this way so command-line verification can run in environments where full Xcode project generation is not available.
