import Foundation
import XCTest
@testable import Camera

final class PhotoLibrarySaverTests: XCTestCase {
    func testAuthorizedStatusWritesPhotoData() async {
        let writer = PhotoWriterSpy()
        let saver = PhotoLibrarySaver(
            authorizationStatus: { .authorized },
            writePhotoData: { data in
                await writer.write(data)
            }
        )
        let data = Data([1, 2, 3])

        let result = await saver.savePhoto(data: data)
        let writtenData = await writer.writtenDataSnapshot()

        XCTAssertEqual(result, .saved)
        XCTAssertEqual(writtenData, data)
    }

    func testLimitedStatusWritesPhotoData() async {
        let writer = PhotoWriterSpy()
        let saver = PhotoLibrarySaver(
            authorizationStatus: { .limited },
            writePhotoData: { data in
                await writer.write(data)
            }
        )

        let result = await saver.savePhoto(data: Data([4, 5, 6]))
        let writeCount = await writer.writeCountSnapshot()

        XCTAssertEqual(result, .saved)
        XCTAssertEqual(writeCount, 1)
    }

    func testDeniedStatusDoesNotWritePhotoData() async {
        let writer = PhotoWriterSpy()
        let saver = PhotoLibrarySaver(
            authorizationStatus: { .denied },
            writePhotoData: { data in
                await writer.write(data)
            }
        )

        let result = await saver.savePhoto(data: Data([1]))
        let writeCount = await writer.writeCountSnapshot()

        XCTAssertEqual(result, .permissionDenied)
        XCTAssertEqual(writeCount, 0)
    }

    func testRestrictedStatusDoesNotWritePhotoData() async {
        let writer = PhotoWriterSpy()
        let saver = PhotoLibrarySaver(
            authorizationStatus: { .restricted },
            writePhotoData: { data in
                await writer.write(data)
            }
        )

        let result = await saver.savePhoto(data: Data([1]))
        let writeCount = await writer.writeCountSnapshot()

        XCTAssertEqual(result, .permissionRestricted)
        XCTAssertEqual(writeCount, 0)
    }

    func testNotDeterminedStatusDoesNotWritePhotoData() async {
        let writer = PhotoWriterSpy()
        let saver = PhotoLibrarySaver(
            authorizationStatus: { .notDetermined },
            writePhotoData: { data in
                await writer.write(data)
            }
        )

        let result = await saver.savePhoto(data: Data([1]))
        let writeCount = await writer.writeCountSnapshot()

        XCTAssertEqual(result, .permissionNotDetermined)
        XCTAssertEqual(writeCount, 0)
    }

    func testEmptyPhotoDataFailsBeforeAuthorizationRequest() async {
        let authorization = AuthorizationSpy(status: .authorized)
        let writer = PhotoWriterSpy()
        let saver = PhotoLibrarySaver(
            authorizationStatus: {
                await authorization.status()
            },
            writePhotoData: { data in
                await writer.write(data)
            }
        )

        let result = await saver.savePhoto(data: Data())
        let requestCount = await authorization.requestCountSnapshot()
        let writeCount = await writer.writeCountSnapshot()

        XCTAssertEqual(result, .invalidData)
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(writeCount, 0)
    }

    func testWriterFailureReturnsFailed() async {
        let saver = PhotoLibrarySaver(
            authorizationStatus: { .authorized },
            writePhotoData: { _ in
                throw TestSaveError.failed
            }
        )

        let result = await saver.savePhoto(data: Data([1]))

        XCTAssertEqual(result, .failed)
    }
}

private actor PhotoWriterSpy {
    private(set) var writtenData: Data?
    private(set) var writeCount = 0

    func write(_ data: Data) {
        writtenData = data
        writeCount += 1
    }

    func writtenDataSnapshot() -> Data? {
        writtenData
    }

    func writeCountSnapshot() -> Int {
        writeCount
    }
}

private actor AuthorizationSpy {
    private let value: PhotoLibraryAuthorizationStatus
    private(set) var requestCount = 0

    init(status: PhotoLibraryAuthorizationStatus) {
        self.value = status
    }

    func status() -> PhotoLibraryAuthorizationStatus {
        requestCount += 1
        return value
    }

    func requestCountSnapshot() -> Int {
        requestCount
    }
}

private enum TestSaveError: Error {
    case failed
}
