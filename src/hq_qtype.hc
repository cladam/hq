import "hml"
import "std/string"
import "std/list"

pub type QueryOp {
  OpElem(name: string),
  OpProp(name: string),
  OpAttr(name: string),
  OpText,
  OpDirective(name: string),
  OpIndex(n: int),
  OpCount,
  OpHead,
  OpTake(n: int),
  OpSetAttr(key: string, val_str: string),
  OpSetProp(key: string, val_str: string),
  OpRemove
}

pub noinline fun parse_digits(s: string, pos: int, acc: int) : int {
  if pos >= str_length(s) { acc }
  else {
    let ch = s[pos:pos+1]
    if contains("0123456789", ch) {
      let digit = match ch {
        "1" => 1, "2" => 2, "3" => 3, "4" => 4, "5" => 5,
        "6" => 6, "7" => 7, "8" => 8, "9" => 9, _ => 0
      }
      parse_digits(s, pos + 1, acc * 10 + digit)
    } else {
      acc
    }
  }
}

pub noinline fun local_parse_int(s: string) : int => parse_digits(s, 0, 0)

pub noinline fun parse_hml_val(s: string) : Hml {
  if starts_with(s, "\"") && ends_with(s, "\"") {
    HStr(s[1:str_length(s) - 1])
  } else if s == "true" { HBool(true) }
  else if s == "false" { HBool(false) }
  else if s == "null" { HNull }
  else { HInt(local_parse_int(s)) }
}

pub noinline fun parse_set_op(step: string, prefix_len: int) : result<(string, string), string> {
  let after_prefix = step[prefix_len:]
  let parts = split(after_prefix, "\", ")
  match parts {
    [key, val_part] => {
      let slen = str_length(val_part)
      Ok((key, trim(val_part[:slen - 1])))
    },
    _ => Err("Invalid set_attr/set_prop syntax: " + step)
  }
}

pub noinline fun parse_step_a(step: string) : result<QueryOp, string> {
  if step == "text()" || step == ".text()" {
    Ok(OpText)
  } else if step == "count()" {
    Ok(OpCount)
  } else if step == "head()" {
    Ok(OpHead)
  } else if step == "remove()" {
    Ok(OpRemove)
  } else if starts_with(step, "@") {
    Ok(OpElem(step[1:]))
  } else if starts_with(step, ".") {
    Ok(OpProp(step[1:]))
  } else if starts_with(step, "#") {
    Ok(OpDirective(step[1:]))
  } else if starts_with(step, "directive(\"") && ends_with(step, "\")") {
    let len = str_length(step)
    Ok(OpDirective(step[11:len - 2]))
  } else {
    Err("__no_match__")
  }
}

pub noinline fun parse_step_b(step: string) : result<QueryOp, string> {
  if starts_with(step, "attr(\"") && ends_with(step, "\")") {
    let len = str_length(step)
    Ok(OpAttr(step[6:len - 2]))
  } else if starts_with(step, "elem(\"") && ends_with(step, "\")") {
    let len = str_length(step)
    Ok(OpElem(step[6:len - 2]))
  } else if starts_with(step, "prop(\"") && ends_with(step, "\")") {
    let len = str_length(step)
    Ok(OpProp(step[6:len - 2]))
  } else if starts_with(step, "set_attr(\"") && ends_with(step, ")") {
    match parse_set_op(step, 10) {
      Ok((key, val_s)) => Ok(OpSetAttr(key, val_s)),
      Err(e) => Err(e)
    }
  } else if starts_with(step, "set_prop(\"") && ends_with(step, ")") {
    match parse_set_op(step, 10) {
      Ok((key, val_s)) => Ok(OpSetProp(key, val_s)),
      Err(e) => Err(e)
    }
  } else if starts_with(step, "take(") && ends_with(step, ")") {
    let len = str_length(step)
    let n = local_parse_int(step[5:len - 1])
    Ok(OpTake(n))
  } else if starts_with(step, "index(") && ends_with(step, ")") {
    let len = str_length(step)
    let n = local_parse_int(step[6:len - 1])
    Ok(OpIndex(n))
  } else if starts_with(step, "[") && ends_with(step, "]") {
    let len = str_length(step)
    let n = local_parse_int(step[1:len - 1])
    Ok(OpIndex(n))
  } else {
    Err("Unknown query step: " + step)
  }
}
