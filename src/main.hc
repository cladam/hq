import "std/cli"
import "std/list"
import "std/io"
import "hml"
import "hq"

fun make_spec() =>
  cli("hq", "0.3.0", "hq - a HML Query tool")
    |> flag("raw-output", "r", "Prints unquoted scalar strings or text content blocks directly")
    |> flag("in-place", "i", "Rewrites the target input file(s) atomically with the evaluation result")
    |> flag("color", "c", "Enables ANSI syntax colorization for terminal output")
    |> flag("slurp", "s", "Reads multiple top-level elements across inputs into a single list sequence")
    |> flag("no-include", "", "Disables recursive #include directive resolution during parsing")
    |> option_default("indent", "", "Sets the indentation level (spaces) for HML body serialization", "4")
    |> arg("expression", "The query expression to evaluate", true)
    |> arg("files", "Input files (or STDIN if missing)", false)

fun process_file(f: string, expr: string, is_raw: bool, in_place: bool, use_color: bool, no_include: bool) {
  match read_file(f) {
    Ok(content) => {
      let processed = if no_include { replace(content, "#include", "// #include") } else { content }
      match run_query_ext_color(expr, processed, f, is_raw, use_color) {
        Ok(result) => {
          if in_place {
            match write_file(f, result) {
              Ok(_) => { },
              Err(e) => eprintln("Failed to write {f}: {e}")
            }
          } else {
            println(result)
          }
        },
        Err(e) => eprintln("error: {e}")
      }
    },
    Err(e) => eprintln("Failed to read {f}: {e}")
  }
}

fun process_slurp(files: list<string>, expr: string, is_raw: bool, use_color: bool, no_include: bool) {
  var combined: list<HmlNode> = []
  var has_error = false
  
  foreach(files, (f) => {
    if !has_error {
      match read_file(f) {
        Ok(content) => {
          let processed = if no_include { replace(content, "#include", "// #include") } else { content }
          match hml_parse_file_content(processed, f) {
            Ok(nodes) => {
              combined = combined + nodes
            },
            Err(e) => {
              eprintln("Parse error in {f}: {e}")
              has_error = true
            }
          }
        },
        Err(e) => {
          eprintln("Failed to read {f}: {e}")
          has_error = true
        }
      }
    }
  })
  
  if !has_error {
    match run_query_nodes_color(expr, combined, is_raw, use_color) {
      Ok(result) => println(result),
      Err(e) => eprintln("error: {e}")
    }
  }
}

fun main() {
  let spec = make_spec()
  match cli_parse(spec) {
    Help          => println(cli_help(spec)),
    Version       => println(cli_version_str(spec)),
    CliError(msg) => eprintln("error: {msg}"),
    Parsed(r)     => {
      let raw_output = has_flag(r, "raw-output")
      let in_place   = has_flag(r, "in-place")
      let use_color  = has_flag(r, "color")
      let no_include = has_flag(r, "no-include")
      let slurp      = has_flag(r, "slurp")
      let pos = get_positionals(r)
      match pos {
        [] => eprintln("error: Missing expression argument"),
        [expr, ..files] => {
          if slurp {
            process_slurp(files, expr, raw_output, use_color, no_include)
          } else {
            foreach(files, (f) => process_file(f, expr, raw_output, in_place, use_color, no_include))
          }
        }
      }
    }
  }
}
