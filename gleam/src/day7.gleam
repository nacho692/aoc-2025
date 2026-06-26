import gleam/dict.{type Dict}
import gleam/function
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/set.{type Set}
import gleam/string

import utils

type TachyonsAcc {
  TachyonsAcc(collisions: Int, tachyons: Set(Int))
}

fn cascade_tachyons_acc(
  splitters: List(Set(Int)),
  acc: TachyonsAcc,
  max: Int,
) -> TachyonsAcc {
  case splitters {
    [] -> acc
    [h, ..rest] -> {
      let #(collisions, tachyons) = splits(h, acc.tachyons, max)
      cascade_tachyons_acc(
        rest,
        TachyonsAcc(collisions: acc.collisions + collisions, tachyons:),
        max,
      )
    }
  }
}

fn splits(
  splitters: Set(Int),
  tachyons: Set(Int),
  max: Int,
) -> #(Int, Set(Int)) {
  let collisions = set.intersection(tachyons, splitters)
  let split_tachyons =
    collisions
    |> set.fold(set.new(), fn(acc, collision) {
      case collision {
        n if n >= max - 1 -> set.insert(acc, max - 1)
        0 -> set.insert(acc, 1)
        e -> acc |> set.insert(e - 1) |> set.insert(e + 1)
      }
    })
  #(
    set.size(collisions),
    tachyons |> set.union(split_tachyons) |> set.difference(collisions),
  )
}

fn parse_splitters_tachyons(line: String) -> #(Set(Int), Set(Int)) {
  line
  |> string.to_graphemes
  |> list.index_fold(#(set.new(), set.new()), fn(acc, char, idx) {
    case char {
      "S" -> #(acc.0, set.insert(acc.1, idx))
      "^" -> #(set.insert(acc.0, idx), acc.1)
      _ -> acc
    }
  })
}

fn part1() {
  let assert Ok(text) =
    utils.read_text("src/day7.input")
    |> result.map(string.trim)

  // Width of parsed data
  let assert Ok(width) =
    text
    |> string.split_once("\n")
    |> result.map(fn(split) { string.length(split.0) })

  // Tachyons + Splitters
  let map =
    text
    |> string.split("\n")
    |> list.map(parse_splitters_tachyons)
  let splitters =
    map
    |> list.map(fn(t) { t.0 })
  // Set of tachyons, should be first line only
  let assert Ok(tachyons) = map |> list.first |> result.map(fn(t) { t.1 })

  cascade_tachyons_acc(
    splitters,
    TachyonsAcc(collisions: 0, tachyons: tachyons),
    width,
  ).collisions
}

pub type DAG(a) {
  DAG(values: Dict(String, a), edges: Dict(String, List(String)))
}

// Every splitter will be connected to one below that can cascade a tachyon.
// Basically if there is an existing one above on a column +-1 and there
// is no existing one on the same column in between.
//
// .......S.......
// ...............
// .......^.......
// ...............
// ......^.^......
// ...............
// .....^.^.^.....
//
// A source and a sink will be added at the beginning and end of the DAG.
// I am going bottom up while keeping a set of nodes that need a parent.
// If a parent is found, I am removing the node from the set.
fn splitters_to_dag(root: Coord, splitters: List(Set(Coord))) -> DAG(Coord) {
  let dag =
    splitters_to_dag_acc(
      list.reverse(splitters),
      dict.new(),
      DAG(values: dict.new(), edges: dict.new()),
    )
  // Adding root manually
  let root_node = #("root", root)

  let root_edges =
    {
      dag.values
      |> dict.filter(fn(_, v) { v.x == root.x })
      |> dict.to_list
      |> list.max(fn(n1, n2) { int.compare(-n1.1.y, -n2.1.y) })
      |> result.map(fn(c) { [c.0] })
      |> result.unwrap(["sink"])
    }
    |> list.fold(dict.new(), fn(acc, edge) {
      dict.upsert(acc, "root", fn(opt_existing) {
        case opt_existing {
          option.Some(existing) -> [edge, ..existing]
          option.None -> [edge]
        }
      })
    })

  // Adding sink manually
  DAG(
    values: dag.values
      |> dict.insert("sink", Coord(list.length(splitters), 0))
      |> dict.insert(root_node.0, root_node.1),
    edges: dag.edges
      |> dict.merge(
        dag.edges
        |> dict.map_values(fn(_, edges) {
          edges |> list.append(list.repeat("sink", 2 - list.length(edges)))
        }),
      )
      |> dict.merge(root_edges),
  )
}

