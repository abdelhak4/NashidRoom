import SwiftUI

// MARK: - Theme Color Names
public enum ThemeColor {
    case appBackground
    case secondaryBackground
    case tertiaryBackground
    case cardBackground
    case tabBarBackground
    case primaryText
    case secondaryText
    case tertiaryText
    case separatorColor
    case opaqueSeparator
    case selectedTabColor
    case unselectedTabColor
    case inputBackground
    case inputBorder
    case primaryBackground
    
    // Convert enum to Color
    public var color: Color {
        switch self {
        case .appBackground:
            return Color("appBackground")
        case .secondaryBackground:
            return Color("secondaryBackground")
        case .tertiaryBackground:
            return Color("tertiaryBackground")
        case .cardBackground:
            return Color("cardBackground")
        case .tabBarBackground:
            return Color("tabBarBackground")
        case .primaryText:
            return Color("primaryText")
        case .secondaryText:
            return Color("secondaryText")
        case .tertiaryText:
            return Color("tertiaryText")
        case .separatorColor:
            return Color("separatorColor")
        case .opaqueSeparator:
            return Color("opaqueSeparator")
        case .selectedTabColor:
            return Color("selectedTabColor")
        case .unselectedTabColor:
            return Color("unselectedTabColor")
        case .inputBackground:
            return Color("inputBackground")
        case .inputBorder:
            return Color("inputBorder")
        case .primaryBackground:
            return Color("appBackground") // Alias for appBackground
        }
    }
}

// MARK: - Color Extension for Easy Access
extension Color {
    // Only add the colors that don't conflict with system colors
    static var separatorColor: Color {
        return ThemeColor.separatorColor.color
    }
    
    static var selectedTabColor: Color {
        return ThemeColor.selectedTabColor.color
    }
    
    static var unselectedTabColor: Color {
        return ThemeColor.unselectedTabColor.color
    }
    
    // Theme-specific colors with 'theme' prefix to avoid conflicts
    static var themeAppBackground: Color {
        return ThemeColor.appBackground.color
    }
    
    static var themeSecondaryBackground: Color {
        return ThemeColor.secondaryBackground.color
    }
    
    static var themeTertiaryBackground: Color {
        return ThemeColor.tertiaryBackground.color
    }
    
    static var themeCardBackground: Color {
        return ThemeColor.cardBackground.color
    }
    
    static var themeTabBarBackground: Color {
        return ThemeColor.tabBarBackground.color
    }
    
    static var themePrimaryText: Color {
        return ThemeColor.primaryText.color
    }
    
    static var themeSecondaryText: Color {
        return ThemeColor.secondaryText.color
    }
    
    static var themeTertiaryText: Color {
        return ThemeColor.tertiaryText.color
    }
    
    static var themeOpaqueSeparator: Color {
        return ThemeColor.opaqueSeparator.color
    }
    
    static var themeInputBackground: Color {
        return ThemeColor.inputBackground.color
    }
    
    static var themeInputBorder: Color {
        return ThemeColor.inputBorder.color
    }
}

// MARK: - View Extensions for Theme Colors
public extension View {
    /// Apply a theme color as the foreground color
    func foregroundTheme(_ themeColor: ThemeColor) -> some View {
        self.foregroundColor(themeColor.color)
    }
    
    /// Apply a theme color as the background color
    func backgroundTheme(_ themeColor: ThemeColor) -> some View {
        self.background(themeColor.color)
    }
}

// MARK: - Preview Provider
struct ColorTheme_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Theme Colors - Light Mode")
                .font(.headline)
                .foregroundColor(ThemeColor.primaryText.color)
            
            Group {
                ColorRow("Background Colors", colors: [
                    ("appBackground", ThemeColor.appBackground),
                    ("secondaryBackground", ThemeColor.secondaryBackground),
                    ("tertiaryBackground", ThemeColor.tertiaryBackground),
                ])
                
                ColorRow("Card & Tab Colors", colors: [
                    ("cardBackground", ThemeColor.cardBackground),
                    ("tabBarBackground", ThemeColor.tabBarBackground),
                ])
                
                ColorRow("Text Colors", colors: [
                    ("primaryText", ThemeColor.primaryText),
                    ("secondaryText", ThemeColor.secondaryText),
                    ("tertiaryText", ThemeColor.tertiaryText),
                ])
                
                ColorRow("Tab Colors", colors: [
                    ("selectedTab", ThemeColor.selectedTabColor),
                    ("unselectedTab", ThemeColor.unselectedTabColor),
                ])
                
                ColorRow("Input & Separator", colors: [
                    ("inputBackground", ThemeColor.inputBackground),
                    ("inputBorder", ThemeColor.inputBorder),
                    ("separator", ThemeColor.separatorColor),
                ])
            }
        }
        .padding()
        .background(ThemeColor.appBackground.color)
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")
        
        VStack(spacing: 20) {
            Text("Theme Colors - Dark Mode")
                .font(.headline)
                .foregroundColor(ThemeColor.primaryText.color)
            
            Group {
                ColorRow("Background Colors", colors: [
                    ("appBackground", ThemeColor.appBackground),
                    ("secondaryBackground", ThemeColor.secondaryBackground),
                    ("tertiaryBackground", ThemeColor.tertiaryBackground),
                ])
                
                ColorRow("Card & Tab Colors", colors: [
                    ("cardBackground", ThemeColor.cardBackground),
                    ("tabBarBackground", ThemeColor.tabBarBackground),
                ])
                
                ColorRow("Text Colors", colors: [
                    ("primaryText", ThemeColor.primaryText),
                    ("secondaryText", ThemeColor.secondaryText),
                    ("tertiaryText", ThemeColor.tertiaryText),
                ])
                
                ColorRow("Tab Colors", colors: [
                    ("selectedTab", ThemeColor.selectedTabColor),
                    ("unselectedTab", ThemeColor.unselectedTabColor),
                ])
                
                ColorRow("Input & Separator", colors: [
                    ("inputBackground", ThemeColor.inputBackground),
                    ("inputBorder", ThemeColor.inputBorder),
                    ("separator", ThemeColor.separatorColor),
                ])
            }
        }
        .padding()
        .background(ThemeColor.appBackground.color)
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
    
    // Helper view for color previews
    struct ColorRow: View {
        let title: String
        let colors: [(name: String, color: ThemeColor)]
        
        init(_ title: String, colors: [(name: String, color: ThemeColor)]) {
            self.title = title
            self.colors = colors
        }
        
        var body: some View {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(ThemeColor.primaryText.color)
                
                HStack(spacing: 10) {
                    ForEach(colors, id: \.name) { colorInfo in
                        VStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorInfo.color.color)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(ThemeColor.separatorColor.color, lineWidth: 0.5)
                                )
                            
                            Text(colorInfo.name)
                                .font(.caption)
                                .foregroundColor(ThemeColor.secondaryText.color)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(width: 80)
                    }
                }
            }
        }
    }
}
