import "std/string"
import "std/list"

pub type QueryOp {
  OpElem(name: string),
  OpProp(name: string),
  OpAttr(name: string)
}

pub fun parse_query(expr: string) : result<list<QueryOp>, string> {
  let steps = split(expr, "|>") |> map(trim)
  parse_steps(steps)
}

fun parse_steps(steps: list<string>) : result<list<QueryOp>, string> {
  match steps {
    [] => Ok([]),
    [step, ..rest] => {
      match parse_step(step) {
        Ok(op) => match parse_steps(rest) {
          Ok(ops) => Ok([op] + ops),
          Err(e) => Err(e)
        },
        Err(e) => Err(e)
      }
    }
  }
}

fun parse_step(step: string) : result<QueryOp, string> {
  if starts_with(step, "@") {
    Ok(OpElem(step[1:]))
  } else if starts_with(step, ".") {
    Ok(OpProp(step[1:]))
  } else if starts_with(step, "attr(\"") && ends_with(step, "\")") {
    let len = str_length(step)
    let name = step[6:len - 2]
    Ok(OpAttr(name))
  } else if starts_with(step, "elem(\"") && ends_with(step, "\")") {
    let len = str_length(step)
    let name = step[6:len - 2]
    Ok(OpElem(name))
  } else if starts_with(step, "prop(\"") && ends_with(step, "\")") {
    let len = str_length(step)
    let name = step[6:len - 2]
    Ok(OpProp(name))
  } else {
    Err("Unknown query step: " + step)
  }
}

test "parse simple elem and attr pipeline" {
  let r = parse_query("@server |> attr(\"port\")")
  let success = match r {
    Ok([OpElem(e), OpAttr(a)]) => e == "server" && a == "port",
    _ => false
  }
  assert(success)
}

test "parse prop short syntax" {
  let r = parse_query(".database")
  let success = match r {
    Ok([OpProp(p)]) => p == "database",
    _ => false
  }
  assert(success)
}
