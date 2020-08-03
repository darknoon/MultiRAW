import Foundation

extension FourCharCode {
    var debugDescription: String {
        let array = withUnsafeBytes(of: self.littleEndian, Array.init)
        let chars: [Character] = array.map{ Character(Unicode.Scalar($0)) }
        return String(chars)
    }
}
