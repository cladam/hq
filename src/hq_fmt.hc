import "hml"
import "std/string"
import "std/list"
import "std/term"

pub fun show_hml_array(items: list<Hml>) : string =>
  show_hml_array_ext(items, false)

pub fun show_hml_array_ext(items: list<Hml>, use_color: bool) : string =>
  match items {
    [] => "",
    [x] => hq_hml_show_ext(x, use_color),
    [x, ..rest] => hq_hml_show_ext(x, use_color) + ", " + show_hml_array_ext(rest, use_color)
  }

pub fun hq_hml_show(v: Hml) : string =>
  hq_hml_show_ext(v, false)

pub noinline fun hq_hml_show_ext(v: Hml, use_color: bool) : string => match v {
  HStr(s)  => {
    let raw_s = if contains(s, "\n") { "\"\"\"\n" + s + "\n\"\"\"" } else { "\"" + s + "\"" }
    if use_color { ilseon_muted_teal(raw_s) } else { raw_s }
  },
  HInt(n)  => if use_color { ilseon_ochre(show(n)) } else { show(n) },
  HFloat(f) => if use_color { ilseon_ochre(show(f)) } else { show(f) },
  HBool(b) => {
    let raw_b = if b { "true" } else { "false" }
    if use_color { ilseon_sage(raw_b) } else { raw_b }
  },
  HDuration(amount, unit) => {
    let raw_d = show(amount) + unit
    if use_color { ilseon_amber(raw_d) } else { raw_d }
  },
  HDatetime(s) => if use_color { italic(ilseon_sage(s)) } else { s },
  HNull    => if use_color { dim(white("null")) } else { "null" },
  HArray(items) => {
    let inner = show_hml_array_ext(items, use_color)
    "[" + inner + "]"
  },
  HElement(name, attrs, body) => hq_show_element_ext(name, attrs, body, use_color)
}

pub fun show_attrs_list(attrs: list<(string, Hml)>) : string =>
  show_attrs_list_ext(attrs, false)

pub fun show_attrs_list_ext(attrs: list<(string, Hml)>, use_color: bool) : string =>
  match attrs {
    [] => "",
    [a] => hq_show_attr_ext(a, use_color),
    [a, ..rest] => hq_show_attr_ext(a, use_color) + ", " + show_attrs_list_ext(rest, use_color)
  }

pub fun hq_show_element(name: string, attrs: list<(string, Hml)>, body: list<HmlNode>) : string =>
  hq_show_element_ext(name, attrs, body, false)

pub fun hq_show_element_ext(name: string, attrs: list<(string, Hml)>, body: list<HmlNode>, use_color: bool) : string {
  let attr_str = if length(attrs) == 0 { "" } else { "(" + show_attrs_list_ext(attrs, use_color) + ")" }
  let body_str = if length(body) == 0 { "" } else { " \{ ... \}" }
  let elem_name = "@" + name
  let colored_elem = if use_color { ilseon_teal(elem_name) } else { elem_name }
  colored_elem + attr_str + body_str
}

pub fun hq_show_attr(entry: (string, Hml)) : string =>
  hq_show_attr_ext(entry, false)

pub fun hq_show_attr_ext(entry: (string, Hml), use_color: bool) : string => match entry {
  (k, HBool(true)) => if use_color { bold(ilseon_blue_teal(k)) } else { k },
  (k, v) => {
    let key_str = if use_color { bold(ilseon_blue_teal(k)) } else { k }
    key_str + ": " + hq_hml_show_ext(v, use_color)
  }
}

pub fun make_hml_indent(n: int) : string =>
  if n <= 0 { "" } else { "    " + make_hml_indent(n - 1) }

pub fun local_pretty_nodes(nodes: list<HmlNode>, indent: int) : string =>
  local_pretty_nodes_ext(nodes, indent, false)

pub fun local_pretty_nodes_ext(nodes: list<HmlNode>, indent: int, use_color: bool) : string =>
  match nodes {
    [] => "",
    [node] => hq_pretty_node_ext(node, indent, use_color),
    [node, ..rest] => hq_pretty_node_ext(node, indent, use_color) + "\n" + local_pretty_nodes_ext(rest, indent, use_color)
  }

pub fun hq_pretty_node(node: HmlNode, indent: int) : string =>
  hq_pretty_node_ext(node, indent, false)

pub noinline fun hq_pretty_node_ext(node: HmlNode, indent: int, use_color: bool) : string {
  let pad = make_hml_indent(indent)
  match node {
    NProp(key, hval) => {
      let key_str = if use_color { bold(ilseon_blue_teal(key)) } else { key }
      pad + key_str + ": " + hq_hml_show_ext(hval, use_color)
    },
    NElem(HElement(name, attrs, body)) => {
      let attr_str = if length(attrs) == 0 { "" } else { "(" + show_attrs_list_ext(attrs, use_color) + ")" }
      let elem_name = "@" + name
      let colored_elem = if use_color { ilseon_teal(elem_name) } else { elem_name }
      if length(body) == 0 { pad + colored_elem + attr_str }
      else {
        let header = pad + colored_elem + attr_str + " \{"
        let content = local_pretty_nodes_ext(body, indent + 1, use_color)
        let footer = pad + "\}"
        join([header, content, footer], "\n")
      }
    },
    NElem(_) => pad + (if use_color { ilseon_detail("// unknown element") } else { "// unknown element" }),
    NText(content) => pad + (if use_color { green(content) } else { content }),
    NComment(text) => pad + (if use_color { ilseon_detail("// " + text) } else { "// " + text }),
    NNamespace(pfx, uri) => {
      let directive_str = "#namespace " + pfx + ": \"" + uri + "\""
      pad + (if use_color { ilseon_slate_blue(directive_str) } else { directive_str })
    }
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
