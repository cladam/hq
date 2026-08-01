# hq

A lightweight, zero-dependency command-line HML (Hica Markup Language) query and stream processor written in [hica](https://www.hica.dev).

`hq` allows you to slice, filter, and extract data from HML documents using a pipe-friendly query language resembling hica's own native functional pipeline style.

## Features

- **Direct AST Selection**: Fast, immutable transformations on HML element tree nodes.
- **Selector Primitives**:
  - `prop("name")` or `.name`: Selects content properties matching `name` inside an element body.
  - `attr("name")` or `@name` (when used in function form): Selects attribute metadata matching `name`.
  - `elem("name")` or `@name`: Selects child elements matching `name`.
- **Raw Scalar Output (`-r`, `--raw-output`)**: Output unquoted strings and raw scalars directly rather than formatting them as HML structures.
- **No Runtime Dependencies**: Compiled to a native native binary using the Koka-backed hica toolchain.

## Building and Running

Ensure you have `hica` installed. Then build the native binary:

```sh
hica build -o hq
```

Run queries against HML files:

```sh
./hq '<query-expression>' <file.hml>
```

To run built-in tests:

```sh
hica test tests/query_test.hc
hica test tests/eval_test.hc
```

## CLI Usage

```sh
hq [FLAGS] <expression> [FILE...]
```

### Flags & Options
- `-r`, `--raw-output`: Prints unquoted scalar strings or text content blocks directly instead of formatting them as HML.
- `-i`, `--in-place`: Rewrites the target input file(s) atomically with the evaluation result.
- `-c`, `--color`: Enables ANSI syntax colorization for terminal output.
- `-s`, `--slurp`: Reads multiple top-level elements across inputs into a single list sequence.
- `--no-include`: Disables recursive `#include` directive resolution during parsing.
- `--indent <N>`: Sets the indentation level (spaces) for HML body serialization (default: `4`).

## Examples

Using the provided `examples/tbdflow.hml`:

### Extract a Top-Level Property
```sh
$ ./hq '.main-branch-name' examples/tbdflow.hml
main-branch-name: "main"
```

### Extract raw unquoted values
```sh
$ ./hq -r '.main-branch-name' examples/tbdflow.hml
main
```

### Query deep nested configurations
```sh
$ ./hq '@review |> elem("labels") |> prop("pending")' examples/tbdflow.hml
pending: "review-pending"
```

### Query deep nested configurations in raw output mode
```sh
$ ./hq -r '@review |> elem("labels") |> prop("pending")' examples/tbdflow.hml
review-pending
```

### Run All Built-in Examples
You can run the complete examples showcase using:
```sh
./examples/run_examples.sh
```
