import "std/list"
import "std/string"
pub import "hml"

pub type QueryOp {
  OpElem(name: string),
  OpProp(name: string),
  OpAttr(name: string)
}

// -------------------------------------------------------------------
// Direct single-pattern helpers
// -------------------------------------------------------------------

pub fun hq_is_elem_named(node: HmlNode, target: string) : bool =>
  match node {
    NElem(HElement(name, _, _)) => name == target,
    _ => false
  }

pub fun hq_get_elem_attrs(node: HmlNode) : list<(string, Hml)> =>
  match node {
    NElem(HElement(_, attrs, _)) => attrs,
    _ => []
  }

pub fun hq_get_elem_body(node: HmlNode) : list<HmlNode> =>
  match node {
    NElem(HElement(_, _, body)) => body,
    _ => []
  }

pub fun find_attr_val(attrs: list<(string, Hml)>, target: string) : maybe<Hml> {
  match filter(attrs, (attr) => attr.0 == target) {
    [attr, ..] => Some(attr.1),
    [] => None
  }
}

// -------------------------------------------------------------------
// Query Evaluation Engine
// -------------------------------------------------------------------

pub fun eval_elem(node: HmlNode, target: string) : list<HmlNode> =>
  if hq_is_elem_named(node, target) { [node] } else { [] }

pub fun eval_attr(node: HmlNode, target: string) : list<HmlNode> =>
  match find_attr_val(hq_get_elem_attrs(node), target) {
    Some(val) => [NProp(target, val)],
    None => []
  }

pub fun eval_prop(node: HmlNode, target: string) : list<HmlNode> =>
  filter(hq_get_elem_body(node), (child) => match child {
    NProp(k, _) => k == target,
    _ => false
  })

pub fun eval_apply_op(node: HmlNode, op: QueryOp) : list<HmlNode> =>
  match op {
    OpElem(target) => eval_elem(node, target),
    OpAttr(target) => eval_attr(node, target),
    OpProp(target) => eval_prop(node, target)
  }

pub fun eval_op(nodes: list<HmlNode>, op: QueryOp) : list<HmlNode> =>
  flat_map(nodes, (node) => eval_apply_op(node, op))

pub fun eval_pipeline(doc_nodes: list<HmlNode>, ops: list<QueryOp>) : list<HmlNode> =>
  fold(ops, doc_nodes, (acc, op) => eval_op(acc, op))

// -------------------------------------------------------------------
// Expression Parsing
// -------------------------------------------------------------------

pub fun parse_query(expr: string) : result<list<QueryOp>, string> {
  let steps = split(expr, "|>") |> map(trim)
  parse_steps(steps)
}

pub fun parse_steps(steps: list<string>) : result<list<QueryOp>, string> =>
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

pub fun pretty_print_nodes(nodes: list<HmlNode>) : string =>
  hml_pretty(nodes, 0)

pub fun parse_hml_content(content: string, path: string) : result<list<HmlNode>, string> =>
  hml_parse_file_content(content, path)
