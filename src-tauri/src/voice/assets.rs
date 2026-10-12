//! Voice libraries are verified and extracted into AppData from lossless payloads.
use handy_core::embedded_assets::{extract_assets, EmbeddedAsset};
use std::path::PathBuf;
include!(concat!(env!("OUT_DIR"), "/voice_assets.rs"));

/// VB-Cable is not embedded; users install it from the vendor site.
pub fn ensure_voice_resources() -> Result<PathBuf, String> {
    let dest = PathBuf::from(std::env::var_os("APPDATA").ok_or("APPDATA unavailable")?)
        .join("Music Island")
        .join("voice");
    extract_assets(VOICE_FILES, &dest).map_err(|e| format!("voice resources: {e:#}"))?;
    Ok(dest)
}
