import gleam/dict.{type Dict}
import gleam/int
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

pub fn root() -> Node(a) {
  Node("", Root, None, dict.new())
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

pub fn insert(node: Node(a), key: String, value: a) -> Node(a) {
  todo
}

pub fn build_route(path: String, value: a) -> Result(Node(a), Nil) {
  let segments = path |> uri.path_segments() |> list.reverse()

  build_route_impl(segments, None, value)
}

fn build_root_segment(segment: String) -> Result(#(NodeType, String), Nil) {
  let len = string.length(segment)
  case string.starts_with(segment, "{") {
    True -> {
      let term = segment |> string.slice(len - 1, 1)
      let segment = segment |> string.slice(1, len - 2)

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
          build_root_segment(segment)
          |> result.then(fn(segment) {
            let #(kind, segment) = segment

            let node =
              Node(
                "/" <> segment,
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
          build_root_segment(segment)
          |> result.then(fn(segment) {
            let #(kind, segment) = segment

            let node = Node("/" <> segment, kind, Some(value), dict.new())

            build_route_impl(rest, Some(node), value)
          })
        }
      }
    }
  }
}
