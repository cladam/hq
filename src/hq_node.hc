import "hml"
import "std/string"
import "std/list"

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

pub fun filter_elems_by_name(nodes: list<HmlNode>, target: string) : list<HmlNode> =>
  match nodes {
    [] => [],
    [node, ..rest] =>
      if hq_is_elem_named(node, target) { [node] + filter_elems_by_name(rest, target) }
      else { filter_elems_by_name(rest, target) }
  }

pub fun eval_elem(node: HmlNode, target: string) : list<HmlNode> =>
  filter_elems_by_name(get_elem_body(node), target)

pub fun eval_attr(node: HmlNode, target: string) : list<HmlNode> =>
  match find_attr_val(get_elem_attrs(node), target) {
    Some(hval) => [NProp(target, hval)],
    None => []
  }

pub fun filter_props_by_key(nodes: list<HmlNode>, target: string) : list<HmlNode> =>
  match nodes {
    [] => [],
    [node, ..rest] => match node {
      NProp(k, _) =>
        if k == target { [node] + filter_props_by_key(rest, target) }
        else { filter_props_by_key(rest, target) },
      _ => filter_props_by_key(rest, target)
    }
  }

pub fun eval_prop(node: HmlNode, target: string) : list<HmlNode> =>
  filter_props_by_key(get_elem_body(node), target)

pub fun filter_texts(nodes: list<HmlNode>) : list<HmlNode> =>
  match nodes {
    [] => [],
    [node, ..rest] => match node {
      NText(_) => [node] + filter_texts(rest),
      _ => filter_texts(rest)
    }
  }

pub fun eval_text(node: HmlNode) : list<HmlNode> =>
  match node {
    NElem(HElement(_, _, body)) => filter_texts(body),
    NText(_) => [node],
    _ => []
  }

pub fun filter_directives(nodes: list<HmlNode>, target: string) : list<HmlNode> =>
  match nodes {
    [] => [],
    [node, ..rest] => match node {
      NNamespace(pfx, uri) =>
        if pfx == target { [NProp(pfx, HStr(uri))] + filter_directives(rest, target) }
        else { filter_directives(rest, target) },
      _ => filter_directives(rest, target)
    }
  }
