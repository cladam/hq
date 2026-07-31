import "std/cli"

pub fun make_spec() {
  cli("hq", "0.1.0", "hq - a HML Query tool")
    |> flag("raw-output", "r", "Prints unquoted scalar strings or text content blocks directly")
    |> flag("in-place", "i", "Rewrites the target input file(s) atomically with the evaluation result")
    |> flag("color", "c", "Enables ANSI syntax colorization for terminal output")
    |> flag("slurp", "s", "Reads multiple top-level elements across inputs into a single list sequence")
    |> flag("no-include", "", "Disables recursive #include directive resolution during parsing")
    |> option_default("indent", "", "Sets the indentation level (spaces) for HML body serialization", "4")
    |> arg("expression", "The query expression to evaluate", true)
    |> arg("files...", "Input files (or STDIN if missing)", false)
}

pub fun cli_help_extended(spec) {
  let base_help = cli_help(spec)
  let extra_help = "EXTENDED HELP:\n" +
"  - Expression syntax: `@server |> attr(\"port\")`\n" +
"  - See https://github.com/cladam/hq for more examples.\n"
  base_help + "\n" + extra_help
}
