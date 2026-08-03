import "hml"
import "std/string"
import "std/list"

pub fun upsert_attr(attrs: list<(string, Hml)>, key: string, hval: Hml) : list<(string, Hml)> =>
  match attrs {
    [] => [(key, hval)],
    [attr, ..rest] => if attr.0 == key { [(key, hval)] + rest } else { [attr] + upsert_attr(rest, key, hval) }
  }

pub fun upsert_prop(body: list<HmlNode>, key: string, hval: Hml) : list<HmlNode> =>
  match body {
    [] => [NProp(key, hval)],
    [node, ..rest] => match node {
      NProp(k, _) => if k == key { [NProp(key, hval)] + rest } else { [node] + upsert_prop(rest, key, hval) },
      _ => [node] + upsert_prop(rest, key, hval)
    }
  }

pub fun eval_set_attr(node: HmlNode, key: string, hval: Hml) : list<HmlNode> =>
  match node {
    NElem(HElement(name, attrs, body)) => [NElem(HElement(name, upsert_attr(attrs, key, hval), body))],
    _ => [node]
  }

pub fun eval_set_prop(node: HmlNode, key: string, hval: Hml) : list<HmlNode> =>
  match node {
    NElem(HElement(name, attrs, body)) => [NElem(HElement(name, attrs, upsert_prop(body, key, hval)))],
    _ => [node]
  }
