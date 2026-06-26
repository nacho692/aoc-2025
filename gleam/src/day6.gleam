import gleam/int
import gleam/list
import gleam/result
import gleam/string
import utils

type Operator {
  Addition
  Multiplication
}

type Formula {
  Formula(operands: List(Int), operator: Operator)
}

fn split_first(matrix: List(List(any))) -> #(List(any), List(List(any))) {
  // [[a1,b1],[a2,b2],[*,+]] -> #([a1,a2,*], [[b1],[b2],[+]])
  let first_column =
    list.map(matrix, fn(row) {
      case row {
        [r, ..] -> r
        _ -> panic as { "Row is empty" }
      }
    })
  let rest_columns =
    list.map(matrix, fn(row) {
      case row {
        [_, ..rest] -> rest
        _ -> panic as { "Row is empty" }
      }
    })

  #(first_column, rest_columns)
}

fn pivot(matrix: List(List(any))) -> List(List(any)) {
  pivot_tail(matrix, [])
}

fn pivot_tail(
  matrix: List(List(any)),
  acc: List(List(any)),
) -> List(List(any)) {
  case matrix {
    [] -> acc
    [[], ..] -> acc
    _ -> {
      let #(first_column, rest_column) = split_first(matrix)
      pivot_tail(rest_column, [first_column, ..acc])
    }
  }
}

fn must_ints(input: List(String)) -> List(Int) {
  let assert Ok(output) = list.try_map(input, int.parse)
  output
}

// ["123", "2323", "*"] -> Formula
fn to_formula(formula_text: List(String)) -> Formula {
  let reversed = formula_text |> list.reverse
  case reversed {
    ["*", ..rest] ->
      Formula(operands: must_ints(rest), operator: Multiplication)
    ["+", ..rest] -> Formula(operands: must_ints(rest), operator: Addition)
    _ -> panic as "Operand expected"
  }
}

fn execute_formula(formula: Formula) -> Int {
  case formula.operator {
    Addition -> int.sum(formula.operands)
    Multiplication -> int.product(formula.operands)
  }
}

fn parse_formulas(text: String) -> List(Formula) {
  let lines = text |> string.trim |> string.split("\n")
  lines
  |> list.map(string.trim)
  |> list.map(fn(line) {
    line
    |> string.split(" ")
    // There are more than one space between columns, so we remove extra empty stuff
    // ["123", "", "", "51"] -> ["123", "51"]
    |> list.filter(fn(maybe) { maybe != "" })
  })
  // [[a1,b1],[a2,b2],[*,+]]
  |> pivot
  |> list.map(to_formula)
}

// Instead of grabbing ["123", "32 ", "+"] (in a column) as [123, 32, +], we do [3, 22, 13, +]
// Number of digits is given by spaces between operands
// 123 328  51 64
//  45 64  387 23
//   6 98  215 314
// *   +   *   +
fn parse_formulas_cephalopod(text: String) -> List(Formula) {
  let lines =
    text
    |> string.split("\n")
    |> list.map(string.to_graphemes)
  // ["1", "2", "3", " ", ...]
  // [" ", "4", "5", " ", ...]
  // [" ", " ", "6", " ", ...]
  // ["*", " ", " ", " ", ...]

  let assert Ok(operators) =
    lines
    |> list.last
    |> result.map(list.filter(_, fn(e) { e != " " }))
  let #(number_lines, _) = list.split(lines, list.length(lines) - 1)

  let numbers =
    list.transpose(number_lines)
    // ["1", " ", " "]
    // ["2", "4", " "]
    // ["3", "5", "6"]
    // [" ", " ", " "]
    |> list.map(list.filter(_, fn(e) { e != " " }))
    |> list.map(string.concat)
    |> list.chunk(fn(e) { e != "" })
    // [["1", "24", "356"], [""], ...]
    |> list.filter(fn(e) { e != [""] })
  // [["1", "24", "356"], ...]
  list.zip(numbers, operators)
  |> list.map(fn(t) { list.append(t.0, [t.1]) })
  |> list.map(to_formula)
}

fn part1() {
  let assert Ok(text) = utils.read_text("src/day6.input")
  parse_formulas(text)
  |> list.map(execute_formula)
  |> int.sum
}

fn part2() {
  let assert Ok(text) = utils.read_text("src/day6.input")
  parse_formulas_cephalopod(string.trim(text))
  |> list.map(execute_formula)
  |> int.sum
}

pub fn main() {
  echo part1()
  echo part2()
}
