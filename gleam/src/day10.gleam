import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/set.{type Set}
import gleam/string
import utils

type Lights {
  Lights(lights: Set(Int), capacity: Int)
}

fn new_lights(on: Set(Int), capacity: Int) -> Result(Lights, Nil) {
  click(Lights(lights: set.new(), capacity:), set.to_list(on))
}

fn new_empty_lights(capacity: Int) -> Lights {
  Lights(lights: set.new(), capacity:)
}

fn click(lights: Lights, buttons: List(Int)) -> Result(Lights, Nil) {
  let new_lights =
    list.fold(buttons, lights.lights, fn(acc, button) {
      case set.contains(acc, button) {
        True -> set.delete(acc, button)
        False -> set.insert(acc, button)
      }
    })
  Ok(Lights(lights: new_lights, capacity: lights.capacity))
}

type Machine {
  Machine(target: Lights, lights: Lights, buttons: Dict(Int, List(Int)))
}

fn new_machine(target: Lights, buttons: List(List(Int))) -> Machine {
  let lights = new_empty_lights(target.capacity)

  Machine(
    target:,
    lights:,
    buttons: list.index_map(buttons, fn(e, idx) { #(idx, e) }) |> dict.from_list,
  )
}

fn solved(machine: Machine) -> Bool {
  machine.target == machine.lights
}

fn press_button(machine: Machine, button: Int) -> Result(Machine, Nil) {
  machine.buttons
  |> dict.get(button)
  |> result.map(fn(buttonset) {
    let assert Ok(lights) = click(machine.lights, buttonset)
    Machine(target: machine.target, lights: lights, buttons: machine.buttons)
  })
}

// Returns min buttons to press to get the machine from the current state to the target
fn solve(machine: Machine) -> Result(List(Int), Nil) {
  case
    min_buttons_acc(
      machine,
      machine.buttons |> dict.keys,
      [],
      machine.buttons |> dict.size,
    )
  {
    #(res, option.Some(_)) -> Ok(res)
    _ -> Error(Nil)
  }
}

fn min_buttons_acc(
  machine: Machine,
  rest: List(Int),
  acc: List(Int),
  acc_n: Int,
) -> #(List(Int), option.Option(Int)) {
  case solved(machine) {
    True -> #(acc, option.Some(acc_n))
    False ->
      case rest {
        [] -> #(acc, option.None)
        [h, ..rest] -> {
          let assert Ok(new_machine) = press_button(machine, h)
          let new_acc = [h, ..acc]
          let solve_press =
            min_buttons_acc(new_machine, rest, new_acc, acc_n + 1)
          let solve_no_press = min_buttons_acc(machine, rest, acc, acc_n)
          case solve_press, solve_no_press {
            #(_, _), #(_, option.None) -> solve_press
            #(_, option.None), #(_, _) -> solve_no_press
            #(_, option.Some(n1)), #(_, option.Some(n2)) ->
              case n1 <= n2 {
                True -> solve_press
                False -> solve_no_press
              }
          }
        }
      }
  }
}

fn parse_machine(line: String) -> Result(Machine, Nil) {
  use #(lights_raw, rest_raw) <- result.try(string.split_once(line, " "))
  let lights =
    lights_raw
    |> string.remove_prefix("[")
    |> string.remove_suffix("]")
    |> string.to_graphemes
  let capacity = lights |> list.length
  let on =
    lights
    |> list.index_map(fn(e, idx) { #(e, idx) })
    |> list.fold(set.new(), fn(acc, t) {
      case t {
        #("#", idx) -> acc |> set.insert(idx)
        _ -> acc
      }
    })
  use lights <- result.try(new_lights(on, capacity))
  use #(buttons_raw, _) <- result.try(rest_raw |> string.split_once("{"))
  use buttons <- result.try(
    buttons_raw
    |> string.trim
    |> string.split(" ")
    |> list.try_map(fn(buttonset_raw) {
      buttonset_raw
      |> string.remove_prefix("(")
      |> string.remove_suffix(")")
      |> string.split(",")
      |> list.try_fold([], fn(acc, button_raw) {
        case int.parse(button_raw) {
          Ok(n) -> Ok([n, ..acc])
          Error(e) -> Error(e)
        }
      })
    }),
  )
  Ok(new_machine(lights, buttons))
}

fn part1() {
  use text <- result.try(utils.read_text("src/day10.input"))
  use machines <- result.try(
    text
    |> string.trim
    |> string.split("\n")
    |> list.map(string.trim)
    |> list.try_map(parse_machine),
  )
  machines
  |> list.try_map(solve)
  |> result.map(fn(r) { r |> list.flatten |> list.length })
}

pub fn main() {
  let _ = echo part1()
}
