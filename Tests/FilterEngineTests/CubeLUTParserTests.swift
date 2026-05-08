import XCTest
@testable import FilterEngine

final class CubeLUTParserTests: XCTestCase {

    // MARK: - Happy paths

    func testParsesValid32Cube3DLUT() throws {
        let source = makeCube3D(size: 32)
        let lut = try CubeLUTParser.parse(source)

        guard case .threeDimensional(let parsed) = lut else {
            return XCTFail("Expected 3D LUT, got \(lut)")
        }

        XCTAssertEqual(parsed.size, 32)
        // Identity LUT — corner samples should be the canonical (0,0,0) and (1,1,1).
        XCTAssertEqual(parsed.colorAt(red: 0, green: 0, blue: 0).red, 0, accuracy: 1e-6)
        XCTAssertEqual(parsed.colorAt(red: 31, green: 31, blue: 31).blue, 1, accuracy: 1e-6)
    }

    func testParsesValid64Cube3DLUT() throws {
        let source = makeCube3D(size: 64)
        let lut = try CubeLUTParser.parse(source)

        guard case .threeDimensional(let parsed) = lut else {
            return XCTFail("Expected 3D LUT, got \(lut)")
        }
        XCTAssertEqual(parsed.size, 64)
    }

    func testParsesValid1DLUT() throws {
        let source = """
        TITLE "ramp"
        LUT_1D_SIZE 4
        0.0 0.0 0.0
        0.25 0.25 0.25
        0.75 0.75 0.75
        1.0 1.0 1.0
        """

        let lut = try CubeLUTParser.parse(source)

        guard case .oneDimensional(let samples) = lut else {
            return XCTFail("Expected 1D LUT, got \(lut)")
        }
        XCTAssertEqual(samples.count, 4)
        XCTAssertEqual(samples[2].red, 0.75, accuracy: 1e-6)
    }

    func testIgnoresBlankLinesAndComments() throws {
        let source = """
        # moodit identity LUT 2x2x2
        TITLE "identity"

        # next: declare size

        LUT_3D_SIZE 2
        # 8 rows follow:
        0.0 0.0 0.0
        1.0 0.0 0.0

        0.0 1.0 0.0
        1.0 1.0 0.0
        # blue=1
        0.0 0.0 1.0
        1.0 0.0 1.0
        0.0 1.0 1.0
        1.0 1.0 1.0
        """

        let lut = try CubeLUTParser.parse(source)
        guard case .threeDimensional(let parsed) = lut else {
            return XCTFail("Expected 3D LUT")
        }
        XCTAssertEqual(parsed.size, 2)
    }

    func testIgnoresDomainMinMaxHeaders() throws {
        let source = """
        LUT_3D_SIZE 2
        DOMAIN_MIN 0.0 0.0 0.0
        DOMAIN_MAX 1.0 1.0 1.0
        \(makeIdentity3DRows(size: 2))
        """

        XCTAssertNoThrow(try CubeLUTParser.parse(source))
    }

    // MARK: - Error paths

    func testRejectsMissingSizeHeader() {
        let source = """
        0.0 0.0 0.0
        1.0 1.0 1.0
        """

        XCTAssertThrowsError(try CubeLUTParser.parse(source)) { error in
            XCTAssertEqual(error as? CubeLUTParser.ParseError, .missingSizeHeader)
        }
    }

    func testRejectsRowCountMismatch() {
        // Declares size 2 (8 rows expected) but only supplies 4.
        let source = """
        LUT_3D_SIZE 2
        0.0 0.0 0.0
        1.0 0.0 0.0
        0.0 1.0 0.0
        1.0 1.0 0.0
        """

        XCTAssertThrowsError(try CubeLUTParser.parse(source)) { error in
            XCTAssertEqual(
                error as? CubeLUTParser.ParseError,
                .rowCountMismatch(expected: 8, actual: 4)
            )
        }
    }

    func testRejectsNonFiniteValue() {
        let source = """
        LUT_1D_SIZE 2
        0.0 0.0 0.0
        nan 1.0 1.0
        """

        XCTAssertThrowsError(try CubeLUTParser.parse(source)) { error in
            guard case CubeLUTParser.ParseError.valueNotFinite(let line) = error else {
                return XCTFail("Expected valueNotFinite, got \(error)")
            }
            XCTAssertEqual(line, 3)
        }
    }

    func testRejectsSizeOutOfRange() {
        let source = """
        LUT_3D_SIZE 1
        0.0 0.0 0.0
        """

        XCTAssertThrowsError(try CubeLUTParser.parse(source)) { error in
            guard case CubeLUTParser.ParseError.sizeOutOfRange(_, let size, let allowed) = error else {
                return XCTFail("Expected sizeOutOfRange, got \(error)")
            }
            XCTAssertEqual(size, 1)
            XCTAssertEqual(allowed, CubeLUTParser.threeDSizeRange)
        }
    }

    func testRejectsDuplicateSizeHeader() {
        let source = """
        LUT_3D_SIZE 2
        LUT_1D_SIZE 4
        """

        XCTAssertThrowsError(try CubeLUTParser.parse(source)) { error in
            XCTAssertEqual(error as? CubeLUTParser.ParseError, .duplicateSizeHeader)
        }
    }

    func testRejectsMalformedDataLine() {
        let source = """
        LUT_1D_SIZE 2
        0.0 0.0
        1.0 1.0 1.0
        """

        XCTAssertThrowsError(try CubeLUTParser.parse(source)) { error in
            guard case CubeLUTParser.ParseError.malformedDataLine(let line, _) = error else {
                return XCTFail("Expected malformedDataLine, got \(error)")
            }
            XCTAssertEqual(line, 2)
        }
    }

    func testRejectsInvalidSizeValue() {
        let source = """
        LUT_3D_SIZE banana
        """

        XCTAssertThrowsError(try CubeLUTParser.parse(source)) { error in
            guard case CubeLUTParser.ParseError.invalidSizeValue = error else {
                return XCTFail("Expected invalidSizeValue, got \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func makeCube3D(size: Int) -> String {
        "TITLE \"identity \(size)\"\nLUT_3D_SIZE \(size)\n" + makeIdentity3DRows(size: size)
    }

    /// Identity LUT rows in `red varies fastest` order — matches the LUT3D layout.
    private func makeIdentity3DRows(size: Int) -> String {
        var rows: [String] = []
        rows.reserveCapacity(size * size * size)
        let scale = Float(size - 1)
        for b in 0 ..< size {
            for g in 0 ..< size {
                for r in 0 ..< size {
                    let row = "\(Float(r) / scale) \(Float(g) / scale) \(Float(b) / scale)"
                    rows.append(row)
                }
            }
        }
        return rows.joined(separator: "\n")
    }
}
