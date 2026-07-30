import "../src/query"

test "parse simple elem and attr pipeline" {
  let r = parse_query("@server |> attr(\"port\")")
  let success = match r {
    Ok([OpElem(e), OpAttr(a)]) => e == "server" && a == "port",
    _ => false
  }
  assert(success)
}

test "parse prop short syntax" {
  let r = parse_query(".database")
  let success = match r {
    Ok([OpProp(p)]) => p == "database",
    _ => false
  }
  assert(success)
}