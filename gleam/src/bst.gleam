import gleam/list
import gleam/order

pub opaque type RangeIndex(a) {
  RangeIndex(root: Tree(a), comparator: fn(a, a) -> order.Order)
}

type Tree(a) {
  Leaf
  Node(left: Tree(a), value: a, right: Tree(a))
}

pub fn from_list(
  list: List(a),
  comparator: fn(a, a) -> order.Order,
) -> RangeIndex(a) {
  let sorted_list = list |> list.sort(comparator)
  let #(tree, leftover) =
    sorted_list |> build_from_sorted_list(list.length(sorted_list))
  let assert [] = leftover as "from_sorted: leftover elements after build"
  RangeIndex(root: tree, comparator:)
}

/// Returns values such that from <= values <= to
pub fn range(range_index: RangeIndex(a), from: a, to: a) -> List(a) {
  range_acc(range_index.root, from, to, range_index.comparator, [])
}

/// Returns the max value in the index
pub fn max(range_index: RangeIndex(a)) -> Result(a, Nil) {
  max_acc(range_index.root)
}

/// Returns the min value in the index
pub fn min(range_index: RangeIndex(a)) -> Result(a, Nil) {
  min_acc(range_index.root)
}

fn min_acc(tree: Tree(a)) -> Result(a, Nil) {
  case tree {
    Leaf -> Error(Nil)
    Node(Leaf, value, _) -> Ok(value)
    Node(left, _, _) -> min_acc(left)
  }
}

fn max_acc(tree: Tree(a)) -> Result(a, Nil) {
  case tree {
    Leaf -> Error(Nil)
    Node(_, value, Leaf) -> Ok(value)
    Node(_, _, right) -> max_acc(right)
  }
}

fn range_acc(
  tree: Tree(a),
  from: a,
  to: a,
  comparator: fn(a, a) -> order.Order,
  acc: List(a),
) -> List(a) {
  case tree {
    Leaf -> acc
    Node(left, value, right) ->
      case comparator(value, from), comparator(value, to) {
        o1, o2
          if { o1 == order.Gt || o1 == order.Eq }
          && { o2 == order.Lt || o2 == order.Eq }
        -> {
          let right_acc = range_acc(right, from, to, comparator, acc)
          range_acc(left, from, to, comparator, [value, ..right_acc])
        }
        o1, o2 if o1 == order.Lt && { o2 == order.Lt || o2 == order.Eq } -> {
          range_acc(right, from, to, comparator, acc)
        }
        o1, o2 if { o1 == order.Gt || o1 == order.Eq } && o2 == order.Gt -> {
          range_acc(left, from, to, comparator, acc)
        }
        _, _ -> acc
      }
  }
}

fn build_from_sorted_list(items: List(a), n: Int) -> #(Tree(a), List(a)) {
  case n {
    0 -> #(Leaf, items)
    _ -> {
      // A
      // items = [1, 2, 3], n = 3
      // left_size = 1
      // root = 2, rest = [3]
      // right_size = n - left_size - 1 (root) = 1

      // B
      // items = [1,2], n = 2
      // left_size = 1
      // root = 2, rest = []
      // right_size = n - 1 - 1 = 0
      //
      // C
      // items = [1], n = 1
      // left_size = 0
      // root = 1, rest = []
      // right_size = n - 0 - 1 = 0
      let left_size = n / 2
      let #(left, left_dropped) = build_from_sorted_list(items, left_size)
      let assert [root, ..rest] = left_dropped as "n exceeds sorted list length"
      let #(right, right_dropped) =
        build_from_sorted_list(rest, n - left_size - 1)

      #(Node(left:, value: root, right:), right_dropped)
    }
  }
}
