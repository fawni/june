import bindings/blake2
import gleam/bit_array
import gleam/string

pub fn hash(bits: BitArray) -> String {
  bits
  |> blake2.hash2b(8)
  |> bit_array.base16_encode
  |> string.lowercase
}
