import "hml"
import "std/string"
import "std/list"

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

pub fun get_elem_attrs(node: HmlNode) : list<(string, Hml)> =>
  match node {
    NElem(HElement(_, attrs, _)) => attrs,
    _ => []
  }

pub fun get_elem_body(node: HmlNode) : list<HmlNode> =>
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
  match find_attr_val(get_elem_attrs(node), target) {
    Some(val) => [NProp(target, val)],
    None => []
  }

pub fun eval_prop(node: HmlNode, target: string) : list<HmlNode> =>
  filter(get_elem_body(node), (child) => match child {
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
// Query Expression Parsing
// -------------------------------------------------------------------

pub fun parse_step(step: string) : result<QueryOp, string> {
  if starts_with(step, "@") {
    Ok(OpElem(step[1:]))
  } else if starts_with(step, ".") {
    Ok(OpProp(step[1:]))
  } else if starts_with(step, "attr(\"") && ends_with(step, "\")") {
    let len = str_length(step)
    Ok(OpAttr(step[6:len - 2]))
  } else if starts_with(step, "elem(\"") && ends_with(step, "\")") {
    let len = str_length(step)
    Ok(OpElem(step[6:len - 2]))
  } else if starts_with(step, "prop(\"") && ends_with(step, "\")") {
    let len = str_length(step)
    Ok(OpProp(step[6:len - 2]))
  } else {
    Err("Unknown query step: " + step)
  }
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

pub fun parse_query(expr: string) : result<list<QueryOp>, string> {
  let steps = split(expr, "|>") |> map(trim)
  parse_steps(steps)
}

// -------------------------------------------------------------------
// Local Formatting Engine (Inlined to avoid cross-module recursive specialization)
// -------------------------------------------------------------------

pub fun hq_hml_show(v: Hml) : string => match v {
  HStr(s) => if contains(s, "\n") { "\"\"\"\n" + s + "\n\"\"\"" } else { "\"" + s + "\"" },
  HInt(n) => show(n),
  HFloat(f) => show(f),
  HBool(b) => if b { "true" } else { "false" },
  HDuration(amount, unit) => show(amount) + unit,
  HDatetime(s) => s,
  HNull => "null",
  HArray(items) => "[" + join(map(items, (i) => hq_hml_show(i)), ", ") + "]",
  HElement(name, attrs, body) => show_element(name, attrs, body)
}

pub fun hq_show_element(name: string, attrs: list<(string, Hml)>, body: list<HmlNode>) : string {
  let attr_str = if length(attrs) == 0 { "" }
                 else { "(" + join(map(attrs, (a) => hq_show_attr(a)), ", ") + ")" }
  let body_str = if length(body) == 0 { "" }
                 else { " \{ ... \}" }
  "@" + name + attr_str + body_str
}

pub fun hq_show_attr(entry: (string, Hml)) : string => match entry {
  (k, HBool(true)) => k,
  (k, v) => k + ": " + hq_hml_show(v)
}

pub fun make_hml_indent(n: int) : string =>
  if n <= 0 { "" } else { "    " + make_hml_indent(n - 1) }

pub fun local_pretty_nodes(nodes: list<HmlNode>, indent: int) : string =>
  join(map(nodes, (node) => hq_pretty_node(node, indent)), "\n")

pub fun hq_pretty_node(node: HmlNode, indent: int) : string {
  let pad = make_hml_indent(indent)
  match node {
    NProp(key, val) => pad + key + ": " + hq_hml_show(val),
    NElem(HElement(name, attrs, body)) => {
      let attr_str = if length(attrs) == 0 { "" }
                     else { "(" + join(map(attrs, (a) => hq_show_attr(a)), ", ") + ")" }
      if length(body) == 0 { pad + "@" + name + attr_str }
      else {
        let header = pad + "@" + name + attr_str + " {"
        let content = local_pretty_nodes(body, indent + 1)
        let footer = pad + "}"
        join([header, content, footer], "\n")
      }
    },
    NElem(_) => pad + "// unknown element",
    NText(content) => pad + content,
    NComment(text) => pad + "// " + text,
    NNamespace(pfx, uri) => pad + "#namespace " + pfx + ": \"" + uri + "\""
  }
}

// Top-level String -> String entrypoint
pub fun run_query(expr: string, hml_content: string) : result<string, string> {
  match parse_query(expr) {
    Ok(ops) => match hml_parse_file_content(hml_content, "input.hml") {
      Ok(nodes) => {
        let filtered = eval_pipeline(nodes, ops)
        Ok(local_pretty_nodes(filtered, 0))
      },
      Err(e) => Err("Parse error: " + e)
    },
    Err(e) => Err("Query error: " + e)
  }
}