import SwiftUI
import Combine

// MARK: - Theme Types
enum AppTheme: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case auto = "Auto"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .auto:
            return nil // Uses system setting
        }
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var selectedTheme: AppTheme {
        didSet {
            saveTheme()
        }
    }
    
    private let themeKey = "selectedTheme"
    
    private init() {
        // Load saved theme or default to auto
        if let savedTheme = UserDefaults.standard.string(forKey: themeKey),
           let theme = AppTheme(rawValue: savedTheme) {
            self.selectedTheme = theme
        } else {
            self.selectedTheme = .auto
        }
    }
    
    private func saveTheme() {
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: themeKey)
    }
    
    func setTheme(_ theme: AppTheme) {
        selectedTheme = theme
    }
    
    // Returns a dynamic color that adapts to the current theme setting
    func dynamicColor(light: Color, dark: Color) -> Color {
        switch selectedTheme {
        case .light:
            return light
        case .dark:
            return dark
        case .auto:
            // In auto mode, use the system setting
            return Color(UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor(dark)
                default:
                    return UIColor(light)
                }
            })
        }
    }
    
    // Applies the current theme to the app
    func applyTheme(to view: some View) -> some View {
        return view.preferredColorScheme(selectedTheme.colorScheme)
    }
}

// MARK: - View Extension
extension View {
    func applyTheme() -> some View {
        ThemeManager.shared.applyTheme(to: self)
    }
}
