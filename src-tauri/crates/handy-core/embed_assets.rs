use flate2::{write::ZlibEncoder, Compression};
use sha2::{Digest, Sha256};
use std::{
    fs,
    io::Write,
    path::{Path, PathBuf},
};

fn write_if_changed(path: &Path, bytes: &[u8]) {
    if !fs::read(path).is_ok_and(|existing| existing == bytes) {
        fs::write(path, bytes).expect("write embedded asset");
    }
}

pub fn embed_files(mut files: Vec<(String, PathBuf)>, output: &Path, symbol: &str) {
    files.sort_by(|a, b| a.0.cmp(&b.0));
    let mut source = format!("static {symbol}: &[EmbeddedAsset] = &[\n");
    for (name, path) in files {
        println!("cargo:rerun-if-changed={}", path.display());
        let bytes = fs::read(&path).expect("read embedded asset");
        let sha256: [u8; 32] = Sha256::digest(&bytes).into();
        let mut encoder = ZlibEncoder::new(Vec::new(), Compression::best());
        encoder.write_all(&bytes).expect("compress embedded asset");
        let packed = output.with_file_name(format!("{symbol}-{:x}.zlib", Sha256::digest(&bytes)));
        write_if_changed(
            &packed,
            &encoder.finish().expect("finish asset compression"),
        );
        source.push_str(&format!(
            "EmbeddedAsset {{ name: {name:?}, size: {}, sha256: {sha256:?}, packed: include_bytes!({:?}) }},\n",
            bytes.len(), packed.to_str().unwrap()
        ));
    }
    source.push_str("];\n");
    write_if_changed(output, source.as_bytes());
}

pub fn embed_directory(root: &Path, output: &Path, symbol: &str) {
    fn collect(root: &Path, dir: &Path, files: &mut Vec<(String, PathBuf)>) {
        println!("cargo:rerun-if-changed={}", dir.display());
        for entry in fs::read_dir(dir).expect("read asset directory") {
            let entry = entry.unwrap();
            let name = entry.file_name();
            // Portable builds never carry virtual microphone drivers or placeholder files.
            if name.to_string_lossy().starts_with('.') || name == "vb-cable" {
                continue;
            }
            let path = entry.path();
            if entry.file_type().unwrap().is_dir() {
                collect(root, &path, files);
            } else {
                files.push((
                    path.strip_prefix(root)
                        .unwrap()
                        .to_str()
                        .unwrap()
                        .replace('\\', "/"),
                    path,
                ));
            }
        }
    }
    let mut files = Vec::new();
    collect(root, root, &mut files);
    embed_files(files, output, symbol);
}
