use crate::embedded_assets::EmbeddedAsset;
use std::path::PathBuf;
use std::sync::OnceLock;
static DATA: OnceLock<PathBuf> = OnceLock::new();
include!(concat!(env!("OUT_DIR"), "/handy_assets.rs"));
pub fn init() {
    crate::storage::remember_hf();
    let root = data_dir().unwrap();
    std::env::set_var("HF_HOME", root.join("huggingface"));
    std::env::set_var("HF_HUB_CACHE", root.join("huggingface/hub"));
}
pub fn data_dir() -> Option<&'static PathBuf> {
    Some(DATA.get_or_init(|| {
        std::env::var_os("APPDATA")
            .map(PathBuf::from)
            .expect("APPDATA unavailable")
            .join("Music Island")
            .join("dictation")
    }))
}
pub fn is_portable() -> bool {
    true
}
pub fn app_data_dir(_: &tauri::AppHandle) -> Result<PathBuf, tauri::Error> {
    Ok(data_dir().unwrap().clone())
}
pub fn app_log_dir(_: &tauri::AppHandle) -> Result<PathBuf, tauri::Error> {
    Ok(data_dir().unwrap().join("logs"))
}
pub fn resolve_app_data(app: &tauri::AppHandle, relative: &str) -> Result<PathBuf, tauri::Error> {
    Ok(app_data_dir(app)?.join(relative))
}
pub fn store_path(relative: &str) -> PathBuf {
    data_dir().unwrap().join(relative)
}
pub fn resources() -> PathBuf {
    data_dir().unwrap().join("runtime").join("handy-0.9.7")
}
pub fn extract_resources() -> std::io::Result<()> {
    crate::embedded_assets::extract_assets(HANDY_FILES, &resources().join("resources"))
        .map_err(std::io::Error::other)
}

pub fn prepare_storage() -> anyhow::Result<()> {
    let root = data_dir().unwrap();
    crate::runtime::checked_directory(root)?;
    for folder in [
        "models",
        "huggingface",
        "huggingface/hub",
        "history",
        "recordings",
        "downloads",
        "runtime",
        "logs",
    ] {
        crate::runtime::checked_directory(&root.join(folder))?;
    }
    Ok(())
}
