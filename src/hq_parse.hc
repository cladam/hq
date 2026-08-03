import "hml"
import "std/string"
import "std/list"
import "hq_qtype"

pub noinline fun parse_step(step: string) : result<QueryOp, string> {
  match parse_step_a(step) {
    Ok(op) => Ok(op),
    Err(e) => if e == "__no_match__" { parse_step_b(step) } else { Err(e) }
  }
}

pub noinline fun parse_steps(steps: list<string>) : result<list<QueryOp>, string> =>
  match steps {
    [] => Ok([]),
    [step, ..rest] => match parse_step(step) {
      Ok(op) => match parse_steps(rest) {
        Ok(ops) => Ok([op] + ops),
        Err(e)  => Err(e)
      },
      Err(e) => Err(e)
    }
  }

pub noinline fun map_trim(steps: list<string>) : list<string> =>
  match steps {
    [] => [],
    [s, ..rest] => [trim(s)] + map_trim(rest)
  }

pub noinline fun parse_query(expr: string) : result<list<QueryOp>, string> {
  let steps = map_trim(split(expr, "|>"))
  parse_steps(steps)
}
