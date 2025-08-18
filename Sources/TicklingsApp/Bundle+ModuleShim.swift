#if !SWIFT_PACKAGE
import Foundation
extension Bundle {
    static var module: Bundle { Bundle.main }
}
#endif
