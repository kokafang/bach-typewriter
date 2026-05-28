import Foundation

enum AppResources {
    private static let bundleName = "bach-typewriter-swift_bach-typewriter-swift.bundle"

    private static var resourceBundle: Bundle? {
        for url in bundleCandidates {
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return nil
    }

    static func url(
        forResource name: String,
        withExtension ext: String,
        subdirectory: String? = nil
    ) -> URL? {
        if let url = resourceBundle?.url(
            forResource: name,
            withExtension: ext,
            subdirectory: subdirectory
        ) {
            return url
        }

        return nil
    }

    static func directory(subdirectory: String? = nil) -> URL {
        if let bundleURL = resourceBundle?.bundleURL {
            return subdirectory.map { bundleURL.appendingPathComponent($0) } ?? bundleURL
        }

        let resourceURL = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        return subdirectory.map { resourceURL.appendingPathComponent($0) } ?? resourceURL
    }

    private static var bundleCandidates: [URL] {
        var urls: [URL] = []
        let bundleURL = Bundle.main.bundleURL

        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appendingPathComponent(bundleName))
        }

        urls.append(
            bundleURL
                .appendingPathComponent("Contents")
                .appendingPathComponent("Resources")
                .appendingPathComponent(bundleName)
        )

        if let executableURL = Bundle.main.executableURL {
            urls.append(executableURL.deletingLastPathComponent().appendingPathComponent(bundleName))
        }

        urls.append(bundleURL.appendingPathComponent(bundleName))
        return urls
    }
}
