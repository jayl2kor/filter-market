# moodit - Swift 코딩 컨벤션

> 버전: v1.0 · 작성일: 2026-05-06
>
> 본 문서는 [TECH_STACK.md](./TECH_STACK.md) §12 (코드 품질 / 표준)의 결정을 구체화한 작업 표준이다. PR 머지 전 모든 코드는 본 컨벤션을 통과해야 한다.

---

## 1. 일반 원칙

1. **명확함이 영리함을 이긴다** (Clarity over cleverness)
2. **불변성 우선** — `let` 우선, `var`은 회피, 가능하면 `struct` + 함수형 변환
3. **작은 파일** — 200~400줄 권장, 800줄을 넘으면 분리 검토 (참고: `~/.claude/rules/common/coding-style.md`)
4. **퍼블릭 API는 의도를 드러낸다** — 내부 구현 노출 금지(`internal` 기본, `public/open`은 명시적)
5. **Swift API Design Guidelines** 준수 — https://swift.org/documentation/api-design-guidelines/

---

## 2. 네이밍

### 2.1 타입 / 프로토콜
- **PascalCase**, 명사 또는 명사구
- 프로토콜이 능력(capability)을 표현하면 `-able` / `-ing` 접미사
  - `FilterRenderable`, `Authenticating`
- 프로토콜이 역할(role)이면 명사 그대로
  - `FilterRepository`, `CameraService`

### 2.2 메서드
- **camelCase**, 동사로 시작
- 첫 인자 레이블이 문장처럼 읽혀야 함
  ```swift
  // GOOD
  filter.apply(to: image, intensity: 0.8)
  // BAD
  filter.applyFilter(image, 0.8)
  ```
- Boolean 반환은 `is/has/should/can` 접두사

### 2.3 프로퍼티
- **camelCase**, 명사
- Boolean: `isLoading`, `hasMore`, `canSubmit`

### 2.4 상수
- **camelCase** (Swift 표준), 타입 내부에서 `static let`
- 절대 `kFooBar`, `FOO_BAR` 사용 금지 (Obj-C 잔재)

### 2.5 enum
- 타입은 PascalCase, case는 **camelCase**
  ```swift
  enum FilterStatus { case pending, published, rejected, takedown }
  ```

### 2.6 약어
- 약어는 일관되게 대문자 또는 소문자
  - `URL`, `URLRequest` (전부 대문자)
  - `urlString`, `id` (소문자 시작)
- `id`는 소문자, 식별자에 표준

### 2.7 Generic
- 단일 타입은 `T`, `U`, 의미가 있으면 PascalCase 단어
  - `func map<NewValue>(_ transform: (Value) -> NewValue) -> Self<NewValue>`

---

## 3. 파일 구조

### 3.1 한 파일 한 책임
- 파일명은 그 안의 주 타입과 동일 (`FilterEngine.swift`)
- 1 type per file 원칙 (단, 직접 관련된 작은 helper enum/struct는 동일 파일 OK)
- Extension은 같은 파일 내 또는 `<Type>+<Concern>.swift` 패턴
  - `Filter+Codable.swift`, `Filter+Validation.swift`

### 3.2 파일 내 섹션 순서

```swift
// 1. Imports (알파벳 정렬)
import Foundation
import Metal
import SwiftUI

// 2. MARK: - 타입 정의
public struct Filter: Identifiable, Codable, Sendable {
    // 2.1 stored properties
    // 2.2 nested types
    // 2.3 init
    // 2.4 computed properties
    // 2.5 public methods
    // 2.6 private helpers
}

// 3. MARK: - Extensions (같은 파일 내라면)
extension Filter: Equatable { ... }
```

### 3.3 모듈 구성
- SPM 패키지 단위로 분리 (참고: [ARCHITECTURE.md](./ARCHITECTURE.md) §3.1)
- 각 모듈의 `public` API는 `Public/` 서브디렉토리에 모음 (선택)
- 모듈 간 의존성은 단방향 (Domain ← Data ← Presentation, Domain은 Foundation 외부 의존성 없음)

---

## 4. 동시성 (Swift Concurrency)

### 4.1 기본 원칙
- **`async/await`**가 1순위, `Combine`은 SwiftUI 외부에서 회피
- **`Task`**는 명시적 라이프사이클, `Task.detached`는 정당한 사유가 있을 때만
- **취소 전파** 필수: `try Task.checkCancellation()` 적절히

