import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/uri

pub type NodeType {
  Root
  Static
  Param
}

pub type Node(a) {
  Node(
    prefix: String,
    kind: NodeType,
    value: Option(a),
    children: Dict(String, Node(a)),
  )
}

pub fn root(children: List(Node(a))) -> Node(a) {
  Node(
    "",
    Root,
    None,
    dict.from_list(
      children
      |> list.map(fn(node) { #(node.prefix, node) }),
    ),
  )
}

pub fn new() -> Node(a) {
  root([])
}

pub fn longest_common_prefix(a: String, b: String) -> String {
  longest_common_prefix_impl(a, b, "")
}

fn longest_common_prefix_impl(a: String, b: String, r: String) -> String {
  case string.pop_grapheme(a), string.pop_grapheme(b) {
    Ok(#(a, a_rest)), Ok(#(b, b_rest)) -> {
      case a == b {
        True -> longest_common_prefix_impl(a_rest, b_rest, r <> a)
        False -> r
      }
    }
    _, _ -> r
  }
}

pub fn longest_common_path_prefix(a: String, b: String) -> String {
  let a_segments =
    uri.path_segments(a)
    |> list.map(fn(segment) { "/" <> segment })
    |> list.prepend("/")
  let b_segments =
    uri.path_segments(b)
    |> list.map(fn(segment) { "/" <> segment })
    |> list.prepend("/")

  list.zip(a_segments, b_segments)
  |> list.take_while(fn(pair) {
    let #(a_seg, b_seg) = pair
    a_seg == b_seg
  })
  |> list.map(fn(pair) {
    let #(segment, _) = pair
    segment
  })
  |> string.concat()
  |> fn(s) {
    case string.starts_with(s, "//") {
      True -> string.slice(s, 1, string.length(s))
      False -> s
    }
  }
}

pub fn insert(node: Node(a), key: String, value: a) -> Node(a) {
  case key {
    "" -> Node(node.prefix, node.kind, Some(value), node.children)
    _ -> {
      case key == node.prefix {
        True -> {
          insert(node, "", value)
        }
        False -> {
          case node.children |> dict.get(key) {
            Ok(child) -> {
              // full match
              insert(child, "", value)
            }
            Error(_) -> {
              case
                node.children
                |> dict.values()
                |> list.find_map(fn(el) {
                  let common = longest_common_path_prefix(el.prefix, key)

                  case common {
                    "" -> Error(Nil)
                    _ -> Ok(#(el, common))
                  }
                })
              {
                Ok(#(child, common)) -> {
                  let common_len = case common {
                    "/" -> 0
                    _ -> string.length(common)
                  }
                  // partial match
                  let new_prefix =
                    string.slice(
                      child.prefix,
                      common_len,
                      string.length(child.prefix) - common_len,
                    )
                  let new_other_prefix =
                    string.slice(
                      key,
                      common_len,
                      string.length(key) - common_len,
                    )

                  let #(children, value) = case common {
                    "/" -> #(
                      [#(new_prefix, Node(..child, prefix: new_prefix))],
                      Some(value),
                    )
                    _ -> #(
                      [
                        #(new_prefix, Node(..child, prefix: new_prefix)),
                        #(
                          new_other_prefix,
                          Node(
                            new_other_prefix,
                            Static,
                            Some(value),
                            dict.new(),
                          ),
                        ),
                      ],
                      None,
                    )
                  }

                  Node(
                    ..node,
                    children: node.children
                      |> dict.delete(child.prefix)
                      |> dict.insert(
                        common,
                        Node(common, Static, value, dict.from_list(children)),
                      ),
                  )
                }
                Error(_) -> {
                  Node(
                    ..node,
                    children: dict.insert(
                      node.children,
                      key,
                      Node(key, Static, Some(value), dict.new()),
                    ),
                  )
                }
              }
            }
          }
        }
      }
    }
  }
}

