import "std/list"
import "../src/hq"

test "eval elem and attr" {
  let doc = "@server(port: 8080) \{ log_file: \"app.log\" \}"
  let out = match run_query("@server |> attr(\"port\")", doc) {
    Ok(s) => s,
    _ => ""
  }
  assert(out == "port: 8080")
}

test "eval elem and attr raw" {
  let doc = "@server(port: 8080) \{ log_file: \"app.log\" \}"
  let out = match run_query_ext("@server |> attr(\"port\")", doc, true) {
    Ok(s) => s,
    _ => ""
  }
  assert(out == "8080")
}

test "eval prop" {
  let doc = "@server(port: 8080) \{ log_file: \"app.log\" \}"
  let out = match run_query("@server |> prop(\"log_file\")", doc) {
    Ok(s) => s,
    _ => ""
  }
  assert(out == "log_file: \"app.log\"")
}

test "eval prop raw" {
  let doc = "@server(port: 8080) \{ log_file: \"app.log\" \}"
  let out = match run_query_ext("@server |> prop(\"log_file\")", doc, true) {
    Ok(s) => s,
    _ => ""
  }
  assert(out == "app.log")
}

test "eval advanced list selectors" {
  let doc = "@servers \{ @node(id: 1) @node(id: 2) @node(id: 3) \}"
  let count_out = match run_query("@servers |> elem(\"node\") |> count()", doc) {
    Ok(s) => s,
    _ => ""
  }
  assert(count_out == "count: 3")

  let index_out = match run_query_ext("@servers |> elem(\"node\") |> [1] |> attr(\"id\")", doc, true) {
    Ok(s) => s,
    _ => ""
  }
  assert(index_out == "2")

  let take_out = match run_query("@servers |> elem(\"node\") |> take(2)", doc) {
    Ok(s) => s,
    _ => ""
  }
  assert(take_out == "@node(id: 1)\n@node(id: 2)")

  let head_out = match run_query_ext("@servers |> elem(\"node\") |> head() |> attr(\"id\")", doc, true) {
    Ok(s) => s,
    _ => ""
  }
  assert(head_out == "1")
}

test "eval text and directive" {
  let doc = "#namespace k8s: \"https://kubernetes.io\"\n@body \{ Hello world\}"
  let directive_out = match run_query_ext("#k8s", doc, true) {
    Ok(s) => s,
    _ => ""
  }
  assert(directive_out == "https://kubernetes.io")

  let text_out = match run_query_ext("@body |> text()", doc, true) {
    Ok(s) => s,
    _ => ""
  }
  assert(text_out == "Hello world")
}

test "mutation set_attr" {
  let doc = "@server(port: 8080) \{ log_file: \"app.log\" \}"
  let out = match run_query("@server |> set_attr(\"port\", 9090)", doc) {
    Ok(s) => s,
    _ => ""
  }
  assert(out == "@server(port: 9090) \{\n    log_file: \"app.log\"\n\}")
}

test "mutation set_attr add new" {
  let doc = "@server \{ port: 8080 \}"
  let out = match run_query("@server |> set_attr(\"ssl\", true)", doc) {
    Ok(s) => s,
    _ => ""
  }
  assert(out == "@server(ssl) \{\n    port: 8080\n\}")
}

test "mutation set_prop" {
  let doc = "@server(port: 8080) \{ log_file: \"app.log\" \}"
  let out = match run_query("@server |> set_prop(\"log_file\", \"new.log\")", doc) {
    Ok(s) => s,
    _ => ""
  }
  assert(out == "@server(port: 8080) \{\n    log_file: \"new.log\"\n\}")
}

test "mutation remove" {
  let doc = "@servers \{ @node(id: 1) @node(id: 2) \}"
  let out = match run_query("@servers |> elem(\"node\") |> remove()", doc) {
    Ok(s) => s,
    _ => ""
  }
  assert(out == "@servers")
}
