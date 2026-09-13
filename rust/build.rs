use std::{env, io, path::PathBuf};

fn main() -> io::Result<()> {
    let manifest = PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").unwrap());
    let protocol_root = manifest.join("../../protocol");
    let schema = protocol_root.join("loanx/v1/envelope.proto");
    println!("cargo:rerun-if-changed={}", schema.display());
    let mut config = prost_build::Config::new();
    config.protoc_executable(protoc_bin_vendored::protoc_bin_path().map_err(io::Error::other)?);
    config.compile_protos(&[schema], &[protocol_root])
}