### 4.2 actor
- 가변 상태를 공유하는 컴포넌트는 `actor`
  ```swift
  actor FilterCache {
      private var entries: [Filter.ID: Filter] = [:]
      func get(_ id: Filter.ID) -> Filter? { entries[id] }
      func put(_ filter: Filter) { entries[filter.id] = filter }
  }
  ```
- UI 갱신은 `@MainActor`
  ```swift
  @MainActor
  final class FilterListViewModel: ObservableObject {
      @Published var filters: [Filter] = []
  }
  ```

### 4.3 `Sendable`
- 모듈의 public 타입은 가급적 `Sendable` 적합
- `struct`는 모든 stored property가 Sendable이면 자동
- `class`는 `final` + 불변 + `Sendable` 명시 (또는 `@unchecked Sendable` + 동기화 책임 명시)

### 4.4 MainActor 주의
- ViewModel은 `@MainActor`로 선언, 백그라운드 작업은 `Task.detached` 또는 별도 actor에 위임
- `@MainActor` 함수에서 무거운 작업 수행 금지 (UI 끊김)
  ```swift
  @MainActor
  func loadFilters() async {
      let result = await repository.fetchFilters()  // repository는 actor
      self.filters = result                          // MainActor에서 갱신
  }
  ```

### 4.5 Strict Concurrency 단계
- Phase 0~1: `-strict-concurrency=minimal`
- Phase 2~3: `-strict-concurrency=targeted`
- Phase 4+: `-strict-concurrency=complete` (Swift 6 모드)

---

## 5. 에러 처리

### 5.1 에러 정의
- 모듈별 `Error` enum, 도메인 의미 있는 케이스
  ```swift
  public enum FilterError: Error, Sendable {
      case notFound(id: Filter.ID)
      case invalidPackage(reason: String)
      case unsupportedShader(name: String)
      case downloadFailed(underlying: Error)
  }
  ```
- `LocalizedError` 적합 (사용자 노출 메시지가 필요한 경우)

### 5.2 throws vs Result
- 비동기 + 단일 호출 흐름 → `async throws`
- 콜백/Combine → `Result<Success, Failure>` (불가피한 경우만)
- 변환은 컴파일러에 맡김: `Result(catching: { try ... })`

### 5.3 절대 금지
- `try!` 프로덕션 코드 금지 (테스트는 OK)
- `fatalError` 는 "절대 도달 불가" 코드에만, 메시지 필수
- 빈 `catch {}` 금지 (최소한 `os_log`)

### 5.4 사용자 표시
- UI 레이어에서 도메인 에러 → 사용자 메시지 변환 (한국어/영어 i18n)
- 서버 에러는 `error.code`로 분기 (참고: [API_SPEC.md](./API_SPEC.md) §에러 응답)

---

## 6. 의존성 주입 (DI)

### 6.1 원칙
- **프로토콜 + initializer injection**
- DI 컨테이너 라이브러리 회피 — 컴파일 타임 안전성 우선
- `@EnvironmentObject` / `@Environment(.\)`는 SwiftUI의 외부 자원 (DesignSystem, Theme) 주입에만

### 6.2 패턴
```swift
public protocol FilterRepository: Sendable {
    func fetch(id: Filter.ID) async throws -> Filter
    func list(query: FilterQuery) async throws -> [Filter]
}

public final class FilterListViewModel: ObservableObject {
    private let repository: FilterRepository
    public init(repository: FilterRepository) {
        self.repository = repository
    }
}

// 운영 / 테스트 / 프리뷰별 다른 구현체 주입
```

### 6.3 합성 루트
- `App` 모듈의 `@main` 진입점에서 모든 의존성 조립
- 환경(Debug/Staging/Release)별 분기는 합성 루트에서 결정

---

## 7. SwiftUI 작성 규칙

### 7.1 뷰 분리 기준
- **본문이 50줄을 넘으면 서브뷰로 분리**
- `body` 안에 `if/else` 3단계 이상 중첩 금지 → `@ViewBuilder` 함수 또는 별도 View로 추출
- 한 뷰의 `@State`가 5개를 넘으면 ViewModel(`@StateObject`)로 추출

