import gleam/int
import gleam/list
import gleam/result
import gleam/string
import polygon
import utils

type Position {
  Position(x: Int, y: Int)
}

fn area(p1: Position, p2: Position) -> Int {
  { int.absolute_value(p1.x - p2.x) + 1 }
  * { int.absolute_value(p1.y - p2.y) + 1 }
}

fn parse_red_tiles(lines: List(String)) -> Result(List(Position), Nil) {
  lines
  |> list.try_map(fn(line) {
    let assert [x, y] = string.split(line, ",") as { "invalid line " <> line }
    use x <- result.try(int.parse(x))
    use y <- result.try(int.parse(y))
    Ok(Position(x:, y:))
  })
}

fn part1() -> Result(String, String) {
  use text <- result.try(
    utils.read_text("src/day9.input")
    |> result.replace_error("reading day9.input"),
  )
  use tiles <- result.try(
    text
    |> string.trim
    |> string.split("\n")
    |> list.map(string.trim)
    |> parse_red_tiles
    |> result.replace_error("parsing tiles"),
  )
  tiles
  |> list.combination_pairs
  |> list.sort(fn(t1, t2) { int.compare(-area(t1.0, t1.1), -area(t2.0, t2.1)) })
  |> list.first
  |> result.replace_error("not enough pairs")
  |> result.map(fn(t) { int.to_string(area(t.0, t.1)) })
}

fn part2() {
  use text <- result.try(
    utils.read_text("src/day9.input")
    |> result.replace_error("reading day9.input"),
  )
  use tiles <- result.try(
    text
    |> string.trim
    |> string.split("\n")
    |> list.map(string.trim)
    |> parse_red_tiles
    |> result.replace_error("parsing tiles"),
  )
  use poly <- result.try(
    tiles
    |> list.map(fn(t) { polygon.Point(x: t.x, y: t.y) })
    |> polygon.from_points,
  )
  tiles
  |> list.combination_pairs
  |> list.sort(fn(t1, t2) { int.compare(-area(t1.0, t1.1), -area(t2.0, t2.1)) })
  |> list.find(fn(t) {
    polygon.contains_area(
      poly,
      polygon.Point(t.0.x, t.0.y),
      polygon.Point(t.1.x, t.1.y),
    )
  })
  |> result.replace_error("no solution")
  |> result.map(fn(t) { int.to_string(area(t.0, t.1)) })
}

pub fn main() {
  let _ = echo part1()
  let _ = echo part2()
}
