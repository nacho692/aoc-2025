import gleam/int
import gleam/list
import gleam/string
import utils

type Range {
  Range(from: Int, to: Int)
}

fn in_range(range: Range, n: Int) -> Bool {
  n >= range.from && n <= range.to
}

fn parse_range(text: String) -> Range {
  let assert Ok(#(from_text, to_text)) =
    text |> string.trim |> string.split_once("-")

  let assert Ok(from) = int.parse(from_text)
  let assert Ok(to) = int.parse(to_text)
  Range(from: from, to: to)
}

fn parse_id(text: String) -> Int {
  let assert Ok(id) = int.parse(text)
  id
}

fn merge_ranges(ranges: List(Range)) -> List(Range) {
  ranges
  |> list.sort(fn(r1: Range, r2: Range) { int.compare(r1.from, r2.from) })
  |> list.fold([], fn(acc: List(Range), range: Range) {
    case acc {
      // Since they are sorted, range.from >= fst.from.
      // Given that, they only overlap if range.from <= fst.to, if range.from > fst.to, there is a gap
      [fst, ..rest] if range.from <= fst.to -> {
        [Range(from: fst.from, to: int.max(range.to, fst.to)), ..rest]
      }
      _ -> [range, ..acc]
    }
  })
}

pub fn part1() {
  let assert Ok(text) = utils.read_text("src/day5.input")
  let assert Ok(#(ranges_text, ids_text)) = string.split_once(text, "\n\n")
  let ranges =
    ranges_text
    |> string.trim
    |> string.split("\n")
    |> list.map(parse_range)
  let ids =
    ids_text
    |> string.trim
    |> string.split("\n")
    |> list.map(parse_id)

  ids
  |> list.count(fn(id) {
    ranges
    |> list.any(fn(range) { in_range(range, id) })
  })
}

pub fn part2() {
  let assert Ok(text) = utils.read_text("src/day5.input")
  let assert Ok(#(ranges_text, _)) = string.split_once(text, "\n\n")
  let ranges =
    ranges_text
    |> string.trim
    |> string.split("\n")
    |> list.map(parse_range)
    |> merge_ranges
  ranges
  |> list.map(fn(range) { range.to - range.from + 1 })
  |> int.sum
}

pub fn main() {
  echo part1()
  echo part2()
}
