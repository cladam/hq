# Design Document: `hq` (HML Query Tool)

`hq` is a zero-dependency CLI tool built natively in **hica** for querying, filtering, and transforming HML (Hica Markup Language) documents.

Designed around **hica’s functional programming principles**, `hq` operates strictly on HML AST structures using immutable data transformations, lazy streams, transducers, and pure expression pipelines.

## 1. Core Architecture & FP Philosophy

`hq` processes HML strictly as an HML-to-HML transformer. Cross-format conversions (such as JSON or YAML) are explicitly excluded to keep the tool focused on HML's semantic feature set: metadata attributes `(...)`, content properties `{...}`, native durations/date-times, and text-mode blocks.

```
┌─────────────┐     ┌──────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│ Input File  │ ──> │ HML Parser   │ ──> │ Transducer Pipeline  │ ──> │ HML Formatter   │
│ or STDIN    │     │ (cladam/hml) │     │ (std/xform Engine)   │     │ & Colorizer     │
└─────────────┘     └──────────────┘     └──────────────────────┘     └─────────────────┘

```

### Key Architectural Principles

* **Immutability by Default:** Queries never mutate HML nodes in place; transformations construct new AST nodes via pattern matching.
* **Lazy Stream & Transducer Evaluation:** Document nodes are evaluated using lazy streams (`std/stream`) or zero-allocation transducer pipelines (`std/xform`), preventing unnecessary allocations when querying large HML trees.
* **Safe Failure Handling:** Partial paths, missing attributes, or parse failures use `Maybe` (`Some`/`None`) and `Result` (`Ok`/`Err`) types with early-exit operators (`?`).

## 2. AST Data Model (`hica` ADTs)

The HML AST is represented using native hica algebraic data types (enums and structs):

```hica
// Represents HML Value types
type HmlValue {
  HmlString(val: string),
  HmlInt(val: int),
  HmlFloat(val: float),
  HmlBool(val: bool),
  HmlDuration(amount: int, unit: string),  // ns, us, ms, s, m, h, d
  HmlDateTime(val: string),                 // RFC 3339 timestamp
  HmlArray(items: list<HmlValue>),
  HmlInlineElement(elem: HmlElement),
  HmlNull
}

// Represents structural identity (attributes) and content (properties/elements)
struct Attribute { key: string, value: HmlValue }
struct Property  { key: string, value: HmlValue }

type BodyItem {
  ItemElement(elem: HmlElement),
  ItemProperty(prop: Property),
  ItemText(content: string)
}

struct HmlElement {
  name: string,
  attributes: list<Attribute>,
  body: list<BodyItem>
}

struct HmlDocument {
  directives: list<string>,
  root_properties: list<Property>,
  root_elements: list<HmlElement>
}

```

## 3. CLI Interface & Flag Specification

```bash
hq [FLAGS] [OPTIONS] <expression> [FILE...]

```

### Flags & Options

* `-r`, `--raw-output`: Prints unquoted scalar strings or text content blocks directly instead of formatting them as HML.
* `-i`, `--in-place`: Rewrites the target input file(s) atomically with the evaluation result.
* `-c`, `--color`: Enables ANSI syntax colorization for terminal output.
* `-s`, `--slurp`: Reads multiple top-level elements across inputs into a single list sequence.
* `--no-include`: Disables recursive `#include` directive resolution during parsing.
* `--indent <N>`: Sets the indentation level (spaces) for HML body serialization (default: `4`).

## 4. Query Language Specification

`hq` query expressions follow a pure, functional pipeline style matching `hica`'s native syntax. Steps are chained using the pipe operator (`|>`), point-free combinations, and higher-order functions.

### A. Selector Primitives

| Selector Function | Short Form | Target Description | Spec Reference |
| --- | --- | --- | --- |
| `prop(name)` | `.name` | Selects properties matching `name` inside an element body. |  |
| `attr(name)` | `@name` | Selects attribute metadata matching `name` from parentheses `(...)`. |  |
| `elem(name)` | `@elem_name` | Selects child elements matching `name`. |  |
| `text()` | `.text()` | Extracts raw text content from built-in or declared `#text` containers. |  |
| `directive(name)` | `#name` | Extracts directive values (e.g., `#schema`, `#namespace`). |  |
| `index(n)` | `[n]` | Selects the element at index `n` from repeated element lists. |  |

