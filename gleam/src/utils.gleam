import gleam/bit_array

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(BitArray, a)

pub fn read_text(path: String) -> Result(String, Nil) {
  case read_file(path) {
    Ok(bits) -> bit_array.to_string(bits)
    // Result(String, Nil)
    Error(_) -> Error(Nil)
  }
}
