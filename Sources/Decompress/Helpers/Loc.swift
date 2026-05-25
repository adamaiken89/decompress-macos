import Foundation

func loc(_ key: String.LocalizationValue) -> String {
  String(localized: key, bundle: .module)
}
