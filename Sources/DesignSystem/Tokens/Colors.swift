import SwiftUI
import UIKit

// MARK: - Color(light:dark:) helper

public extension Color {
    /// 라이트/다크 듀얼 컬러 헬퍼.
    /// - Note: `UITraitCollection.userInterfaceStyle` 에 따라 자동 전환.
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// HEX 헬퍼 — `#RRGGBB` 또는 `#RRGGBBAA`.
    init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: Double(alpha))
    }
}

private extension UIColor {
    convenience init(rgb hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

// MARK: - FMColors namespace

/// filterMarket 디자인 토큰 컬러.
/// JSON v1.2.0 — `docs/DESIGN_TOKENS.json` 의 `modes.light` / `modes.dark` 와 1:1 정합.
public enum FMColors {
    // MARK: Background

    public enum Background {
        /// 메인 캔버스 — light: #FAFAF7, dark: #000000
        public static let bg0 = Color(
            light: UIColor(rgb: 0xFAFAF7),
            dark: UIColor(rgb: 0x000000)
        )
        /// 화면 기본 배경 (sunken) — light: #F5F4EF, dark: #0A0A0A
        public static let bg1 = Color(
            light: UIColor(rgb: 0xF5F4EF),
            dark: UIColor(rgb: 0x0A0A0A)
        )
        /// raised 카드/모달 — light: #FFFFFF, dark: #141414
        public static let bg2 = Color(
            light: UIColor(rgb: 0xFFFFFF),
            dark: UIColor(rgb: 0x141414)
        )
        /// 구분/strong sunken — light: #EDEBE5, dark: #1F1F1F
        public static let bg3 = Color(
            light: UIColor(rgb: 0xEDEBE5),
            dark: UIColor(rgb: 0x1F1F1F)
        )
    }

    // MARK: Surface

    public enum Surface {
        /// 모달/시트 컨테이너 — light: #FFFFFF, dark: #1F1F1F
        public static let raised = Color(
            light: UIColor(rgb: 0xFFFFFF),
            dark: UIColor(rgb: 0x1F1F1F)
        )
        /// 비교 슬라이더, 코드블록 — light: #EDEBE5, dark: #050505
        public static let sunken = Color(
            light: UIColor(rgb: 0xEDEBE5),
            dark: UIColor(rgb: 0x050505)
        )
        /// 스크림 (백드롭) — light: rgba(15,15,14,0.42), dark: rgba(0,0,0,0.72)
        public static let overlay = Color(
            light: UIColor(rgb: 0x0F0F0E, alpha: 0.42),
            dark: UIColor(rgb: 0x000000, alpha: 0.72)
        )
    }

    // MARK: Border

    public enum Border {
        /// 1px 분리선
        public static let subtle = Color(
            light: UIColor(rgb: 0xE8E6E0),
            dark: UIColor(rgb: 0x1F1F1F)
        )
        /// 카드 외곽선
        public static let `default` = Color(
            light: UIColor(rgb: 0xD8D5CD),
            dark: UIColor(rgb: 0x2A2A2A)
        )
        /// 포커스 외곽선
        public static let strong = Color(
            light: UIColor(rgb: 0xB8B4A8),
            dark: UIColor(rgb: 0x3A3A3A)
        )
    }

    // MARK: Text

    public enum Text {
        /// 본문/타이틀 (딥 차콜)
        public static let primary = Color(
            light: UIColor(rgb: 0x0F0F0E),
            dark: UIColor(rgb: 0xFFFFFF)
        )
        /// 서브타이틀, 메타
        public static let secondary = Color(
            light: UIColor(rgb: 0x4A4845),
            dark: UIColor(rgb: 0xA8A8A8)
        )
        /// 캡션, 비활성 라벨
        public static let tertiary = Color(
            light: UIColor(rgb: 0x8A8782),
            dark: UIColor(rgb: 0x6B6B6B)
        )
        /// 비활성 텍스트
        public static let disabled = Color(
            light: UIColor(rgb: 0xC8C5BE),
            dark: UIColor(rgb: 0x3A3A3A)
        )
        /// 악센트 위 텍스트 (인버스)
        public static let inverse = Color(
            light: UIColor(rgb: 0xFFFFFF),
            dark: UIColor(rgb: 0x0A0A0A)
        )
    }

    // MARK: Accent (Gold)

    public enum Accent {
        /// CTA, 활성 탭, 강조 — light: #B8853A, dark: #E8B86D
        public static let primary = Color(
            light: UIColor(rgb: 0xB8853A),
            dark: UIColor(rgb: 0xE8B86D)
        )
        /// 호버 / 롱프레스 직전
        public static let hover = Color(
            light: UIColor(rgb: 0xA0721E),
            dark: UIColor(rgb: 0xF0C683)
        )
        /// 탭 다운
        public static let pressed = Color(
            light: UIColor(rgb: 0x8B5E1F),
            dark: UIColor(rgb: 0xC99A52)
        )
        /// 장식·테두리·아이콘 fill (텍스트 X) — light: #E8B86D
        public static let soft = Color(
            light: UIColor(rgb: 0xE8B86D),
            dark: UIColor(rgb: 0xE8B86D, alpha: 0.16)
        )
        /// 옅은 악센트 배경 fill — light: #FBF3E2
        public static let bg = Color(
            light: UIColor(rgb: 0xFBF3E2),
            dark: UIColor(rgb: 0xE8B86D, alpha: 0.10)
        )
        /// 포커스 링 (4px)
        public static let ring = Color(
            light: UIColor(rgb: 0xB8853A, alpha: 0.32),
            dark: UIColor(rgb: 0xE8B86D, alpha: 0.40)
        )
    }

    // MARK: Semantic

    public enum Semantic {
        public static let success = Color(
            light: UIColor(rgb: 0x2E7D44),
            dark: UIColor(rgb: 0x5FB37C)
        )
        public static let successBg = Color(
            light: UIColor(rgb: 0xE8F2EA),
            dark: UIColor(rgb: 0x5FB37C, alpha: 0.16)
        )
        public static let warning = Color(
            light: UIColor(rgb: 0xA66B0F),
            dark: UIColor(rgb: 0xD9A441)
        )
        public static let warningBg = Color(
            light: UIColor(rgb: 0xFBF1DC),
            dark: UIColor(rgb: 0xD9A441, alpha: 0.16)
        )
        public static let error = Color(
            light: UIColor(rgb: 0xB33A2A),
            dark: UIColor(rgb: 0xD96B6B)
        )
        public static let errorBg = Color(
            light: UIColor(rgb: 0xF8E5E0),
            dark: UIColor(rgb: 0xD96B6B, alpha: 0.16)
        )
        public static let info = Color(
            light: UIColor(rgb: 0x1F5FA8),
            dark: UIColor(rgb: 0x6B9AD9)
        )
        public static let infoBg = Color(
            light: UIColor(rgb: 0xE5EEF8),
            dark: UIColor(rgb: 0x6B9AD9, alpha: 0.16)
        )
    }

    // MARK: Category Hint

    public enum Category {
        public static let cinematic = Color(
            light: UIColor(rgb: 0x7E5FB8),
            dark: UIColor(rgb: 0x9C7BD9)
        )
        public static let vintage = Color(
            light: UIColor(rgb: 0xA57238),
            dark: UIColor(rgb: 0xC99A52)
        )
        public static let pastel = Color(
            light: UIColor(rgb: 0xC485A6),
            dark: UIColor(rgb: 0xE5A8C6)
        )
        public static let monochrome = Color(
            light: UIColor(rgb: 0x7A7A7A),
            dark: UIColor(rgb: 0xA8A8A8)
        )
        public static let portrait = Color(
            light: UIColor(rgb: 0xC77859),
            dark: UIColor(rgb: 0xE89A7B)
        )
        public static let food = Color(
            light: UIColor(rgb: 0xA66B0F),
            dark: UIColor(rgb: 0xD9A441)
        )
        public static let travel = Color(
            light: UIColor(rgb: 0x3A7AB8),
            dark: UIColor(rgb: 0x6BB3D9)
        )
        public static let mood = Color(
            light: UIColor(rgb: 0x5A6E96),
            dark: UIColor(rgb: 0x7B8FB3)
        )
    }

    // MARK: Skeleton (state)

    public enum Skeleton {
        public static let base = Color(
            light: UIColor(rgb: 0xEDEBE5),
            dark: UIColor(rgb: 0x1F1F1F)
        )
        public static let highlight = Color(
            light: UIColor(rgb: 0xF8F6F0),
            dark: UIColor(rgb: 0x2A2A2A)
        )
    }

    // MARK: Overlay (state)

    public enum Overlay {
        /// 모달 백드롭 (alert/confirm용)
        public static let scrim = Color(
            light: UIColor(rgb: 0x0F0F0E, alpha: 0.60),
            dark: UIColor(rgb: 0x000000, alpha: 0.72)
        )
        /// backdrop-blur 위 흐림 fill
        public static let blur = Color(
            light: UIColor(rgb: 0xFFFFFF, alpha: 0.72),
            dark: UIColor(rgb: 0x141414, alpha: 0.72)
        )
    }

    // MARK: Empty (state)

    public enum Empty {
        public static let illustrationTint = Color(
            light: UIColor(rgb: 0xC8C5BE),
            dark: UIColor(rgb: 0x3A3A3A)
        )
        public static let illustrationAccent = Color(
            light: UIColor(rgb: 0xE8B86D),
            dark: UIColor(rgb: 0xE8B86D)
        )
    }
}
