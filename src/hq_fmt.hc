import "hml"
import "std/string"
import "std/list"

pub fun show_hml_array(items: list<Hml>) : string =>
  match items {
    [] => "",
    [x] => hq_hml_show(x),
    [x, ..rest] => hq_hml_show(x) + ", " + show_hml_array(rest)
  }

pub noinline fun hq_hml_show(v: Hml) : string => match v {
  HStr(s)  => if contains(s, "\n") { "\"\"\"\n" + s + "\n\"\"\"" } else { "\"" + s + "\"" },
  HInt(n)  => show(n),
  HFloat(f) => show(f),
  HBool(b) => if b { "true" } else { "false" },
  HDuration(amount, unit) => show(amount) + unit,
  HDatetime(s) => s,
  HNull    => "null",
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
  let attr_str = if length(attrs) == 0 { "" } else { "(" + show_attrs_list(attrs) + ")" }
  let body_str = if length(body) == 0 { "" } else { " \{ ... \}" }
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

pub noinline fun hq_pretty_node(node: HmlNode, indent: int) : string {
  let pad = make_hml_indent(indent)
  match node {
    NProp(key, hval) => pad + key + ": " + hq_hml_show(hval),
    NElem(HElement(name, attrs, body)) => {
      let attr_str = if length(attrs) == 0 { "" } else { "(" + show_attrs_list(attrs) + ")" }
      if length(body) == 0 { pad + "@" + name + attr_str }
      else {
        let header = pad + "@" + name + attr_str + " \{"
        let content = local_pretty_nodes(body, indent + 1)
        let footer = pad + "\}"
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
  NProp(_, hval) => hq_hml_show_raw(hval),
  NText(content) => content,
  _ => hq_pretty_node(node, 0)
}

pub fun raw_pretty_nodes(nodes: list<HmlNode>) : string =>
  match nodes {
    [] => "",
    [node] => raw_pretty_node(node),
    [node, ..rest] => raw_pretty_node(node) + "\n" + raw_pretty_nodes(rest)
  }
