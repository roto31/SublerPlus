import Foundation

/// Subtitle styling configuration for TX3G tracks
public struct SubtitleStyle: Sendable, Codable {
    public struct Color: Sendable, Codable {
        public let red: UInt8
        public let green: UInt8
        public let blue: UInt8
        public let alpha: UInt8
        
        public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }
        
        /// White color (default)
        public static var white: Color {
            Color(red: 255, green: 255, blue: 255)
        }
        
        /// Yellow color
        public static var yellow: Color {
            Color(red: 255, green: 255, blue: 0)
        }
    }
    
    public enum HorizontalJustification: UInt8, Sendable, Codable {
        case left = 0
        case center = 1
        case right = 2
    }
    
    public enum VerticalJustification: Int8, Sendable, Codable {
        case top = -1
        case center = 0
        case bottom = 1
    }
    
    public var fontName: String
    public var fontSize: UInt8
    public var textColor: Color
    public var backgroundColor: Color
    public var horizontalJustification: HorizontalJustification
    public var verticalJustification: VerticalJustification
    public var textBox: TextBox?
    
    public struct TextBox: Sendable, Codable {
        public let top: UInt32
        public let left: UInt32
        public let bottom: UInt32
        public let right: UInt32
        
        public init(top: UInt32, left: UInt32, bottom: UInt32, right: UInt32) {
            self.top = top
            self.left = left
            self.bottom = bottom
            self.right = right
        }
    }
    
    public init(
        fontName: String = "Helvetica",
        fontSize: UInt8 = 12,
        textColor: Color = .white,
        backgroundColor: Color = Color(red: 0, green: 0, blue: 0, alpha: 0),
        horizontalJustification: HorizontalJustification = .center,
        verticalJustification: VerticalJustification = .bottom,
        textBox: TextBox? = nil
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.horizontalJustification = horizontalJustification
        self.verticalJustification = verticalJustification
        self.textBox = textBox
    }
    
    /// Default style matching Subler's defaults
    public static var `default`: SubtitleStyle {
        SubtitleStyle()
    }
}

