import Carbon
import Foundation

private func tisString(_ value: CFString?) -> String? {
  guard let value else { return nil }
  return value as String
}

private struct ManagedInputSourceSession {
  let previousSource: TISInputSource
  let previousID: String
  let selectedEnglishID: String
}

private struct EnglishInputSourceCandidate {
  let source: TISInputSource
  let id: String
  let localizedName: String
  let sourceType: String
  let languages: [String]

  var languageRank: Int {
    languages.contains { language in
      let normalized = language.replacingOccurrences(of: "_", with: "-").lowercased()
      return normalized == "en" || normalized == "en-us"
    } ? 0 : 1
  }

  var nameRank: Int {
    let normalizedName = localizedName.lowercased()
    let normalizedID = id.lowercased()
    return normalizedName.contains("abc")
      || normalizedName.contains("u.s.")
      || normalizedName.contains("us")
      || normalizedID.contains("abc")
      || normalizedID.contains("u.s.")
      || normalizedID.contains("us") ? 0 : 1
  }

  var typeRank: Int {
    if sourceType == tisString(kTISTypeKeyboardLayout) {
      return 0
    }

    if sourceType == tisString(kTISTypeKeyboardInputMode) {
      return 1
    }

    if sourceType == tisString(kTISTypeKeyboardInputMethodWithoutModes) {
      return 2
    }

    return 3
  }
}

final class InputSourceManager {
  static let shared = InputSourceManager()

  private var autoSwitchEnglishInputOnHotkey = false
  private var activeSession: ManagedInputSourceSession?
  private var didShowFailureNotice = false

  private init() {}

  func setAutoSwitchEnglishInputOnHotkey(_ enabled: Bool) {
    autoSwitchEnglishInputOnHotkey = enabled

    if !enabled {
      activeSession = nil
    }
  }

  func beginHotkeySessionIfNeeded() {
    guard autoSwitchEnglishInputOnHotkey else {
      activeSession = nil
      return
    }

    guard let currentSource = Self.currentSource(), let currentID = Self.inputSourceID(currentSource) else {
      showFailureNoticeOnce()
      return
    }

    if Self.isEnglishSource(currentSource) {
      activeSession = nil
      return
    }

    guard let englishSource = Self.bestEnglishSource(), let englishID = Self.inputSourceID(englishSource)
    else {
      showFailureNoticeOnce()
      return
    }

    if currentID == englishID {
      activeSession = nil
      return
    }

    let status = TISSelectInputSource(englishSource)
    guard status == noErr, Self.currentSourceID() == englishID else {
      _ = TISSelectInputSource(currentSource)
      activeSession = nil
      showFailureNoticeOnce()
      return
    }

    activeSession = ManagedInputSourceSession(
      previousSource: currentSource,
      previousID: currentID,
      selectedEnglishID: englishID
    )
  }

  func restoreAfterHotkeySessionIfNeeded() {
    guard let session = activeSession else { return }
    activeSession = nil

    guard Self.currentSourceID() == session.selectedEnglishID else {
      return
    }

    _ = TISSelectInputSource(session.previousSource)
  }

  func rollbackHotkeySessionIfNeeded() {
    guard let session = activeSession else { return }
    activeSession = nil

    if Self.currentSourceID() != session.previousID {
      _ = TISSelectInputSource(session.previousSource)
    }
  }

  private func showFailureNoticeOnce() {
    guard !didShowFailureNotice else { return }
    didShowFailureNotice = true

    DispatchQueue.main.async {
      ToastManager.shared.showToast(
        "Navia could not switch to an English input source.",
        variant: "error",
        timeout: 4,
        image: nil
      )
    }
  }

  private static func currentSource() -> TISInputSource? {
    TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
  }

  private static func currentSourceID() -> String? {
    guard let source = currentSource() else { return nil }
    return inputSourceID(source)
  }

  private static func bestEnglishSource() -> TISInputSource? {
    englishCandidates().sorted(by: isPreferredEnglishCandidate).first?.source
  }

  private static func englishCandidates() -> [EnglishInputSourceCandidate] {
    let sourceList = TISCreateInputSourceList(nil, false).takeRetainedValue() as! [TISInputSource]

    return sourceList.compactMap { source -> EnglishInputSourceCandidate? in
      guard isSelectableKeyboardSource(source), isEnglishSource(source) else { return nil }
      guard let id = inputSourceID(source) else { return nil }

      return EnglishInputSourceCandidate(
        source: source,
        id: id,
        localizedName: stringProperty(source, kTISPropertyLocalizedName) ?? "",
        sourceType: stringProperty(source, kTISPropertyInputSourceType) ?? "",
        languages: stringArrayProperty(source, kTISPropertyInputSourceLanguages)
      )
    }
  }

  private static func isPreferredEnglishCandidate(
    _ lhs: EnglishInputSourceCandidate,
    _ rhs: EnglishInputSourceCandidate
  ) -> Bool {
    if lhs.languageRank != rhs.languageRank { return lhs.languageRank < rhs.languageRank }
    if lhs.nameRank != rhs.nameRank { return lhs.nameRank < rhs.nameRank }
    if lhs.typeRank != rhs.typeRank { return lhs.typeRank < rhs.typeRank }

    let nameComparison = lhs.localizedName.localizedCaseInsensitiveCompare(rhs.localizedName)
    if nameComparison != .orderedSame { return nameComparison == .orderedAscending }

    return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
  }

  private static func isSelectableKeyboardSource(_ source: TISInputSource) -> Bool {
    guard stringProperty(source, kTISPropertyInputSourceCategory) == tisString(kTISCategoryKeyboardInputSource)
    else { return false }

    return boolProperty(source, kTISPropertyInputSourceIsSelectCapable)
  }

  private static func isEnglishSource(_ source: TISInputSource) -> Bool {
    stringArrayProperty(source, kTISPropertyInputSourceLanguages).contains { language in
      let normalized = language.replacingOccurrences(of: "_", with: "-").lowercased()
      return normalized == "en" || normalized.hasPrefix("en-")
    }
  }

  private static func inputSourceID(_ source: TISInputSource) -> String? {
    stringProperty(source, kTISPropertyInputSourceID)
  }

  private static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? String
  }

  private static func stringArrayProperty(_ source: TISInputSource, _ key: CFString) -> [String] {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return [] }
    guard let array = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? [Any]
    else { return [] }
    return array.compactMap { $0 as? String }
  }

  private static func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return false }
    if let value = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? NSNumber {
      return value.boolValue
    }
    return false
  }

}
