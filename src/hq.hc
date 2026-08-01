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

pub fun find_attr_val(attrs: list<(string, Hml)>, target: string) : maybe<Hml> =>
  match attrs {
    [] => None,
    [attr, ..rest] => if attr.0 == target { Some(attr.1) } else { find_attr_val(rest, target) }
  }

// -------------------------------------------------------------------
// Query Evaluation Engine (Direct Recursion - Zero Closures)
// -------------------------------------------------------------------

pub fun filter_elems_by_name(nodes: list<HmlNode>, target: string) : list<HmlNode> =>
  match nodes {
    [] => [],
    [node, ..rest] => if hq_is_elem_named(node, target) { [node] + filter_elems_by_name(rest, target) } else { filter_elems_by_name(rest, target) }
  }

pub fun eval_elem(node: HmlNode, target: string) : list<HmlNode> =>
  filter_elems_by_name(get_elem_body(node), target)

pub fun eval_attr(node: HmlNode, target: string) : list<HmlNode> =>
  match find_attr_val(get_elem_attrs(node), target) {
    Some(val) => [NProp(target, val)],
    None => []
  }

pub fun filter_props_by_key(nodes: list<HmlNode>, target: string) : list<HmlNode> =>
  match nodes {
    [] => [],
    [node, ..rest] => match node {
      NProp(k, _) => if k == target { [node] + filter_props_by_key(rest, target) } else { filter_props_by_key(rest, target) },
      _ => filter_props_by_key(rest, target)
    }
  }

pub fun eval_prop(node: HmlNode, target: string) : list<HmlNode> =>
  filter_props_by_key(get_elem_body(node), target)

pub fun eval_apply_op(node: HmlNode, op: QueryOp) : list<HmlNode> =>
  match op {
    OpElem(target) => eval_elem(node, target),
    OpAttr(target) => eval_attr(node, target),
    OpProp(target) => eval_prop(node, target)
  }

pub fun eval_op(nodes: list<HmlNode>, op: QueryOp) : list<HmlNode> =>
  match nodes {
    [] => [],
    [node, ..rest] => eval_apply_op(node, op) + eval_op(rest, op)
  }

pub fun eval_pipeline(doc_nodes: list<HmlNode>, ops: list<QueryOp>) : list<HmlNode> {
  let root = NElem(HElement("", [], doc_nodes))
  eval_pipeline_rec([root], ops, doc_nodes)
}

pub fun eval_pipeline_rec(current_nodes: list<HmlNode>, ops: list<QueryOp>, original: list<HmlNode>) : list<HmlNode> =>
  match ops {
    [] => current_nodes,
    [op, ..rest] => eval_pipeline_rec(eval_op(current_nodes, op), rest, original)
  }

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

pub fun map_trim(steps: list<string>) : list<string> =>
  match steps {
    [] => [],
    [s, ..rest] => [trim(s)] + map_trim(rest)
  }

pub fun parse_query(expr: string) : result<list<QueryOp>, string> {
  let steps = map_trim(split(expr, "|>"))
  parse_steps(steps)
}

// -------------------------------------------------------------------
// Formatting Engine (Direct Recursion - Zero Closures)
// -------------------------------------------------------------------

pub fun show_hml_array(items: list<Hml>) : string =>
  match items {
    [] => "",
    [x] => hq_hml_show(x),
    [x, ..rest] => hq_hml_show(x) + ", " + show_hml_array(rest)
  }

pub fun hq_hml_show(v: Hml) : string => match v {
  HStr(s) => if contains(s, "\n") { "\"\"\"\n" + s + "\n\"\"\"" } else { "\"" + s + "\"" },
  HInt(n) => show(n),
  HFloat(f) => show(f),
  HBool(b) => if b { "true" } else { "false" },
  HDuration(amount, unit) => show(amount) + unit,
  HDatetime(s) => s,
  HNull => "null",
  HArray(items) => "[" + show_hml_array(items) + "]",
  HElement(name, attrs, body) => hq_show_element(name, attrs, body)
}

pub fun show_attrs_list(attrs: list<(string, Hml)>) : string =>
  match attrs {
    [] => "",
    [a] => hq_show_attr(a),
    [a, ..rest] => hq_show_attr(a) + ", " + show_attrs_list(rest)
  }

pub fun hq_show_element(name: string, attrs: list<(string, Hml)>, body: list<HmlNode>) : string {
  let attr_str = if length(attrs) == 0 { "" }
                 else { "(" + show_attrs_list(attrs) + ")" }
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
  match nodes {
    [] => "",
    [node] => hq_pretty_node(node, indent),
    [node, ..rest] => hq_pretty_node(node, indent) + "\n" + local_pretty_nodes(rest, indent)
  }

pub fun hq_pretty_node(node: HmlNode, indent: int) : string {
  let pad = make_hml_indent(indent)
  match node {
    NProp(key, val) => pad + key + ": " + hq_hml_show(val),
    NElem(HElement(name, attrs, body)) => {
      let attr_str = if length(attrs) == 0 { "" }
                     else { "(" + show_attrs_list(attrs) + ")" }
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

pub fun hq_hml_show_raw(v: Hml) : string => match v {
  HStr(s) => s,
  _ => hq_hml_show(v)
}

pub fun raw_pretty_node(node: HmlNode) : string => match node {
  NProp(_, val) => hq_hml_show_raw(val),
  NText(content) => content,
  _ => hq_pretty_node(node, 0)
}

pub fun raw_pretty_nodes(nodes: list<HmlNode>) : string =>
  match nodes {
    [] => "",
    [node] => raw_pretty_node(node),
    [node, ..rest] => raw_pretty_node(node) + "\n" + raw_pretty_nodes(rest)
  }

// Top-level String -> String entrypoint
pub fun run_query(expr: string, hml_content: string) : result<string, string> =>
  run_query_ext(expr, hml_content, false)

pub fun run_query_ext(expr: string, hml_content: string, raw: bool) : result<string, string> {
  match parse_query(expr) {
    Ok(ops) => match hml_parse_file_content(hml_content, "input.hml") {
      Ok(nodes) => {
        let filtered = eval_pipeline(nodes, ops)
        let output = if raw { raw_pretty_nodes(filtered) } else { local_pretty_nodes(filtered, 0) }
        Ok(output)
      },
      Err(e) => Err("Parse error: " + e)
    },
    Err(e) => Err("Query error: " + e)
  }
}
