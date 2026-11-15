fn main() {
    // Require the builder to enable exactly one feature selecting an application
    // from Demikernel's examples/rust so the system can compile.
    let selected = std::env::vars_os()
        .filter(|(name, _)| name.to_string_lossy().starts_with("CARGO_FEATURE_APP_"))
        .count();

    assert_eq!(selected, 1, "select exactly one app-* feature");
}