pub type Coord {
  Coord(x: Int, y: Int)
}

fn coord_to_key(c: Coord) -> String {
  int.to_string(c.x) <> " " <> int.to_string(c.y)
}

fn splitters_to_dag_acc(
  splitters: List(Set(Coord)),
  // Int is X coord, Coord is the full Coord
  unblocked: Dict(Int, Coord),
  acc: DAG(Coord),
) -> DAG(Coord) {
  case splitters {
    [] -> acc
    [lvl, ..rest] -> {
      // This is bottom up, we add to the DAG all splitters in this lvl
      // The children are defined by the parentless that match
      //
      // new_nodes are the new nodes to insert in the edges map
      let new_node_edges =
        lvl
        |> set.to_list
        |> list.map(fn(c: Coord) {
          #(
            coord_to_key(c),
            [c.x - 1, c.x + 1]
              |> list.filter_map(fn(idx) {
                dict.get(unblocked, idx) |> result.map(coord_to_key)
              }),
          )
        })
        |> dict.from_list

      let new_node_values =
        lvl
        |> set.to_list
        |> list.map(fn(c: Coord) { #(coord_to_key(c), c) })
        |> dict.from_list

      // blocked is the set of nodes that are now blocked by another one
      let blocked =
        unblocked
        |> dict.take(set.fold(lvl, [], fn(acc, c: Coord) { [c.x, ..acc] }))

      // unblocked that keep on being unblocked
      // ..^..
      // ..^.. <- removed since there is no way to get to it
      let new_unblocked =
        unblocked
        |> dict.drop(blocked |> dict.keys)
        |> dict.merge(
          lvl
          |> set.to_list
          |> list.map(fn(c: Coord) { #(c.x, c) })
          |> dict.from_list,
        )
      splitters_to_dag_acc(
        rest,
        new_unblocked,
        DAG(
          values: acc.values
            |> dict.merge(new_node_values),
          edges: acc.edges
            |> dict.merge(new_node_edges),
        ),
      )
    }
  }
}

fn count_paths(from: String, to: String, dag: DAG(Coord)) -> Int {
  count_paths_acc(dag, from, to, dict.new())
  |> dict.get(from)
  |> result.unwrap(0)
}

fn count_paths_acc(
  dag: DAG(Coord),
  from: String,
  to: String,
  acc: Dict(String, Int),
) -> Dict(String, Int) {
  case dict.get(acc, from) {
    Ok(_) -> acc
    _ -> {
      case from == to {
        True -> dict.insert(acc, from, 1)
        False -> {
          let children_map =
            dag.edges
            |> dict.get(from)
            |> result.unwrap([])
            |> list.fold(acc, fn(acc, child) {
              count_paths_acc(dag, child, to, acc)
            })
          children_map
          |> dict.insert(
            from,
            dag.edges
              |> dict.get(from)
              |> result.unwrap([])
              |> list.map(fn(edge) {
                case dict.get(children_map, edge) {
                  Ok(n) -> n
                  _ -> panic as "Edge not found in map"
                }
              })
              |> int.sum,
          )
        }
      }
    }
  }
}

fn part2() {
  let assert Ok(text) =
    utils.read_text("src/day7.input")
    |> result.map(string.trim)

  let splitters =
    text
    |> string.split("\n")
    |> list.index_map(fn(line, y) {
      line
      |> string.to_graphemes
      |> list.index_map(fn(char, x) {
        case char {
          "^" -> Ok(Coord(x:, y:))
          _ -> Error(Nil)
        }
      })
      |> list.filter_map(function.identity)
      |> set.from_list
    })
  let assert Ok(root) =
    text
    |> string.split("\n")
    |> list.index_map(fn(line, y) {
      line
      |> string.to_graphemes
      |> list.index_map(fn(char, x) {
        case char {
          "S" -> Ok(Coord(x:, y:))
          _ -> Error(Nil)
        }
      })
      |> list.filter_map(function.identity)
    })
    |> list.first
    |> result.try(list.first)
  let dag = splitters_to_dag(root, splitters)
  count_paths("root", "sink", dag)
}

pub fn main() {
  echo part1()
  echo part2()
}
