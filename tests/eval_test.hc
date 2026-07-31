import "std/list"
import "../src/query"

test "eval elem and attr" {
  let doc = "@server(port: 8080) \{ log_file: \"app.log\" \}"
  let nodes = match parse_hml_content(doc, "test.hml") {
    Ok(n) => n,
    Err(_) => []
  }
  
  let ops = match parse_query("@server |> attr(\"port\")") {
    Ok(o) => o,
    Err(_) => []
  }
  
  let result = eval_pipeline(nodes, ops)
  
  let success = match result {
    [NProp(k, HInt(v))] => k == "port" && v == 8080,
    _ => false
  }
  assert(success)
}

test "eval prop" {
  let doc = "@server(port: 8080) \{ log_file: \"app.log\" \}"
  let nodes = match parse_hml_content(doc, "test.hml") {
    Ok(n) => n,
    Err(_) => []
  }
  
  let ops = match parse_query("@server |> prop(\"log_file\")") {
    Ok(o) => o,
    Err(_) => []
  }
  
  let result = eval_pipeline(nodes, ops)
  
  let success = match result {
    [NProp(k, HStr(v))] => k == "log_file" && v == "app.log",
    _ => false
  }
  assert(success)
}