### 7.2 ViewModel 패턴
```swift
@MainActor
final class CameraViewModel: ObservableObject {
    @Published private(set) var state: CameraState = .idle
    private let camera: CameraService
    private let filterEngine: FilterEngine

    init(camera: CameraService, filterEngine: FilterEngine) { ... }

    func start() async { ... }
    func capture() async throws -> CapturedPhoto { ... }
}

struct CameraScreen: View {
    @StateObject private var viewModel: CameraViewModel
    init(viewModel: @autoclosure @escaping () -> CameraViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }
    var body: some View { ... }
}
```

### 7.3 상태 관리
- `@State` — 뷰 로컬, 단순 값
- `@StateObject` — 뷰 소유 ObservableObject
- `@ObservedObject` — 외부 주입 ObservableObject
- `@Binding` — 값 양방향 전달
- iOS 17+의 `@Observable` 매크로 사용 권장 (Phase 1부터)

### 7.4 Preview
- 모든 화면 단위 View는 `#Preview` 제공
- Mock repository를 사용해 다양한 상태 (loading/empty/error/loaded) 미리보기

### 7.5 카메라/Metal 등 UIKit 통합
- `UIViewRepresentable` 또는 `UIViewControllerRepresentable`
- Coordinator 패턴으로 콜백 처리 — closure를 직접 capture하지 않기

---

## 8. 주석 / 문서

### 8.1 DocC
- public API 전부 DocC 주석 필수 (`///`)
- 작성 가이드:
  - 첫 문장은 동작 요약 (한 줄)
  - 빈 줄 후 상세 설명
  - 파라미터/반환은 `- Parameter`, `- Returns`, `- Throws`

```swift
/// .fmpkg 패키지를 메모리에 로드하고 Metal 텍스처를 준비한다.
///
/// 패키지의 manifest.json을 검증하고 LUT 텍스처와 셰이더 라이브러리를
/// `MTLDevice`에 업로드한다. 무거운 I/O를 포함하므로 백그라운드에서 호출.
///
/// - Parameter url: 로컬 파일시스템 .fmpkg URL
/// - Returns: 준비된 ``LoadedFilter``
/// - Throws: ``FilterError`` 의 verification 실패 케이스
public func load(_ url: URL) async throws -> LoadedFilter
```

### 8.2 인라인 주석은 "왜"만
- "what"은 코드가 말한다 — 코드를 명확히 작성
- "why"만 주석 — 비자명한 결정 / 트레이드오프
- TODO/FIXME는 이슈 번호 동반: `// TODO(#123): 65³ LUT 지원`

### 8.3 헤더 주석
- 파일 헤더 주석 작성 안 함 (저작권 등은 LICENSE)

---

## 9. SwiftLint 룰셋 (권장)

### 9.1 활성화 (Default + Opt-in)

| 룰 | 사유 |
|---|---|
| `force_unwrapping` | `!` 사용 차단 |
| `force_try` | `try!` 사용 차단 |
| `implicitly_unwrapped_optional` | IBOutlet 외 금지 |
| `cyclomatic_complexity` (warning 12, error 20) | 함수 복잡도 |
| `function_body_length` (warning 60, error 100) | 함수 길이 |
| `file_length` (warning 400, error 800) | 파일 길이 |
| `type_body_length` (warning 250, error 400) | 타입 길이 |
| `line_length` (warning 140, error 180) | 라인 길이 |
| `function_parameter_count` (warning 5, error 8) | 매개변수 수 |
| `large_tuple` (warning 3, error 4) | 튜플 크기 |
| `nesting` (type 3, function 5) | 중첩 깊이 |
| `closure_parameter_position` | 클로저 가독성 |
| `discouraged_object_literal` | `#imageLiteral` 금지 |
| `empty_collection_literal` | `Array()` → `[]` |
| `empty_count` | `.count == 0` → `.isEmpty` |
| `explicit_init` | `Foo.init(...)` → `Foo(...)` |
| `first_where` | `.filter { ... }.first` → `.first(where:)` |
| `last_where` | 동일 |
| `redundant_nil_coalescing` | `a ?? nil` 금지 |
| `unneeded_parentheses_in_closure_argument` | 가독성 |
| `vertical_whitespace_closing_braces` | 빈 줄 정리 |

### 9.2 비활성화

| 룰 | 사유 |
|---|---|
| `trailing_comma` | SwiftFormat과 충돌 |
| `multiple_closures_with_trailing_closure` | SwiftUI 빌더에서 빈번 |
| `identifier_name` (강제 길이) | `id`, `db` 등 짧은 이름 허용 |
| `todo` | TODO 자체는 허용, 단 이슈 번호 정책으로 보완 |