### B. Functional Pipeline Operations

Query pipelines combine transformations lazily over elements:

```hica
// Pipeline Combinators
map(f)          // Transforms every matched node
filter(pred)    // Filters nodes matching a predicate function
flat_map(f)     // Maps and flattens nested node lists
head()          // Selects the first matching node (returns maybe<HmlNode>)
take(n)         // Takes first n items lazily
fold(init, f)   // Aggregates matching nodes into a single value
```

## 5. Expression Examples & Functional Semantics

### 1. Attribute Metadata Querying

Accessing identity attributes inside an `@element(...)` tag:

```bash
hq '@server |> attr("port")' config.hml

```

*Equivalent hica evaluation:*

```hica
doc |> root_elements 
    |> filter((e) => e.name == "server") 
    |> flat_map((e) => e.attributes) 
    |> filter((a) => a.key == "port")
```

### 2. Filtering Repeated Elements with Duration Literals

Filtering repeated elements (`@node`) by comparing native duration values (`ms`, `s`, `h`):

```bash
hq '@upstream |> prop("retry") |> filter((r) => r.delay > 500ms)' service.hml
```

### 3. Text Mode Block Extraction (Raw Output)

Extracting text from text-mode wrapper containers like `@body`, `@p`, or `@text`:

```bash
hq -r '@article |> elem("body") |> text()' post.hml
```

### 4. Boolean Flag Selectors

Matching elements based on implicit boolean attribute flags (e.g., `@field(required)`):

```bash
hq '@field |> filter((f) => f |> attr("required") == true) |> prop("name")' schema.hml
```

### 5. Document Transductions & Aggregations

Counting active nodes in a cluster using transducers (`std/xform`):

```bash
hq '@cluster |> elem("node") |> filter((n) => n |> attr("status") == "healthy") |> count()' cluster.hml
```

## 6. Structural AST Mutation Syntax

Mutations return a newly constructed HML tree using pattern matching.

### AST Mutation Functions

* `set_attr(key, value)`: Updates or inserts an attribute into targeted elements.
* `set_prop(key, value)`: Updates or inserts a property inside targeted element bodies.
* `remove()`: Strips targeted properties, attributes, or elements from the output AST.

### Mutation Examples

```bash
# Update a database port property in-place
hq -i '.database |> set_prop("port", 5433)' db.hml

# Add an attribute flag to a server element
hq '@server |> set_attr("ssl", true)' config.hml

# Strip deprecated properties from document
hq '.deprecated_field |> remove()' app.hml
```

## 7. Directives & Include Resolution

* **Include Resolution (`#include`):** By default, `hq` recursively loads and textually merges files declared in `#include` directives relative to the parent file's directory.
* **Bypassing Includes:** Passing `--no-include` causes `hq` to skip file loading and evaluate the directives as bare AST nodes.
* **Text Mode Registrations (`#text`):** `#text` directives are parsed during AST construction to dynamically switch parser boundaries for user-defined text containers.

## 8. Implementation Engine Blueprint (`hica`)

Below is the foundational hica evaluation function demonstrating how `hq` uses pattern matching, `Maybe` types, and pipeline operators to execute path queries:

```hica
import "std/stream"
import "std/xform"

// Pure function: evaluates an attribute lookup on an element
fun eval_attr(elem: HmlElement, key: string) : maybe<HmlValue> {
  elem.attributes
    |> stream()
    |> filter((a) => a.key == key)
    |> map((a) => a.value)
    |> collect()
    |> match {
      [val, ..] => Some(val),
      []        => None
    }
}

// Pure function: transforms an element body using transducers
fun transform_body(elem: HmlElement, xform) : HmlElement {
  let updated_items = elem.body |> transduce(xform)
  HmlElement {
    name: elem.name,
    attributes: elem.attributes,
    body: updated_items
  }
}
```