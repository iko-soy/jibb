fn main() {
    println!("cargo:rerun-if-changed=src/parser.c");
    println!("cargo:rerun-if-changed=src/scanner.c");
    println!("cargo:rerun-if-changed=src/tree_sitter");

    cc::Build::new()
        .file("src/parser.c")
        .file("src/scanner.c")
        .warnings(false)
        .compile("jibb_tree_sitter");
}
