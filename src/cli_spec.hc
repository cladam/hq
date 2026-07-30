import "std/cli"

pub fun make_spec() =>
  cli("hq", "0.1.0", "hq - a HML Query tool")
    |> flag("verbose", "v", "Enable verbose output")

pub fun cli_help_extended(spec) {
  let base_help = cli_help(spec)
  let extra_help = "EXTENDED HELP:\n" +
"  Method             Explanation\n"
  base_help + "\n" + extra_help
}
