pub mod v1 {
    include!(concat!(env!("OUT_DIR"), "/loanx.v1.rs"));
}
pub const PROTOCOL_MAJOR: u32 = 1;
pub const MAX_FRAME_BYTES: usize = 1024 * 1024;
