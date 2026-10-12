// Manual, autostart and helper launches stay console-free in every build profile.
#![cfg_attr(windows, windows_subsystem = "windows")]

fn main() {
    // WebView2's property setter can leave one white frame during creation.
    // Set the initial transparent color before any WebView or worker exists.
    #[cfg(windows)]
    std::env::set_var("WEBVIEW2_DEFAULT_BACKGROUND_COLOR", "00000000");
    music_island_lib::run()
}
