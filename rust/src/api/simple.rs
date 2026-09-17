#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Do not use `setup_default_user_utils`: it enables trace logging on
    // Android, which causes rustls to emit full TLS handshakes (including
    // certificate data) into logcat for every cloud request.
    flutter_rust_bridge::setup_log_to_console(log::LevelFilter::Warn);
    flutter_rust_bridge::setup_backtrace();
}
