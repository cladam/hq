import "std/cli"

fun main() {
  let spec = cli("test", "1", "test")
    |> flag("raw-output", "r", "Prints unquoted scalar strings")
    |> flag("no-include", "", "Disables recursive include")
    |> param("indent", "", "Sets indent level")
    |> arg("expression", "The query expression")
    |> rest("files", "Input files")
    
  println(cli_help(spec))
}
