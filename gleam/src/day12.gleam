import gleam/bool
import gleam/dict.{type Dict}
import gleam/function
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/set.{type Set}
import gleam/string
import utils

pub type Position {
  Position(x: Int, y: Int)
}

pub type Grid {
  Grid(occupied: Set(Position), w: Int, h: Int)
}

pub type Problem {
  Problem(
    g: Grid,
    shapes: Dict(String, List(Shape)),
    demands: Dict(String, Int),
  )
}

/// occupy ocuppies position p on grid g.
/// Nothing is done if the position is occupied already or invalid.
pub fn occupy(g: Grid, p: Position) -> Grid {
  case p {
    _ if p.x < g.w && 0 <= p.x && 0 <= p.y && p.y < g.h ->
      Grid(..g, occupied: g.occupied |> set.insert(p))
    _ -> g
  }
}

pub fn occupy_positions(g: Grid, ps: Set(Position)) -> Grid {
  ps
  |> set.fold(g, fn(acc, p) { occupy(acc, p) })
}

pub fn is_occupied(g: Grid, p: Position) -> Bool {
  set.contains(g.occupied, p)
}

// counts free slots from a specific position onwards (including)
pub fn free_slots(g: Grid, from: Position) -> Int {
  let remaining = { g.w - from.x } + { g.w * { g.h - from.y - 1 } }
  remaining
  - set.size(
    g.occupied
    |> set.filter(fn(p) { p.y == from.y && p.x >= from.x || p.y > from.y }),
  )
}

pub fn solve(p: Problem) -> option.Option(Dict(Position, Shape)) {
  solve_acc(p, Position(x: 0, y: 0), dict.new())
}

fn solve_acc(
  p: Problem,
  cp: Position,
  acc: Dict(Position, Shape),
) -> option.Option(Dict(Position, Shape)) {
  use <- bool.guard(cp.x >= p.g.w || cp.y >= p.g.h, option.None)
  let required = shapes_required(acc, p.demands)
  let assert Ok(slots_required) =
    required
    |> dict.to_list
    |> list.try_fold(0, fn(acc, t) {
      let #(key, q) = t
      dict.get(p.shapes, key)
      |> result.try(list.first)
      |> result.map(fn(shape) { acc + set.size(shape.occupied) * q })
    })
  use <- bool.guard(slots_required > free_slots(p.g, cp), option.None)

  case slots_required {
    0 -> option.Some(acc)
    _ -> {
      // We add the possibility to alo insert an empty shape
      let choices =
        required
        |> dict.to_list
        |> list.flat_map(fn(t) {
          let #(key, _) = t
          let assert Ok(shapes) = p.shapes |> dict.get(key)
            as { key <> " not found in shapes" }
          shapes
        })
        // Empty shape is always a possibility
        |> list.append([empty()])

      choices
      |> list.find_map(fn(shape) {
        use <- bool.guard(bool.negate(shape_fits(p.g, cp, shape)), Error(Nil))
        let g =
          occupy_positions(
            p.g,
            shape.occupied
              |> set.map(fn(s) { Position(x: s.x + cp.x, y: s.y + cp.y) }),
          )

        use next_position <- result.try(find_free(g, cp))
        case
          solve_acc(
            Problem(..p, g: g),
            next_position,
            dict.insert(acc, cp, shape),
          )
        {
          option.Some(sol) -> Ok(sol)
          option.None -> Error(Nil)
        }
      })
      |> option.from_result
    }
  }
}

fn find_free(g: Grid, cp: Position) -> Result(Position, Nil) {
  let next = case cp.x + 1 == g.w {
    True -> Position(x: 0, y: cp.y + 1)
    False -> Position(x: cp.x + 1, y: cp.y)
  }
  use <- bool.guard(cp.y == g.h, Error(Nil))
  case is_occupied(g, next) {
    True -> find_free(g, next)
    False -> Ok(next)
  }
}

fn shape_fits(g: Grid, p: Position, shape: Shape) -> Bool {
  let translated_shape =
    shape.occupied
    |> set.map(fn(sp) { Position(x: sp.x + p.x, y: sp.y + p.y) })

  use <- bool.guard(
    translated_shape
      |> set.to_list
      |> list.any(fn(sp) { sp.x >= g.w || sp.y >= g.h }),
    False,
  )

  set.intersection(translated_shape, g.occupied) |> set.size == 0
}

