# moodit — Photo Asset Brief

> 작성: 2026-05-07
>
> 사진가 / 디자이너에게 의뢰할 실제 사진 자산 목록. 모든 자산은
> `4:5` (마켓 카드) / `1:1` (아바타) / `16:9` (커버) 비율 중 명시된 것.
> RAW 또는 ≥ 2400px 단변 권장. sRGB 색공간.

---

## 1. 시드 필터 비포 / 애프터 (P0)

각 시드 필터당 **비포 1장 + 애프터 1장 + 커버 1장 = 3장**. 카메라 RAW 또는 high-res JPEG.
현재는 `FMFilterCoverArt` procedural Canvas 일러스트로 대체 — 실제 사진 도입 시 교체.

| 필터 ID | 모티프 | 권장 피사체 | 톤 가이드 |
|---|---|---|---|
| Sunset Vibes | vintage | 낮~저녁 도시 풍경, 따뜻한 햇살 | 골드/오렌지 미드톤, 약한 비네팅 |
| Soft Portra | portrait | 자연광 인물 (실내/창가) | 피부톤 부드러움, 채도 -10% |
| Seoul Night | mood | 도시 야경 (네온, 거리등) | 시안+마젠타, 검정 풍부 |
| Cafe Cream | food | 카페 디저트 / 라떼 | 따뜻한 베이지+크림, 약한 페이드 |
| Airy Trip | travel | 야외 풍경 (해변/산) | 청량한 하이라이트, 그린 채도 |

**자산 위치 (도입 시)**:
- `Sources/Marketplace/Resources/SeedFilters/covers/{filter-id}.jpg` (4:5)
- `Sources/Marketplace/Resources/SeedFilters/before/{filter-id}.jpg` (4:5)
- `Sources/Marketplace/Resources/SeedFilters/after/{filter-id}.jpg` (4:5)

**manifest.json 필드 추가**:
```json
{
  "id": "...",
  "title": "Sunset Vibes",
  "preview": {
    "cover": "SeedFilters/covers/sunset-vibes.jpg",
    "before": "SeedFilters/before/sunset-vibes.jpg",
    "after": "SeedFilters/after/sunset-vibes.jpg"
  }
}
```

---

## 2. 카테고리 대표 사진 8종 (P1)

`SearchScreen` browsing 모드에서 카테고리별 진입점 카드에 사용.

| 카테고리 | 사진 1장 (16:9) | 톤 가이드 |
|---|---|---|
| Cinematic | 영화 한 장면 같은 도시 / 인물 | 시네마스코프, 깊은 콘트라스트 |
| Vintage | 필름 룩 풍경 | 따뜻한 페이드 |
| Pastel | 부드러운 톤 정물 | 베이비핑크/민트 |
| Monochrome | 흑백 인물 / 도시 | 풍부한 콘트라스트 |
| Portrait | 자연광 인물 | 부드러운 피부 |
| Food | 음식 클로즈업 | 따뜻한 톤 |
| Travel | 풍경 / 여행 모먼트 | 청량한 하이라이트 |
| Mood | 감성 정물 / 추상 | 깊은 톤 |

**자산 위치**: `Sources/App/Resources/Assets.xcassets/Categories/{name}.imageset/`

---

## 3. Onboarding 일러스트 4종 (P1)

`OnboardingScreen` 4-페이지 캐러셀 — 현재 카드 스택 그라디언트 사용 중.
사용자가 앱을 처음 만나는 화면이므로 가장 임팩트 있는 자산이 필요.

| 페이지 | 메시지 | 일러스트 컨셉 |
|---|---|---|
| 01 | "moodit 으로 무드를 바꿔보세요" | 카메라 + 빛 광선 |
| 02 | "취향에 맞는 필터를 발견하세요" | 사진 카드 부채꼴 펼침 |
| 03 | "원하는 강도로 자유롭게" | 슬라이더 + 비포/애프터 분할 |
| 04 | "메이커가 되어 공유하세요" | 사람 + 손에서 빛나는 카드 |

**스타일**: 라이트 모드 톤 (베이지 화이트 배경 + 골드 악센트). 라인 일러스트 또는 부드러운 vector.

---

## 4. App Store / 마케팅 (P2)

| 자산 | 비율 | 용도 |
|---|---|---|
| App Store 스크린샷 (5.5") | 1242×2208 | 마켓플레이스 / 카메라 / 에디터 / 프로필 |
| App Store 스크린샷 (6.7") | 1290×2796 | 동일 |
| 프로모션 영상 (15s) | 9:16 | 카메라 → 필터 적용 → 저장 시퀀스 |
| 앱 미리보기 포스터 | 9:16 | 프로모션 영상 1프레임 |

---

## 5. 권한 priming 일러스트 4종 (P2)

현재 SF Symbol 단일 — 권한 프롬프트 직전 priming 화면.

| 권한 | 컨셉 |
|---|---|
| Camera | 카메라 + 빛 |
| Photos | 사진첩 + 화살표 (받기) |
| Notifications | 종 + 부드러운 신호 |
| Location | 핀 + 지도 그리드 |

---

## 6. 우선순위

| 우선 | 항목 | 영향 |
|---|---|---|
| P0 | 시드 필터 비포/애프터 (5종 × 3장) | 마켓 첫 인상, 가장 큰 시각 변화 |
| P0 | 시드 필터 커버 (5종) | FilterTile 시각 풍부함 |
| P1 | 카테고리 대표 사진 (8종) | 검색 진입점 |
| P1 | Onboarding 일러스트 (4종) | 첫 사용자 경험 |
| P2 | 권한 priming 일러스트 (4종) | 권한 수락률 |
| P2 | App Store 자산 | 출시 직전 |

---

## 7. Procedural Fallback 시스템 (현재 상태)

실제 자산 도입 전까지 다음 procedural illustration 으로 대체:

| 자산 | 대체 | 위치 |
|---|---|---|
| 시드 필터 커버 | `FMFilterCoverArt(motif:)` | `Sources/DesignSystem/Components/FMFilterCoverArt.swift` |
| Empty state 일러스트 | `FMEmptyStateIllustration(_:)` | `Sources/DesignSystem/Components/FMEmptyStateIllustration.swift` |
| 아바타 | initials + gradient | (현재 인라인) |
| 필터 그리드 placeholder | `FMSkeleton.rect()` | `Sources/DesignSystem/Components/FMSkeleton.swift` |

실제 자산 도입 시 procedural 시스템은 fallback 으로만 동작하도록 분기:
```swift
Group {
    if let image = FilterCoverAssetSource.image(for: filter) {
        Image(uiImage: image).resizable()
    } else {
        FMFilterCoverArt(motif: .cinematic)
    }
}
```
