use rust_library_fixture::hello;

#[test]
fn hello_returns_world() {
    assert_eq!(hello(), "world");
}