fn shapes_required(
  acc: Dict(Position, Shape),
  demand: Dict(String, Int),
) -> Dict(String, Int) {
  let current =
    acc
    |> dict.values
    |> list.fold(dict.new(), fn(acc, shape) {
      acc
      |> dict.upsert(shape.key, fn(opt) {
        case opt {
          option.None -> 1
          option.Some(n) -> n + 1
        }
      })
    })
  demand
  |> dict.combine(current, fn(d, c) { d - c })
  |> dict.filter(fn(k, v) { v != 0 && k != empty().key })
}

pub type Shape {
  Shape(key: String, occupied: Set(Position), h: Int, w: Int)
}

pub fn empty() -> Shape {
  Shape("x", occupied: set.new(), w: 1, h: 1)
}

pub fn positions(s: Shape) -> Set(Position) {
  s.occupied
}

pub fn rotations(s: Shape) -> List(Shape) {
  rotations_acc(s, [])
}

fn rotations_acc(s: Shape, acc: List(Shape)) {
  // Should only check header but this is a bit more generic in 'loop finding'
  case list.contains(acc, s) {
    True -> acc
    False -> rotations_acc(rotate(s), [s, ..acc])
  }
}

fn rotate(s: Shape) -> Shape {
  let w = s.h
  let h = s.w
  let occupied =
    s.occupied
    |> set.map(fn(p: Position) { Position(x: w - p.y - 1, y: p.x) })
  Shape(key: s.key, occupied:, w:, h:)
}

fn parse_shapes(text: String) -> Result(List(Shape), String) {
  text
  |> string.trim
  |> string.split("\n\n")
  |> list.filter(fn(line) { bool.negate(string.contains(line, "x")) })
  |> list.try_map(parse_shape)
}

fn parse_shape(shape_with_header_raw: String) -> Result(Shape, String) {
  use #(header_raw, shape_raw) <- result.try(
    string.split_once(shape_with_header_raw, ":\n")
    |> result.replace_error("parsing shape " <> shape_with_header_raw),
  )

  let key =
    header_raw
    |> string.trim
    |> string.remove_suffix(":")

  let occupied = {
    shape_raw
    |> string.split("\n")
    |> list.index_map(fn(shape_line, y) {
      shape_line
      |> string.to_graphemes
      |> list.index_map(fn(char, x) { #(x, y, char) })
    })
    |> list.flatten
    |> list.filter(fn(t) { t.2 == "#" })
    |> list.map(fn(t) {
      let #(x, y, _) = t
      Position(x:, y:)
    })
    |> set.from_list
  }

  use #(h, w) <- result.try({
    let split =
      shape_raw
      |> string.split("\n")
    let h = list.length(split)
    use w <- result.try(
      split
      |> list.first
      |> result.map(string.length)
      |> result.replace_error("parsing shape width " <> shape_raw),
    )

    Ok(#(h, w))
  })

  Ok(Shape(key:, occupied:, h:, w:))
}

fn parse_demands(text: String) -> List(#(Grid, Dict(String, Int))) {
  let assert Ok(demands_raw) =
    text
    |> string.trim
    |> string.split("\n\n")
    // 12x5: 1 0 1 0 2 2
    |> list.last

  demands_raw
  |> string.split("\n")
  |> list.map(fn(demand_raw) {
    let assert Ok(#(size_raw, requirements_raw)) =
      demand_raw |> string.trim |> string.split_once(":")
    let assert Ok([w, h]) =
      size_raw
      |> string.split("x")
      |> list.try_map(int.parse)
    let requirements =
      requirements_raw
      |> string.trim
      |> string.split(" ")
      |> list.index_map(fn(d, idx) { #(idx, d) })
      |> list.map(fn(t) {
        let #(idx, d) = t
        let assert Ok(n) = int.parse(d)
        #(int.to_string(idx), n)
      })
    #(Grid(occupied: set.new(), w:, h:), requirements |> dict.from_list)
  })
}

fn part1() -> Result(String, String) {
  use text <- result.try(
    utils.read_text("src/day12.input") |> result.replace_error("reading input"),
  )
  use shapes <- result.try(parse_shapes(text))
  let shapes =
    list.flat_map(shapes, fn(shape) { rotations(shape) })
    |> list.group(fn(shape) { shape.key })
  let grid_demands = parse_demands(text)
  grid_demands
  |> list.map(fn(t) {
    let #(g, demands) = t
    Problem(g:, shapes:, demands:)
  })
  |> list.map(solve)
  |> list.map(option.is_some)
  |> list.filter(function.identity)
  |> list.length
  |> int.to_string
  |> Ok
}

pub fn main() {
  let _ = echo part1()
}
