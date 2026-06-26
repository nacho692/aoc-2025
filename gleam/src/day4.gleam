import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/list
import gleam/string

type Space {
  Roll
  Empty
}

type Coord {
  Coord(x: Int, y: Int)
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

fn parse(text: String) -> dict.Dict(Coord, Space) {
  let lines = text |> string.split("\n")
  lines
  |> list.index_fold(dict.new(), fn(map, line, x) {
    line
    |> string.to_graphemes
    |> list.index_fold(map, fn(map, char, y) {
      dict.insert(map, Coord(x, y), case char {
        "." -> Empty
        "@" -> Roll
        _ -> panic as { "unexpected character: " <> char }
      })
    })
  })
}

fn neighbors(map: Dict(Coord, Space), coord: Coord) -> List(Space) {
  let to_get = [
    Coord(coord.x - 1, coord.y - 1),
    Coord(coord.x - 1, coord.y - 0),
    Coord(coord.x - 1, coord.y + 1),
    Coord(coord.x - 0, coord.y - 1),
    Coord(coord.x - 0, coord.y + 1),
    Coord(coord.x + 1, coord.y - 1),
    Coord(coord.x + 1, coord.y - 0),
    Coord(coord.x + 1, coord.y + 1),
  ]
  to_get
  |> list.fold([], fn(acc, coord) {
    case dict.get(map, coord) {
      Ok(v) -> [v, ..acc]
      Error(_) -> acc
    }
  })
}

fn is_accessible(map, coord) -> Bool {
  neighbors(map, coord)
  |> list.count(fn(space) { space == Roll })
  < 4
}

fn remove_rolls(map: Dict(Coord, Space)) -> #(Dict(Coord, Space), Int) {
  let accessibles =
    map
    |> dict.filter(fn(coord: Coord, space: Space) {
      case space {
        Roll -> is_accessible(map, coord)
        Empty -> False
      }
    })
  let without_rolls =
    accessibles
    |> dict.fold(map, fn(map, accessible, _) {
      dict.upsert(map, accessible, fn(_) { Empty })
    })
  #(without_rolls, dict.size(accessibles))
}

fn remove_until_done(map: Dict(Coord, Space)) -> Int {
  remove_until_done_acc(map, 0)
}

fn remove_until_done_acc(map: Dict(Coord, Space), n: Int) -> Int {
  let #(without_rolls, removed) = remove_rolls(map)
  case removed {
    0 -> n
    _ -> remove_until_done_acc(without_rolls, removed + n)
  }
}

pub fn part1() {
  let assert Ok(text) = read_text("src/day4.input")
  let map = parse(text)
  map
  |> dict.filter(fn(coord: Coord, space: Space) {
    case space {
      Roll -> is_accessible(map, coord)
      Empty -> False
    }
  })
  |> dict.size
}

pub fn part2() {
  let assert Ok(text) = read_text("src/day4.input")
  let map = parse(text)
  remove_until_done(map)
}
