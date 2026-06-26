import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/set.{type Set}
import gleam/string
import utils

type DisjointSets {
  DisjointSets(elements: Dict(String, String))
}

fn new_disjointsets_from_list(elements: List(String)) -> DisjointSets {
  DisjointSets(
    elements: elements |> list.map(fn(n) { #(n, n) }) |> dict.from_list,
  )
}

fn sets(dsets: DisjointSets) -> List(Set(String)) {
  let parents =
    dsets.elements
    |> dict.fold(dict.new(), fn(acc: Dict(String, Set(String)), e, _) {
      let assert Ok(r) = find_representative(dsets, e)
        as "iterating dsets, representatives should exist"
      acc
      |> dict.upsert(r, fn(existing) {
        existing
        |> option.unwrap(set.new())
        |> set.insert(e)
      })
    })
  parents |> dict.to_list |> list.map(fn(e) { e.1 })
}

// returns a list of the path to the 'parent' representative of the set
fn find_parents(sets: DisjointSets, e: String) -> Result(List(String), String) {
  find_parents_acc(sets, e, [])
}

fn find_parents_acc(
  sets: DisjointSets,
  e: String,
  acc: List(String),
) -> Result(List(String), String) {
  case dict.get(sets.elements, e) {
    Error(_) -> Error("key " <> e <> " not found in disjoint sets")
    Ok(parent) if parent == e -> Ok(list.reverse([e, ..acc]))
    Ok(parent) -> find_parents_acc(sets, parent, [e, ..acc])
  }
}

// Updates all the parents along the received path
fn update_parents(sets: DisjointSets, path: List(String)) -> DisjointSets {
  case list.reverse(path) {
    [] -> sets
    [r, ..rest] ->
      DisjointSets(
        elements: dict.merge(sets.elements, {
          rest
          |> list.map(fn(e) { #(e, r) })
          |> dict.from_list
        }),
      )
  }
}

fn find_representative(
  sets: DisjointSets,
  e: String,
) -> Result(String, String) {
  case find_parents(sets, e) {
    Ok(path) ->
      list.reverse(path)
      |> list.first
      |> result.replace_error("representative not found")
    Error(e) -> Error(e)
  }
}

fn union(
  sets: DisjointSets,
  e1: String,
  e2: String,
) -> Result(#(DisjointSets, Bool), String) {
  use parents_e1 <- result.try(find_parents(sets, e1))
  use parents_e2 <- result.try(find_parents(sets, e2))

  let sets = sets |> update_parents(parents_e1) |> update_parents(parents_e2)

  use r1 <- result.try(find_representative(sets, e1))
  use r2 <- result.try(find_representative(sets, e2))
  case r1 == r2 {
    True -> Ok(#(sets, False))
    False ->
      Ok(#(
        { DisjointSets(elements: sets.elements |> dict.insert(r1, r2)) },
        True,
      ))
  }
}

type Position {
  Position(x: Int, y: Int, z: Int)
}

fn squared_distance(p1: Position, p2: Position) -> Int {
  square(p1.x - p2.x) + square(p1.y - p2.y) + square(p1.z - p2.z)
}

fn square(x: Int) -> Int {
  x * x
}

// This is a complete graph
type Graph(any) {
  Graph(nodes: Dict(String, any))
}

fn graph_edges(g: Graph(any)) -> List(#(String, String)) {
  graph_nodes(g) |> list.combination_pairs
}

fn graph_nodes(g: Graph(any)) -> List(String) {
  g.nodes |> dict.keys
}

fn graph_node(g: Graph(any), n: String) -> Result(any, String) {
  g.nodes |> dict.get(n) |> result.replace_error("node " <> n <> " not found")
}

fn kruskal(
  g: Graph(Position),
  steps: Int,
) -> #(DisjointSets, List(#(String, String))) {
  let assert Ok(edges_with_position) =
    graph_edges(g)
    |> list.try_map(fn(e) {
      use p1 <- result.try(graph_node(g, e.0))
      use p2 <- result.try(graph_node(g, e.1))
      Ok(#(#(e.0, p1), #(e.1, p2)))
    })
    as "graph edges should be defined as nodes"

  let edges =
    list.sort(edges_with_position, fn(e1, e2) {
      int.compare(
        squared_distance(e1.0.1, e1.1.1),
        squared_distance(e2.0.1, e2.1.1),
      )
    })

  let sets = new_disjointsets_from_list(graph_nodes(g))

  let res = kruskal_acc(edges, steps, sets, [])
  #(res.0, res.1 |> list.reverse |> list.map(fn(e) { #(e.0.0, e.1.0) }))
}

fn kruskal_acc(
  edges: List(#(#(String, Position), #(String, Position))),
  steps: Int,
  sets: DisjointSets,
  mst: List(#(#(String, Position), #(String, Position))),
) -> #(DisjointSets, List(#(#(String, Position), #(String, Position)))) {
  case edges, steps {
    [], _ | _, 0 -> #(sets, mst)
    [edge, ..rest], _ -> {
      let #(#(id1, _), #(id2, _)) = edge
      let assert Ok(#(union, merged)) = union(sets, id1, id2)
        as "edges should be defined in graph"
      kruskal_acc(rest, steps - 1, union, case merged {
        True -> [edge, ..mst]
        False -> mst
      })
    }
  }
}

fn parse_graph(lines: List(String)) -> Result(Graph(Position), String) {
  lines
  |> list.index_map(fn(e, idx) { #(idx, e) })
  |> list.try_fold(Graph(nodes: dict.new()), fn(acc, e) {
    let #(idx, line) = e
    use positions <- result.try(
      line
      |> string.split(",")
      |> list.try_map(int.parse)
      |> result.replace_error("invalid line " <> line),
    )
    case positions {
      [x, y, z] ->
        Ok(
          Graph(nodes: {
            acc.nodes |> dict.insert(int.to_string(idx), Position(x:, y:, z:))
          }),
        )
      _ -> Error("invalid line " <> line)
    }
  })
}

fn part1() -> Result(String, String) {
  use text <- result.try(
    utils.read_text("src/day8.input") |> result.replace_error("parsing input"),
  )
  use graph <- result.try(
    text
    |> string.trim
    |> string.split("\n")
    |> list.map(fn(line) { string.trim(line) })
    |> parse_graph,
  )

  let #(disjoint_sets, _) = kruskal(graph, 1000)
  sets(disjoint_sets)
  |> list.map(set.size)
  |> list.sort(fn(s1, s2) { int.compare(s1, s2) })
  |> list.reverse
  |> list.take(3)
  |> int.product
  |> int.to_string
  |> Ok
}

fn part2() -> Result(String, String) {
  use text <- result.try(
    utils.read_text("src/day8.input") |> result.replace_error("parsing input"),
  )
  use graph <- result.try(
    text
    |> string.trim
    |> string.split("\n")
    |> list.map(fn(line) { string.trim(line) })
    |> parse_graph,
  )

  let #(_, mst) = kruskal(graph, graph_edges(graph) |> list.length)
  mst
  |> list.last
  |> result.replace_error("msg should have at least one edge")
  |> result.map(fn(edge) {
    let assert Ok(p1) = graph_node(graph, edge.0)
    let assert Ok(p2) = graph_node(graph, edge.1)
    [p1.x, p2.x]
    |> int.product
    |> int.to_string
  })
}

pub fn main() {
  let _ = echo part1()
  let _ = echo part2()
}
