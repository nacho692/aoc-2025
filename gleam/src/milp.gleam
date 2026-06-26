import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import gleam/string_tree.{type StringTree}

// MILP is just an interface to create LP files.
// A solver is required on your system for this to work.

// Problem defines a MILP problem
pub opaque type Problem {
  Problem(
    objective: Objective,
    constraints: List(Constraint),
    bounds: List(Bound),
    variables: Dict(Variable, VariableType),
  )
}

pub type Objective {
  Min(sum: List(#(Variable, Constant)))
  Max(sum: List(#(Variable, Constant)))
}

pub type Variable {
  Variable(v: String)
}

pub type VariableType {
  Binary
  Continuous
  Integer
}

pub type Constant {
  CInt(v: Int)
  CFloat(v: Float)
}

pub type Bound {
  Bound(variable: Variable, lo: BoundValue, hi: BoundValue)
}

pub type BoundValue {
  Finite(Constant)
  NegInf
  PosInf
}

pub type Constraint {
  EQ(sum: List(#(Variable, Constant)), constant: Constant)
  GTE(sum: List(#(Variable, Constant)), constant: Constant)
  LTE(sum: List(#(Variable, Constant)), constant: Constant)
}

pub fn new(
  objective objective: Objective,
  constraints constraints: List(Constraint),
  bounds bounds: List(Bound),
  variable_types variable_types: Dict(Variable, VariableType),
) -> Problem {
  Problem(
    objective:,
    constraints:,
    bounds:,
    variables: dict.new()
      |> dict.merge(sum_variables(objective.sum))
      |> dict.merge(
        constraints
        |> list.fold(dict.new(), fn(acc, constraint) {
          dict.merge(acc, sum_variables(constraint.sum))
        }),
      )
      |> dict.merge(variable_types),
  )
}

pub fn to_lp(problem: Problem) -> String {
  string_tree.new()
  |> objective_to_lp(problem.objective)
  |> string_tree.append("\n")
  |> constraints_to_lp(problem.constraints)
  |> string_tree.append("\n")
  |> bounds_to_lp(problem.bounds)
  |> string_tree.append("\n")
  |> variable_types_to_lp(problem.variables)
  |> string_tree.append("\n")
  |> string_tree.append("End")
  |> string_tree.to_string
}

fn objective_to_lp(st: StringTree, objective: Objective) -> StringTree {
  st
  |> string_tree.append(case objective {
    Min(_) -> "Minimize"
    Max(_) -> "Maximize"
  })
  |> string_tree.append("\n")
  |> string_tree.append(" obj: ")
  |> sum_to_lp(objective.sum)
  |> string_tree.append("\n")
}

fn constraints_to_lp(
  st: StringTree,
  constraints: List(Constraint),
) -> StringTree {
  st
  |> string_tree.append("Subject To\n")
  |> string_tree.append_tree(
    constraints
    |> list.index_fold(string_tree.new(), fn(st, constraint, idx) {
      st
      |> string_tree.append(" r" <> int.to_string(idx) <> ": ")
      |> constraint_to_lp(constraint)
      |> string_tree.append("\n")
    }),
  )
}

fn bounds_to_lp(st: StringTree, bounds: List(Bound)) -> StringTree {
  case bounds {
    [] -> st
    bounds ->
      bounds
      |> list.fold(string_tree.append(st, "Bounds\n"), fn(st, bound) {
        st
        |> string_tree.append(" ")
        |> bound_to_lp(bound)
        |> string_tree.append("\n")
      })
  }
}

fn variable_types_to_lp(
  st: StringTree,
  variables: Dict(Variable, VariableType),
) -> StringTree {
  let generals =
    dict.filter(variables, fn(_, t) { t == Integer })
    |> dict.to_list
    |> list.map(fn(t) { t.0 })
  let binaries =
    dict.filter(variables, fn(_, t) { t == Binary })
    |> dict.to_list
    |> list.map(fn(t) { t.0 })
  let st = {
    case generals {
      [] -> st
      variables ->
        st
        |> string_tree.append("Generals\n ")
        |> string_tree.append(string.join(
          list.map(variables, fn(v) { v.v }),
          " ",
        ))
    }
  }
  let st = {
    case binaries {
      [] -> st
      variables ->
        st
        |> string_tree.append("Binaries\n ")
        |> string_tree.append_tree(
          string_tree.from_strings(list.map(variables, fn(v) { v.v })),
        )
    }
  }
  st
}

fn bound_to_lp(st: StringTree, bound: Bound) -> StringTree {
  st
  |> bound_value_to_lp(bound.lo)
  |> string_tree.append(" <= " <> bound.variable.v <> " <= ")
  |> bound_value_to_lp(bound.hi)
}

fn bound_value_to_lp(st: StringTree, bound_value: BoundValue) -> StringTree {
  st
  |> {
    fn(st) {
      case bound_value {
        Finite(n) -> constant_to_lp(st, n)
        NegInf -> string_tree.append(st, "-infinity")
        PosInf -> string_tree.append(st, "+infinity")
      }
    }
  }
}

fn constraint_to_lp(st: StringTree, constraint: Constraint) -> StringTree {
  st
  |> sum_to_lp(constraint.sum)
  |> string_tree.append(case constraint {
    EQ(_, _) -> " = "
    LTE(_, _) -> " <= "
    GTE(_, _) -> " >= "
  })
  |> constant_to_lp(constraint.constant)
}

fn sum_to_lp(st: StringTree, sum: List(#(Variable, Constant))) -> StringTree {
  sum
  |> list.index_fold(st, fn(st, product, i) {
    let #(variable, constant) = product
    let st = case i {
      0 -> st
      _ -> string_tree.append(st, " + ")
    }
    st
    |> constant_to_lp(constant)
    |> string_tree.append(" " <> variable.v)
  })
}

fn constant_to_lp(st: StringTree, c: Constant) -> StringTree {
  st
  |> string_tree.append(case c {
    CInt(n) -> int.to_string(n)
    CFloat(n) -> float.to_string(n)
  })
}

fn sum_variables(
  sum: List(#(Variable, Constant)),
) -> Dict(Variable, VariableType) {
  sum
  |> list.fold(dict.new(), fn(acc, product) {
    let #(variable, _) = product
    acc |> dict.insert(variable, Continuous)
  })
}
