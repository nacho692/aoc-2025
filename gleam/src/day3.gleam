import gleam/bit_array
import gleam/int
import gleam/list
import gleam/string

fn max_with_idx(list: List(Int)) -> #(Int, Int) {
  list
  |> list.index_fold(#(0, 0), fn(acc, v, idx) {
    // Just a regular max, storing the index
    case acc {
      #(_, current_max) if v > current_max -> #(idx, v)
      _ -> acc
    }
  })
}

pub fn max_joltage(list: List(Int)) -> Int {
  let len = list.length(list)
  let #(fs_idx, fs_max) = max_with_idx(list.take(list, len - 1))
  let #(_, sd_max) = max_with_idx(list.split(list, fs_idx + 1).1)
  10 * fs_max + sd_max
}

pub fn max_joltage_n(list: List(Int), n: Int) -> Int {
  let len = list.length(list)
  let #(taken, extras) = list.split(list, len - n)
  let assert Ok(n) =
    max_joltage_n_tail(taken, extras, [])
    |> list.map(int.to_string)
    // [9, 8]  -> ["9", "8"]
    |> string.concat
    // -> "98"
    |> int.parse
  n
}

// There is a simpler way imo, sorting everything by value, idx and N times we get the max value with min_idx > idx > n
fn max_joltage_n_tail(
  list: List(Int),
  extras: List(Int),
  res: List(Int),
) -> List(Int) {
  case extras {
    [h, ..rest] -> {
      let with_extra = list.append(list, [h])
      let #(idx, max) = max_with_idx(with_extra)
      let #(_, taken) = list.split(with_extra, idx + 1)
      max_joltage_n_tail(taken, rest, [max, ..res])
    }
    [] -> list.reverse(res)
  }
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(BitArray, a)

fn read_text(path: String) -> Result(String, Nil) {
  case read_file(path) {
    Ok(bits) -> bit_array.to_string(bits)
    // Result(String, Nil)
    Error(_) -> Error(Nil)
  }
}

pub fn parse_input(input: String) -> List(List(Int)) {
  input
  |> string.split("\n")
  |> list.map(fn(input_line: String) {
    case
      input_line
      |> string.to_graphemes
      |> list.try_map(int.parse)
    {
      Ok(digits) -> digits
      Error(_) -> []
    }
  })
}

pub fn part1() {
  let assert Ok(text) = read_text("src/day3.input")
  text
  |> string.trim
  |> parse_input
  |> list.map(max_joltage)
  |> list.fold(0, int.add)
}

pub fn part2() {
  let assert Ok(text) = read_text("src/day3.input")
  text
  |> string.trim
  |> parse_input
  |> list.map(max_joltage_n(_, 12))
  |> list.fold(0, int.add)
}
