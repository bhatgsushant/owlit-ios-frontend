import SwiftUI

struct AnimatedText: View, Animatable {
    var value: Double
    var formatType: FormatType
    var checkIsInt: Bool = false
    
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    
    enum FormatType {
        case currency
        case percent
        case number
        case custom(String)
    }
    
    var body: some View {
        Text(formattedString)
            // Font/Color modifiers will be applied by parent
    }
    
    private var formattedString: String {
        switch formatType {
        case .currency:
            // Simple GB Currency
            return String(format: "£%.2f", value)
        case .percent:
            return String(format: "%.1f%%", value)
        case .number:
            if checkIsInt {
                 return String(format: "%.0f", value)
            }
            return String(format: "%.0f", value)
        case .custom(let fmt):
            return String(format: fmt, value)
        }
    }
}
