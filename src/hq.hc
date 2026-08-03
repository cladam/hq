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

pub fun eval_op(nodes: list<HmlNode>, op: QueryOp) : list<HmlNode> =>
  match op {
    OpIndex(n) => match list_get(nodes, n) {
      Some(node) => [node],
      None => []
    },
    OpCount => [NProp("count", HInt(length(nodes)))],
    OpHead => match nodes {
      [] => [],
      [node, ..] => [node]
    },
    OpTake(n) => list_take(nodes, n),
    _ => eval_op_map(nodes, op)
  }

pub fun eval_op_map(nodes: list<HmlNode>, op: QueryOp) : list<HmlNode> =>
  match nodes {
    [] => [],
    [node, ..rest] => eval_apply_op(node, op) + eval_op_map(rest, op)
  }

pub fun eval_pipeline(doc_nodes: list<HmlNode>, ops: list<QueryOp>) : list<HmlNode> {
  let root = NElem(HElement("", [], doc_nodes))
  eval_pipeline_rec([root], ops)
}

pub fun eval_pipeline_rec(current_nodes: list<HmlNode>, ops: list<QueryOp>) : list<HmlNode> =>
  match ops {
    [] => current_nodes,
    [op, ..rest] => eval_pipeline_rec(eval_op(current_nodes, op), rest)
  }

pub fun run_query(expr: string, hml_content: string) : result<string, string> =>
  run_query_ext(expr, hml_content, false)

pub fun run_query_ext(expr: string, hml_content: string, hq_raw: bool) : result<string, string> {
  match parse_query(expr) {
    Ok(ops) => match hml_parse_file_content(hml_content, "input.hml") {
      Ok(nodes) => {
        let filtered = eval_pipeline(nodes, ops)
        let output = if hq_raw { raw_pretty_nodes(filtered) } else { local_pretty_nodes(filtered, 0) }
        Ok(output)
      },
      Err(e) => Err("Parse error: " + e)
    },
    Err(e) => Err("Query error: " + e)
  }
}
