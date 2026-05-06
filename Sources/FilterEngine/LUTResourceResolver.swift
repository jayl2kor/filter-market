import Foundation

enum LUTResourceResolver {
    static func url(bundle: Bundle, resourcePath: String) throws -> URL {
        let path = resourcePath as NSString
        let subdirectory = path.deletingLastPathComponent
        let fileName = path.deletingPathExtension
        let fileExtension = path.pathExtension

        let bundledURL = bundle.url(
            forResource: fileName,
            withExtension: fileExtension.isEmpty ? nil : fileExtension,
            subdirectory: subdirectory.isEmpty ? nil : subdirectory
        )
        let flattenedURL = bundle.url(
            forResource: fileName,
            withExtension: fileExtension.isEmpty ? nil : fileExtension
        )

        return try url(
            resourcePath: resourcePath,
            resourceURL: bundle.resourceURL,
            additionalCandidates: [bundledURL, flattenedURL]
        )
    }

    static func url(
        resourcePath: String,
        resourceURL: URL?,
        additionalCandidates: [URL?] = []
    ) throws -> URL {
        let path = resourcePath as NSString
        let nestedResourceURL = resourceURL?.appendingPathComponent(resourcePath)
        let flattenedResourceURL = resourceURL?.appendingPathComponent(path.lastPathComponent)

        let candidateURLs = additionalCandidates + [nestedResourceURL, flattenedResourceURL]
        guard let url = candidateURLs.compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw LUTImageLoaderError.missingResource(resourcePath)
        }
        return url
    }
}
