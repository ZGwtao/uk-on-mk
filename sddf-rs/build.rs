use std::{env, path::PathBuf, process::Command};

fn main() {
    println!("cargo:rerun-if-changed=src/net.c");
    println!("cargo:rerun-if-changed=src/timer.c");
    println!("cargo:rerun-if-env-changed=SDDF");
    if env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("none") {
        return;
    }

    let manifest = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let sddf = PathBuf::from(env::var("SDDF").expect("SDDF is required"));
    println!("cargo:rerun-if-changed={}", sddf.join("include").display());
    let sdk = env::var("MICROKIT_SDK").expect("MICROKIT_SDK is required");
    let board = env::var("MICROKIT_BOARD").unwrap_or_else(|_| "qemu_virt_aarch64".into());
    let config = env::var("MICROKIT_CONFIG").unwrap_or_else(|_| "debug".into());
    let out = PathBuf::from(env::var("OUT_DIR").unwrap());
    let mut objects = Vec::new();
    for source in ["net", "timer"] {
        let object = out.join(format!("sddf_{source}.o"));
        assert!(Command::new("clang")
            .args(["--target=aarch64-none-elf", "-std=gnu11", "-O2", "-ffreestanding", "-c"])
            .arg(manifest.join(format!("src/{source}.c")))
            .arg(format!("-I{sdk}/board/{board}/{config}/include"))
            .arg(format!("-I{}/include", sddf.display()))
            .arg(format!("-I{}/include/microkit", sddf.display()))
            .arg(format!("-I{}/include/sddf/util/custom_libc", sddf.display()))
            .arg("-o")
            .arg(&object)
            .status().unwrap().success());
        objects.push(object);
    }
    let archive = out.join("libsddf_rs.a");
    let mut ar = Command::new("llvm-ar");
    ar.arg("crs").arg(&archive).args(&objects);
    assert!(ar.status().unwrap().success());
    println!("cargo:rustc-link-search=native={}", out.display());
    println!("cargo:rustc-link-lib=static=sddf_rs");
}
