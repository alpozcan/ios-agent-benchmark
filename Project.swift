import ProjectDescription

// Tier 1 Atlas project manifest.
// The agent writes all Swift sources under ./Atlas/ based on PRD.md.
// This manifest is part of the scaffold and should NOT be modified by the agent.

let project = Project(
    name: "Atlas",
    targets: [
        .target(
            name: "Atlas",
            destinations: [.iPhone],
            product: .app,
            bundleId: "com.iosagentbenchmark.Atlas",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [
                    "UIColorName": "",
                    "UIImageName": "",
                ],
                "UISupportedInterfaceOrientations": [
                    "UIInterfaceOrientationPortrait",
                ],
            ]),
            sources: ["Atlas/**"],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                    "SWIFT_UPCOMING_FEATURE_EXPLICIT_EXISTENTIAL_TYPES": "YES",
                    "GENERATE_INFOPLIST_FILE": "YES",
                    "MARKETING_VERSION": "1.0",
                    "CURRENT_PROJECT_VERSION": "1",
                ],
                configurations: [
                    .debug(name: .debug),
                    .release(name: .release),
                ]
            )
        ),
    ]
)
