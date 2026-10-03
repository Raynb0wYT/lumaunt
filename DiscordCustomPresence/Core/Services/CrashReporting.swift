import Foundation
import Sentry

enum CrashReporting {
    static let preferenceKey = "shareCrashReports"

    private static var isStarted = false

    static func configureFromStoredPreference(
        defaults: UserDefaults = .standard
    ) {
        setEnabled(
            defaults.bool(forKey: preferenceKey)
        )
    }

    static func setEnabled(_ enabled: Bool) {
        guard enabled else {
            if isStarted {
                SentrySDK.close()
                isStarted = false
            }
            return
        }

        guard !isStarted, let dsn else {
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.debug = false
            
            options.enableCrashHandler = true
            options.sendDefaultPii = false
            options.enableMemoryIntrospection = false

            options.enableSwizzling = false
            options.enableAutoBreadcrumbTracking = false
            options.maxBreadcrumbs = 0
            options.enableNetworkBreadcrumbs = false

            options.enableNetworkTracking = false
            options.enableCaptureFailedRequests = false

            options.enableAutoPerformanceTracing = false
            options.tracesSampleRate = 0
            options.enableFileIOTracing = false
            options.enableCoreDataTracing = false

            options.enableAutoSessionTracking = false
            options.enableAppHangTracking = false
            options.enableWatchdogTerminationTracking = false
            options.enableMetricKit = false
            options.enableMetricKitRawPayload = false

            options.enableLogs = false
            options.sendClientReports = false
            options.enableSpotlight = false

            options.beforeSend = { event in
                SentryEventScrubber.scrub(event)
            }
        }

        isStarted = true
    }

    static func isOptedIn(
        defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.bool(forKey: preferenceKey)
    }
    
#if DEBUG
    static func sendDebugTestEvent() {
        guard isStarted, SentrySDK.isEnabled else {
            print("❌ SENTRY TEST: Sentry is not enabled")
            return
        }

        let error = NSError(
            domain: "Lumaunt.SentryTest",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Privacy-safe DEBUG test event"
            ]
        )

        let eventID = SentrySDK.capture(error: error)

        if eventID.sentryIdString ==
            "00000000000000000000000000000000" {
            print("❌ SENTRY TEST: Event was not captured")
        } else {
            print("✅ SENTRY TEST: Event captured")
            print("📨 SENTRY TEST: Event ID: \(eventID)")
        }
    }
    #endif

    
    private static var dsn: String? {
        guard let value = Bundle.main.object(
            forInfoDictionaryKey: "SENTRY_DSN"
        ) as? String else {
            return nil
        }

        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty,
              !trimmed.contains("$(") else {
            return nil
        }

        return trimmed
    }
}

private enum SentryEventScrubber {
    nonisolated static func scrub(
        _ event: Event
    ) -> Event? {
        event.request = nil
        event.message = nil
        event.user = nil
        event.breadcrumbs = []
        event.tags = nil
        event.extra = nil
        event.transaction = nil
        event.logger = nil
        event.serverName = nil

        event.context = allowedContexts(
            from: event.context
        )

        for exception in event.exceptions ?? [] {
            exception.value = nil
            scrub(exception.stacktrace)
        }

        for thread in event.threads ?? [] {
            scrub(thread.stacktrace)
        }

        scrub(event.stacktrace)

        return event
    }

    nonisolated private static func allowedContexts(
        from contexts:
            [String: [String: Any]]?
    ) -> [String: [String: Any]] {
        guard let contexts else {
            return [:]
        }

        let allowedKeys: [
            String: Set<String>
        ] = [
            "app": [
                "app_identifier",
                "app_name",
                "app_version",
                "app_build"
            ],
            "os": [
                "name",
                "version",
                "build"
            ],
            "device": [
                "arch"
            ],
            "runtime": [
                "name",
                "version"
            ]
        ]

        return allowedKeys.reduce(
            into: [:]
        ) { result, entry in
            guard let context =
                    contexts[entry.key] else {
                return
            }

            let filtered = context.filter {
                entry.value.contains($0.key)
            }

            if !filtered.isEmpty {
                result[entry.key] = filtered
            }
        }
    }

    nonisolated private static func scrub(
        _ stacktrace: SentryStacktrace?
    ) {
        for frame in stacktrace?.frames ?? [] {
            frame.fileName = nil
            frame.contextLine = nil
            frame.preContext = nil
            frame.postContext = nil
            frame.vars = nil
        }
    }
}

