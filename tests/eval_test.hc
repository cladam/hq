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

test "eval prop" {
  let doc = "@server(port: 8080) \{ log_file: \"app.log\" \}"
  let out = match run_query("@server |> prop(\"log_file\")", doc) {
    Ok(s) => s,
    _ => ""
  }
  assert(out == "log_file: \"app.log\"")
}
