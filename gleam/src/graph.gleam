import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option
import gleam/result

pub opaque type Graph(a) {
  Graph(values: Dict(String, a), edges: Dict(String, List(String)))
}

pub fn new() -> Graph(a) {
  Graph(values: dict.new(), edges: dict.new())
}

/// add_node adds a node to the graph
pub fn add_node(g: Graph(a), name: String, value: a) -> Graph(a) {
  Graph(
    values: g.values |> dict.insert(name, value),
    edges: g.edges |> dict.insert(name, []),
  )
}

/// add_edge adds a directed edge, from and to must be pre existing nodes
pub fn add_edge(
  g: Graph(a),
  from: String,
  to: String,
) -> Result(Graph(a), String) {
  use _ <- result.try(
    g.values
    |> dict.get(from)
    |> result.replace_error("node: " <> from <> " not found"),
  )
  use _ <- result.try(
    g.values
    |> dict.get(to)
    |> result.replace_error("node: " <> to <> " not found"),
  )

  Ok(Graph(
    values: g.values,
    edges: g.edges
      |> dict.upsert(from, fn(opt) {
        case opt {
          option.Some(edges) -> [to, ..edges]
          option.None -> [to]
        }
      }),
  ))
}

/// add_edges adds multiple edges to the graph, see add_edge for constraints
pub fn add_nodes(g: Graph(a), nodes: List(#(String, a))) -> Graph(a) {
  nodes
  |> list.fold(g, fn(g, n) { add_node(g, n.0, n.1) })
}

/// add_edges adds multiple edges to the graph, see add_edge for constraints
pub fn add_edges(
  g: Graph(a),
  edges: List(#(String, String)),
) -> Result(Graph(a), String) {
  edges
  |> list.try_fold(g, fn(g, e) { add_edge(g, e.0, e.1) })
}

/// count_paths assumes g is a DAG, if either from or to are not in the graph
/// the result is undefined
pub fn count_paths(g: Graph(a), from: String, to: String) -> Int {
  count_paths_acc(g, from, to, dict.new())
  |> dict.get(from)
  |> result.unwrap(0)
}

fn count_paths_acc(
  g: Graph(a),
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
            g.edges
            |> dict.get(from)
            |> result.unwrap([])
            |> list.fold(acc, fn(acc, child) {
              count_paths_acc(g, child, to, acc)
            })
          children_map
          |> dict.insert(
            from,
            g.edges
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
