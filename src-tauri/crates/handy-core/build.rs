use std::{env, fs, path::PathBuf};
mod embed_assets;
fn main() {
    println!("cargo:rerun-if-env-changed=MUSIC_ISLAND_DICTATION_BUNDLE");
    let output = PathBuf::from(env::var_os("OUT_DIR").unwrap());
    embed_assets::embed_directory(
        std::path::Path::new("resources"),
        &output.join("handy_assets.rs"),
        "HANDY_FILES",
    );
    let mut files = Vec::new();
    if let Some(directory) = env::var_os("MUSIC_ISLAND_DICTATION_BUNDLE") {
        let directory = fs::canonicalize(directory).expect("Dictation bundle does not exist");
        println!("cargo:rerun-if-changed={}", directory.display());
        let mut paths: Vec<_> = fs::read_dir(directory)
            .unwrap()
            .map(|e| e.unwrap().path())
            .filter(|p| p.extension().is_some_and(|e| e == "dll"))
            .collect();
        paths.sort();
        assert!(
            paths
                .iter()
                .any(|p| p.file_name().unwrap() == "music_island_dictation.dll"),
            "Build the inference DLL before packaging Music Island"
        );
        for path in paths {
            files.push((path.file_name().unwrap().to_str().unwrap().to_owned(), path));
        }
    } else if env::var("PROFILE").as_deref() == Ok("release") {
        panic!("Portable release requires MUSIC_ISLAND_DICTATION_BUNDLE; use the portable build script");
    }
    embed_assets::embed_files(files, &output.join("runtime_assets.rs"), "RUNTIME_FILES");
}
