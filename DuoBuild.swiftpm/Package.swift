// swift-tools-version: 5.9

// Open this folder in Swift Playgrounds on iPad to run DuoBuild right away.
// The App Store app is built from the same code by project.yml.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "DuoBuild",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "DuoBuild",
            targets: ["AppModule"],
            bundleIdentifier: "com.ariberkowitz.duobuild.preview",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .pencil),
            accentColor: .presetColor(.indigo),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
