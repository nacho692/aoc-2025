import bst
import gleam/int
import gleam/list
import gleam/result

/// A point on the integer tile grid.
pub type Point {
  Point(x: Int, y: Int)
}

/// A closed rectilinear polygon, with its edges indexed for fast queries.
///
/// Containment note: every `contains_*` function asks whether a shape lies
/// *inside or on* the polygon.
pub opaque type Polygon {
  Polygon(
    edges: List(Edge),
    verticals: bst.RangeIndex(Edge),
    // keyed by x
    horizontals: bst.RangeIndex(Edge),
    // keyed by y
  )
}

// Edges are normalized at construction (lo <= hi) so queries never recompute
// int.min / int.max.
type Edge {
  Vertical(x: Int, lo: Int, hi: Int)
  Horizontal(y: Int, lo: Int, hi: Int)
}

/// Build from the ordered vertices of a closed loop (wraps last -> first).
/// Fails if consecutive vertices aren't aligned on a row or column.
pub fn from_points(points: List(Point)) -> Result(Polygon, String) {
  use edges <- result.map(points_to_edges(points))
  // `key` returns x for verticals and y for horizontals, so one comparator
  // orders each index by the field it is keyed on.
  let by_key = fn(e1, e2) { int.compare(key(e1), key(e2)) }
  Polygon(
    edges:,
    verticals: edges |> list.filter(is_vertical) |> bst.from_list(by_key),
    horizontals: edges |> list.filter(is_horizontal) |> bst.from_list(by_key),
  )
}

// Consecutive vertices (wrapping last -> first) become normalized edges.
fn points_to_edges(points: List(Point)) -> Result(List(Edge), String) {
  case points {
    [] | [_] -> Ok([])
    [first, ..] ->
      list.append(points, [first])
      |> list.window_by_2
      |> list.try_map(fn(pair) {
        let #(p1, p2) = pair
        case p1.x == p2.x, p1.y == p2.y {
          True, False ->
            Ok(Vertical(p1.x, int.min(p1.y, p2.y), int.max(p1.y, p2.y)))
          False, True ->
            Ok(Horizontal(p1.y, int.min(p1.x, p2.x), int.max(p1.x, p2.x)))
          _, _ ->
            Error(
              "not axis-aligned: " <> to_string(p1) <> " -> " <> to_string(p2),
            )
        }
      })
  }
}

// The field each index is keyed on: x for verticals, y for horizontals.
fn key(edge: Edge) -> Int {
  case edge {
    Vertical(x, _, _) -> x
    Horizontal(y, _, _) -> y
  }
}

fn is_vertical(edge: Edge) -> Bool {
  case edge {
    Vertical(..) -> True
    Horizontal(..) -> False
  }
}

fn is_horizontal(edge: Edge) -> Bool {
  case edge {
    Horizontal(..) -> True
    Vertical(..) -> False
  }
}

fn to_string(p: Point) -> String {
  int.to_string(p.x) <> "," <> int.to_string(p.y)
}

/// Is `p` inside or on the polygon?
/// Raycast a direction.
/// If either the point is on a polygon boundary or if the ray
/// intersects an odd number of lines in the polygon it means the point is inside.
pub fn contains_point(polygon: Polygon, p: Point) -> Bool {
  use max_x <- unwrap_or(bst.max(polygon.verticals), False)
  let assert Vertical(x, _, _) = max_x
  on_boundary(polygon, p)
  || bst.range(polygon.verticals, Vertical(p.x, 0, 0), Vertical(x, 0, 0))
  |> list.filter(fn(edge) {
    case edge {
      Vertical(_, lo, hi) -> {
        p.y >= lo && p.y < hi
      }
      Horizontal(_, _, _) -> panic as "Vertical expected"
    }
  })
  |> list.length
  |> int.is_odd
}

fn on_boundary(polygon: Polygon, p: Point) -> Bool {
  // p on a vertical edge in its column
  bst.range(polygon.verticals, Vertical(p.x, 0, 0), Vertical(p.x, 0, 0))
  |> list.any(fn(e) {
    case e {
      Vertical(_, lo, hi) -> p.y >= lo && p.y <= hi
      _ -> False
    }
  })
  // or p on a horizontal edge in its row
  || bst.range(
    polygon.horizontals,
    Horizontal(p.y, 0, 0),
    Horizontal(p.y, 0, 0),
  )
  |> list.any(fn(e) {
    case e {
      Horizontal(_, lo, hi) -> p.x >= lo && p.x <= hi
      _ -> False
    }
  })
}

fn unwrap_or(result: Result(a, e), default: b, fun: fn(a) -> b) -> b {
  case result {
    Ok(a) -> fun(a)
    Error(_) -> default
  }
}

/// Is the whole axis-aligned rectangle with opposite corners `a`, `b` inside or
/// on the polygon? No polygon edge may cross the rectangle AND the rectangle must
/// lie on the inside.
pub fn contains_area(polygon: Polygon, a: Point, b: Point) -> Bool {
  let xlo = int.min(a.x, b.x)
  let xhi = int.max(a.x, b.x)
  let ylo = int.min(a.y, b.y)
  let yhi = int.max(a.y, b.y)

  // no vertical edge pokes into the open box (xlo,xhi) x (ylo,yhi)
  bst.range(polygon.verticals, Vertical(xlo + 1, 0, 0), Vertical(xhi - 1, 0, 0))
  |> list.all(fn(e) {
    case e {
      Vertical(_, elo, ehi) -> elo >= yhi || ehi <= ylo
      _ -> True
    }
  })
  // no horizontal edge pokes in
  && bst.range(
    polygon.horizontals,
    Horizontal(ylo + 1, 0, 0),
    Horizontal(yhi - 1, 0, 0),
  )
  |> list.all(fn(e) {
    case e {
      Horizontal(_, elo, ehi) -> elo >= xhi || ehi <= xlo
      _ -> True
    }
  })
  // and the box is on the inside, not outside
  && contains_point(polygon, Point(xlo + 1, ylo + 1))
}
