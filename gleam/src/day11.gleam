import gleam/int
import gleam/list
import gleam/result
import gleam/string
import graph.{type Graph}
import utils

fn parse_dag(lines: List(String)) -> Result(Graph(Nil), String) {
  let edges =
    lines
    |> list.map(string.trim)
    |> list.try_fold([], fn(edges, line) {
      use #(from, tos) <- result.try(
        string.split_once(line, ":")
        |> result.replace_error("splitting line " <> line),
      )
      Ok(
        tos
        |> string.trim
        |> string.split(" ")
        |> list.map(fn(to) { #(from, to) })
        |> list.append(edges),
      )
    })
  use edges <- result.try(edges)
  let nodes = edges |> list.map(fn(t) { t.0 }) |> list.unique

  use g <- result.try(
    graph.new()
    |> graph.add_nodes(nodes |> list.map(fn(n) { #(n, Nil) }))
    |> graph.add_node("out", Nil)
    |> graph.add_edges(edges),
  )
  Ok(g)
}

fn part1() -> Result(String, String) {
  use text <- result.try(
    utils.read_text("src/day11.input")
    |> result.replace_error("reading day11.input"),
  )
  use dag <- result.try(text |> string.trim |> string.split("\n") |> parse_dag)
  Ok(int.to_string(graph.count_paths(dag, "you", "out")))
}

fn part2() -> Result(String, String) {
  use text <- result.try(
    utils.read_text("src/day11.input")
    |> result.replace_error("reading day11.input"),
  )
  use dag <- result.try(text |> string.trim |> string.split("\n") |> parse_dag)
  Ok(int.to_string(
    graph.count_paths(dag, "svr", "fft")
    * graph.count_paths(dag, "fft", "dac")
    * graph.count_paths(dag, "dac", "out")
    + graph.count_paths(dag, "svr", "dac")
    * graph.count_paths(dag, "dac", "fft")
    * graph.count_paths(dag, "fft", "out"),
  ))
}

pub fn main() {
  let _ = echo part1()
  let _ = echo part2()
}
