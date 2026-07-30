import "std/cli"
import "std/term"
import "std/io"
import "std/list"
import "cli_spec"

fun main() {
  let spec = make_spec()
  match cli_parse(spec) {
    Help          => println(cli_help_extended(spec)),
    Version       => println(cli_version_str(spec)),
    CliError(msg) => eprintln("error: {msg}"),
    Parsed(r)     => {
      let raw_output = has_flag(r, "raw-output")
      let in_place = has_flag(r, "in-place")
      
      let pos = get_positionals(r)
      if is_empty(pos) {
        eprintln("error: Missing expression argument")
      } else {
        let expr = head_or(pos, "")
        let files = tail(pos)
        
        println("Expression: {expr}")
        if is_empty(files) {
          println("No files provided, would read STDIN")
        } else {
          foreach(files, (f) => {
            println("File: {f}")
            match read_file(f) {
              Ok(content) => println("Read {show(length(content))} bytes from {f}"),
              Err(e)      => eprintln("Failed to read {f}: {e}")
            }
          })
        }
      }
    }
  }
}