### 9.3 `.swiftlint.yml` 시드

```yaml
included:
  - Sources
  - Tests
excluded:
  - .build
  - DerivedData
  - "**/Generated"
opt_in_rules:
  - empty_collection_literal
  - empty_count
  - explicit_init
  - first_where
  - last_where
  - redundant_nil_coalescing
disabled_rules:
  - trailing_comma
  - multiple_closures_with_trailing_closure
  - identifier_name
line_length:
  warning: 140
  error: 180
file_length:
  warning: 400
  error: 800
function_body_length:
  warning: 60
  error: 100
type_body_length:
  warning: 250
  error: 400
custom_rules:
  no_print:
    name: "no_print"
    regex: "(?<!swift)\\bprint\\("
    message: "use os_log/Logger instead of print"
    severity: warning
```

---

## 10. SwiftFormat 권장 옵션

```bash
# .swiftformat
--swiftversion 5.10
--indent 4
--maxwidth 140
--commas inline
--trimwhitespace always
--header strip
--self remove
--importgrouping testable-bottom
--ranges spaced
--patternlet hoist
--wraparguments before-first
--wrapparameters before-first
--wrapcollections before-first
--closingparen balanced
--ifdef no-indent
--enable isEmpty
--enable redundantReturn
--enable redundantSelf
--enable spaceAroundOperators
--enable trailingCommas
--enable wrapMultilineStatementBraces
--disable hoistAwait        # await 분산이 명확함
```

`brew install swiftformat` → 사전 커밋 훅에서 실행:
```bash
swiftformat Sources Tests --lint
```

---

## 11. Git 커밋 메시지 (Conventional Commits)

### 11.1 형식
```
<type>(<scope>): <description>

<optional body>

<optional footer>
```

### 11.2 type
- `feat` 새 기능
- `fix` 버그 수정
- `refactor` 동작 변경 없는 구조 개선
- `perf` 성능 개선
- `docs` 문서만
- `test` 테스트만
- `chore` 빌드/도구
- `ci` CI 파이프라인
- `style` 포맷팅(코드 의미 변화 없음)

### 11.3 scope (선택)
- 모듈명 (`camera`, `filter-engine`, `marketplace`, `auth`, `editor`, `storage`, `models`)
- 또는 큰 영역 (`docs`, `ci`, `infra`)

### 11.4 예시
```
feat(filter-engine): support 65^3 LUT with RGBA16F textures

Adds high-precision LUT path for premium makers. Falls back to
33^3 RGBA8 when device doesn't support family 7.

Refs: ADR-0003
```

```
fix(camera): release MTLCommandBuffer on backgrounding

Closes #142
```

> 자세한 git 워크플로는 `~/.claude/rules/common/git-workflow.md` 참고.

---

## 12. PR 체크리스트

PR 본문에 다음을 포함한다:

```markdown
## 개요
<무엇을 / 왜>

## 변경 요약
- ...
- ...

## 영향 범위
- 모듈:
- 마이그레이션 필요 여부:

## 테스트
- [ ] 단위 테스트 추가/갱신
- [ ] 스냅샷 테스트 (UI 변경 시)
- [ ] 통합 테스트 (Firebase Emulator)
- [ ] 실기기 검증 (카메라/Metal 변경 시)

## 스크린샷 / 비디오
<UI/카메라 변경 시>

## 체크리스트
- [ ] SwiftLint 통과
- [ ] SwiftFormat 통과
- [ ] DocC 주석 작성 (public API)
- [ ] 시크릿 누출 없음
- [ ] CHANGELOG (필요 시)
- [ ] 관련 문서 업데이트 (CODING_CONVENTIONS, API_SPEC 등)

## 관련 이슈 / ADR
- Closes #
- Refs: ADR-XXXX
```

머지 전 요구:
- 1명 이상 승인
- 모든 CI 그린
- 아키텍처 변경 시 ADR 추가 (참고: [ADR/template.md](./ADR/template.md))

---

## 13. 관련 문서

- [SETUP.md](./SETUP.md)
- [TECH_STACK.md](./TECH_STACK.md) §12
- [TESTING_STRATEGY.md](./TESTING_STRATEGY.md)
- [ARCHITECTURE.md](./ARCHITECTURE.md) §3.1 모듈 구성
- [ADR/](./ADR/) — 아키텍처 결정 기록
