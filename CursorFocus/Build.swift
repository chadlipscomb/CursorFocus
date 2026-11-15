/// Features that depend on how the app was built.
///
/// HOVER_ONLY leaves typing redirect out and keeps switch on hover, always
/// on. That build never touches the keyboard, so it needs one permission
/// (posting events, to click windows) instead of two, which is a much
/// easier sell to App Review. The AppStore configuration sets it; remove it
/// from SWIFT_ACTIVE_COMPILATION_CONDITIONS to ship the full app there.
enum Build {
    #if HOVER_ONLY
    static let redirectsTyping = false
    #else
    static let redirectsTyping = true
    #endif
}
