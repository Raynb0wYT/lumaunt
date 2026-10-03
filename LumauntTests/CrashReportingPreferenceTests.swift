import Foundation
import Testing
@testable import Lumaunt

struct CrashReportingPreferenceTests {
    @Test
    func crashReportingDefaultsToOff() {
        let suiteName =
            "CrashReportingPreferenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(
            suiteName: suiteName
        )!

        defer {
            defaults.removePersistentDomain(
                forName: suiteName
            )
        }

        #expect(
            CrashReporting.isOptedIn(
                defaults: defaults
            ) == false
        )
    }

    @Test
    func crashReportingPreferencePersists() {
        let suiteName =
            "CrashReportingPreferenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(
            suiteName: suiteName
        )!

        defer {
            defaults.removePersistentDomain(
                forName: suiteName
            )
        }

        defaults.set(
            true,
            forKey: CrashReporting.preferenceKey
        )

        let reloadedDefaults = UserDefaults(
            suiteName: suiteName
        )!

        #expect(
            CrashReporting.isOptedIn(
                defaults: reloadedDefaults
            )
        )
    }
}
