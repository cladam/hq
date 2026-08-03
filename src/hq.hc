import "hml"
import "mutate"
import "std/string"
import "std/list"
import "hq_node"
import "hq_fmt"
import "hq_qtype"
import "hq_parse"

// -------------------------------------------------------------------
// Eval engine
// -------------------------------------------------------------------

pub fun eval_apply_op(node: HmlNode, op: QueryOp) : list<HmlNode> =>
  match op {
    OpElem(target) => eval_elem(node, target),
    OpAttr(target) => eval_attr(node, target),
    OpProp(target) => eval_prop(node, target),
    OpText => eval_text(node),
    OpDirective(target) => filter_directives(get_elem_body(node), target),
    OpSetAttr(key, vs) => eval_set_attr(node, key, parse_hml_val(vs)),
    OpSetProp(key, vs) => eval_set_prop(node, key, parse_hml_val(vs)),
    OpRemove => [],
    _ => []
  }

pub fun list_get(nodes: list<HmlNode>, n: int) : maybe<HmlNode> =>
  match nodes {
    [] => None,
    [node, ..rest] => if n <= 0 { Some(node) } else { list_get(rest, n - 1) }
  }

pub fun list_take(nodes: list<HmlNode>, n: int) : list<HmlNode> =>
  if n <= 0 { [] }
  else {
    match nodes {
      [] => [],
      [node, ..rest] => [node] + list_take(rest, n - 1)
    }
  }

pub fun unwrap_anonymous_root(nodes: list<HmlNode>) : list<HmlNode> =>
  match nodes {
    [NElem(HElement("", _, body))] => body,
    _ => nodes
  }

pub fun eval_op(nodes: list<HmlNode>, op: QueryOp) : list<HmlNode> =>
  match op {
    OpIndex(n) => match list_get(unwrap_anonymous_root(nodes), n) {
      Some(node) => [node],
      None => []
    },
    OpCount => [NProp("count", HInt(length(unwrap_anonymous_root(nodes))))],
    OpHead => match unwrap_anonymous_root(nodes) {
      [] => [],
      [node, ..] => [node]
    },
    OpTake(n) => list_take(unwrap_anonymous_root(nodes), n),
    _ => eval_op_map(nodes, op)
  }

pub fun eval_op_map(nodes: list<HmlNode>, op: QueryOp) : list<HmlNode> =>
  match nodes {
    [] => [],
    [node, ..rest] => eval_apply_op(node, op) + eval_op_map(rest, op)
  }

pub fun is_mutation_op(op: QueryOp) : bool =>
  match op {
    OpSetAttr(_, _) => true,
    OpSetProp(_, _) => true,
    OpRemove => true,
    _ => false
  }

pub fun has_mutation(ops: list<QueryOp>) : bool =>
  match ops {
    [] => false,
    [op, ..rest] => if is_mutation_op(op) { true } else { has_mutation(rest) }
  }

pub fun list_get_op(ops: list<QueryOp>, n: int) : maybe<QueryOp> =>
  match ops {
    [] => None,
    [op, ..rest] => if n <= 0 { Some(op) } else { list_get_op(rest, n - 1) }
  }

pub fun list_take_op(ops: list<QueryOp>, n: int) : list<QueryOp> =>
  if n <= 0 { [] }
  else {
    match ops {
      [] => [],
      [op, ..rest] => [op] + list_take_op(rest, n - 1)
    }
  }

pub fun split_mutation(ops: list<QueryOp>) : (list<QueryOp>, QueryOp) {
  let len = length(ops)
  let path = list_take_op(ops, len - 1)
  let last_op = match list_get_op(ops, len - 1) {
    Some(op) => op,
    None => OpRemove
  }
  (path, last_op)
}

pub fun apply_mutation(node: HmlNode, mutate_op: QueryOp) : list<HmlNode> =>
  match mutate_op {
    OpSetAttr(key, vs) => eval_set_attr(node, key, parse_hml_val(vs)),
    OpSetProp(key, vs) => eval_set_prop(node, key, parse_hml_val(vs)),
    OpRemove => [],
    _ => [node]
  }

pub fun is_node_match(node: HmlNode, op: QueryOp) : bool =>
  match op {
    OpElem(target) => hq_is_elem_named(node, target),
    OpProp(target) => match node {
      NProp(k, _) => k == target,
      _ => false
    },
    _ => false
  }

pub fun mutate_nodes(nodes: list<HmlNode>, path_ops: list<QueryOp>, mutate_op: QueryOp) : list<HmlNode> =>
  match path_ops {
    [] => {
      // If path is empty, we apply the mutation directly to all nodes in this list
      match nodes {
        [] => [],
        [node, ..rest] => apply_mutation(node, mutate_op) + mutate_nodes(rest, path_ops, mutate_op)
      }
    },
    [op] => {
      // If path has exactly one step, we are at the level where target nodes reside
      match nodes {
        [] => [],
        [node, ..rest] => {
          if is_node_match(node, op) {
            apply_mutation(node, mutate_op) + mutate_nodes(rest, path_ops, mutate_op)
          } else {
            [node] + mutate_nodes(rest, path_ops, mutate_op)
          }
        }
      }
    },
    [op, ..rest_ops] => {
      // Deeper path: we traverse down if the current node matches the current path step
      match nodes {
        [] => [],
        [node, ..rest] => {
          if is_node_match(node, op) {
            match node {
              NElem(HElement(name, attrs, body)) => {
                let mutated_body = mutate_nodes(body, rest_ops, mutate_op)
                [NElem(HElement(name, attrs, mutated_body))] + mutate_nodes(rest, path_ops, mutate_op)
              },
              _ => [node] + mutate_nodes(rest, path_ops, mutate_op)
            }
          } else {
            [node] + mutate_nodes(rest, path_ops, mutate_op)
          }
        }
      }
    }
  }

pub fun eval_pipeline(doc_nodes: list<HmlNode>, ops: list<QueryOp>) : list<HmlNode> {
  if has_mutation(ops) {
    let (path_ops, mutate_op) = split_mutation(ops)
    mutate_nodes(doc_nodes, path_ops, mutate_op)
  } else {
    let root = NElem(HElement("", [], doc_nodes))
    eval_pipeline_rec([root], ops)
  }
}

pub fun eval_pipeline_rec(current_nodes: list<HmlNode>, ops: list<QueryOp>) : list<HmlNode> =>
  match ops {
    [] => current_nodes,
    [op, ..rest] => eval_pipeline_rec(eval_op(current_nodes, op), rest)
  }

pub fun run_query(expr: string, hml_content: string) : result<string, string> =>
  run_query_ext_color(expr, hml_content, false, false)

pub fun run_query_ext(expr: string, hml_content: string, hq_raw: bool) : result<string, string> =>
  run_query_ext_color(expr, hml_content, hq_raw, false)

pub fun run_query_nodes_color(expr: string, nodes: list<HmlNode>, hq_raw: bool, use_color: bool) : result<string, string> {
  match parse_query(expr) {
    Ok(ops) => {
      let filtered = eval_pipeline(nodes, ops)
      let output = if hq_raw { raw_pretty_nodes(filtered) } else { local_pretty_nodes_ext(filtered, 0, use_color) }
      Ok(output)
    },
    Err(e) => Err("Query error: " + e)
  }
}

pub fun run_query_ext_color(expr: string, hml_content: string, hq_raw: bool, use_color: bool) : result<string, string> {
  match hml_parse_file_content(hml_content, "input.hml") {
    Ok(nodes) => run_query_nodes_color(expr, nodes, hq_raw, use_color),
    Err(e) => Err("Parse error: " + e)
  }
}
