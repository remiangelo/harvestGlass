import Foundation

enum HeightFormatter {
    static func feetAndInches(from centimeters: Int) -> (feet: Int, inches: Int) {
        let totalInches = Int((Double(centimeters) / 2.54).rounded())
        return (totalInches / 12, totalInches % 12)
    }

    static func string(from centimeters: Int) -> String {
        let converted = feetAndInches(from: centimeters)
        return "\(converted.feet)'\(converted.inches)\""
    }
}