/// Merge two tries together, erroring on conflicts. Conflicts only
/// occur when two route segments have the same name but a different type.
///
/// Broken I think
pub fn merge(node: Node(a), other: Node(a)) -> Result(Node(a), Nil) {
  let Node(prefix, kind, value, children) = node
  let Node(other_prefix, other_kind, other_value, other_children) = other

  case prefix == other_prefix {
    True -> {
      case kind == other_kind {
        True -> {
          dict.fold(other_children, Ok(children), fn(acc, key, other_child) {
            acc
            |> result.then(fn(children) {
              case dict.get(children, key) {
                Ok(child) -> {
                  merge(child, other_child)
                  |> result.then(fn(child) {
                    Ok(dict.insert(children, key, child))
                  })
                }
                Error(_) -> {
                  // if common prefixes, merge them. otherwise, insert

                  // let common = longest_common_path_prefix(prefix, other_prefix)
                  //
                  Ok(dict.insert(children, key, other_child))
                }
              }
            })
          })
          |> result.map(fn(children) { Node(prefix, kind, value, children) })
        }
        False -> Error(Nil)
      }
    }
    False -> {
      let common = longest_common_path_prefix(prefix, other_prefix)

      case common {
        "" -> {
          panic as "bruh"
        }
        _ -> {
          let common_len = string.length(common)
          let new_prefix =
            string.slice(prefix, common_len, string.length(prefix) - common_len)
          let new_other_prefix =
            string.slice(
              other_prefix,
              common_len,
              string.length(other_prefix) - common_len,
            )

          Ok(Node(
            common,
            kind,
            value,
            dict.from_list([
              #(new_prefix, Node(new_prefix, kind, value, children)),
              #(
                new_other_prefix,
                Node(new_other_prefix, other_kind, other_value, other_children),
              ),
            ]),
          ))
        }
      }
    }
  }
}

pub fn build_route(path: String, value: a) -> Result(Node(a), Nil) {
  let segments =
    path
    |> uri.path_segments()
    |> list.map(fn(segment) {
      case string.starts_with(segment, "/") {
        True -> segment
        False -> "/" <> segment
      }
    })
    |> chunk_segments()
    |> list.reverse()

  build_route_impl(segments, None, value)
}

pub fn chunk_segments(segments: List(String)) -> List(String) {
  case segments {
    [] -> []
    [first, ..rest] -> {
      list.fold(rest, #([], first), fn(acc, segment) {
        let #(result, current) = acc
        case string.starts_with(segment, "/{") {
          True -> {
            case current {
              "" -> #([segment, ..result], "")
              _ -> #([segment, current, ..result], "")
            }
          }
          False -> #(result, current <> segment)
        }
      })
      |> fn(acc) {
        let #(result, current) = acc
        case current {
          "" -> result
          _ -> [current, ..result]
        }
      }
      |> list.reverse()
    }
  }
}

fn build_route_segment(segment: String) -> Result(#(NodeType, String), Nil) {
  let len = string.length(segment)
  case string.starts_with(segment, "/{") {
    True -> {
      let term = segment |> string.slice(len - 1, 1)

      case term {
        "}" -> Ok(#(Param, segment))
        _ -> Error(Nil)
      }
    }
    False -> Ok(#(Static, segment))
  }
}

fn build_route_impl(
  path: List(String),
  child: Option(Node(a)),
  value: a,
) -> Result(Node(a), Nil) {
  case child {
    Some(child) -> {
      case path {
        [] -> Ok(child)
        [segment, ..rest] -> {
          build_route_segment(segment)
          |> result.then(fn(segment) {
            let #(kind, segment) = segment

            let node =
              Node(
                segment,
                kind,
                None,
                dict.from_list([#(child.prefix, child)]),
              )

            build_route_impl(rest, Some(node), value)
          })
        }
      }
    }
    None -> {
      case path {
        [] -> Error(Nil)
        [segment, ..rest] -> {
          build_route_segment(segment)
          |> result.then(fn(segment) {
            let #(kind, segment) = segment

            let node = Node(segment, kind, Some(value), dict.new())

            build_route_impl(rest, Some(node), value)
            |> result.map(fn(node) {
              Node("", Root, None, dict.from_list([#(node.prefix, node)]))
            })
          })
        }
      }
    }
  }
}
