import Foundation

func workflowDateString(_ date: Date) -> String {
    DateFormatter.workflowDate.string(from: date)
}

func workflowTimeString(_ date: Date) -> String {
    DateFormatter.workflowTime.string(from: date)
}

func parameterTitle(_ key: String) -> String {
    switch key {
    case "exposure": "노출"
    case "contrast": "대비"
    case "saturation": "채도"
    case "grain": "필름 그레인"
    case "vignette": "비네트"
    default: key.capitalized
    }
}

private extension DateFormatter {
    static let workflowDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy. M. d. HH:mm"
        return formatter
    }()

    static let workflowTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
