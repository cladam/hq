import "std/cli"
import "std/term"
import "cli_spec"

fun main() {
  println("hello from hq")
  let spec = make_spec()
  match cli_parse(spec) {
    Help          => println(cli_help_extended(spec)),
    Version       => println(cli_version_str(spec)),
    CliError(msg) => eprintln("error: {msg}"),
    Parsed(r)     => {
      let verbose = has_flag(r, "verbose")
      if verbose {
        println("Verbose mode is ON")
        println("CLI Parsed successfully!")
      }
    }
  }
}
