import "std/list"
import "std/string"
pub import "hml"

pub type QueryOp {
  OpElem(name: string),
  OpProp(name: string),
  OpAttr(name: string)
}

pub fun parse_query(expr: string) : result<list<QueryOp>, string> {
  let steps = split(expr, "|>") |> map(trim)
  parse_steps(steps)
}

pub fun parse_steps(steps: list<string>) : result<list<QueryOp>, string> {
  var err: maybe<string> = None
  var ops: list<QueryOp> = []
  foreach(steps, (step) => {
    match parse_step(step) {
      Ok(op) => { ops = ops + [op] },
      Err(e) => {
        match err {
          None => { err = Some(e) },
          Some(_) => {}
        }
      }
    }
  })
  match err {
    Some(e) => Err(e),
    None => Ok(ops)
  }
}

pub fun parse_step(step: string) : result<QueryOp, string> {
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

pub fun find_attr_val(attrs: list<(string, Hml)>, target: string) : maybe<Hml> {
  var res: maybe<Hml> = None
  foreach(attrs, (attr) => {
    if attr.0 == target && is_none(res) {
      res = Some(attr.1)
    }
  })
  res
}

pub fun eval_apply_op(node: HmlNode, op: QueryOp) : list<HmlNode> =>
  match op {
    OpElem(target) => match node {
      NElem(el) => match el {
        HElement(ename, _, _) => if ename == target { [node] } else { [] },
        _ => []
      },
      _ => []
    },
    OpAttr(target) => match node {
      NElem(el) => match el {
        HElement(_, attrs, _) => match find_attr_val(attrs, target) {
          Some(val) => [NProp(target, val)],
          None => []
        },
        _ => []
      },
      _ => []
    },
    OpProp(target) => match node {
      NElem(el) => match el {
        HElement(_, _, body) => filter(body, (child) => match child {
          NProp(k, _) => k == target,
          _ => false
        }),
        _ => []
      },
      _ => []
    }
  }

pub fun eval_op(nodes: list<HmlNode>, op: QueryOp) : list<HmlNode> =>
  flat_map(nodes, (node) => eval_apply_op(node, op))

pub fun eval_pipeline(doc_nodes: list<HmlNode>, ops: list<QueryOp>) : list<HmlNode> =>
  fold(ops, doc_nodes, (acc, op) => eval_op(acc, op))

pub fun pretty_print_nodes(nodes: list<HmlNode>) : string =>
  hml_pretty(nodes, 0)

pub fun parse_hml_content(content: string, path: string) : result<list<HmlNode>, string> =>
  hml_parse_file_content(content, path)
