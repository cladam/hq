import "std/cli"
import "std/list"
import "std/io"
import "./cli_spec"
import "./query"

fun process_file(f: string, ops: list<QueryOp>, raw_output: bool) {
  match read_file(f) {
    Ok(content) => {
      match parse_hml_content(content, f) {
        Ok(nodes) => {
          let filtered = eval_pipeline(nodes, ops)
          println(pretty_print_nodes(filtered))
        },
        Err(e) => eprintln("Parse error in {f}: {e}")
      }
    },
    Err(e) => eprintln("Failed to read {f}: {e}")
  }
}

fun main() {
  let spec = make_spec()
  match cli_parse(spec) {
    Help          => println(cli_help(spec)),
    Version       => println(cli_version_str(spec)),
    CliError(msg) => eprintln("error: " + msg),
    Parsed(r)     => {
      let raw_output = has_flag(r, "raw-output")
      let pos = get_positionals(r)

      match pos {
        [] => eprintln("error: Missing expression argument"),
        [expr, ..files] => {
          match parse_query(expr) {
            Ok(ops) => {
              match files {
                [] => eprintln("No files provided, STDIN reading coming next"),
                _ => foreach(files, (f) => process_file(f, ops, raw_output))
              }
            },
            Err(err) => eprintln("Query error: " + err)
          }
        }
      }
    }
  }
}
