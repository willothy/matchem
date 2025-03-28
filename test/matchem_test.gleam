import gleam/dict.{type Dict}
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should

import matchem.{type Node, Node}

pub fn main() {
  gleeunit.main()
}

pub fn chunk_segments_test() {
  matchem.chunk_segments(["/a", "/b", "/{c}", "/d"])
  |> should.equal(["/a/b", "/{c}", "/d"])
}

pub fn longest_common_prefix_test() {
  matchem.longest_common_prefix("hello", "hello") |> should.equal("hello")
  matchem.longest_common_prefix("hello", "world") |> should.equal("")
  matchem.longest_common_prefix("hello", "hell") |> should.equal("hell")
  matchem.longest_common_prefix("hello", "hel") |> should.equal("hel")
  matchem.longest_common_prefix("hello", "he") |> should.equal("he")
  matchem.longest_common_prefix("hello", "h") |> should.equal("h")
  matchem.longest_common_prefix("hello", "") |> should.equal("")
  matchem.longest_common_prefix("", "hello") |> should.equal("")
  matchem.longest_common_prefix("", "") |> should.equal("")
}

pub fn longest_common_path_prefix_test() {
  matchem.longest_common_path_prefix("/hello/world/test", "/hello/world/toss")
  |> should.equal("/hello/world")
  matchem.longest_common_path_prefix("/hello", "/world") |> should.equal("/")
  matchem.longest_common_path_prefix("/hello", "/hell") |> should.equal("/")

  matchem.longest_common_path_prefix(
    "/api/users/profile",
    "/api/users/settings",
  )
  |> should.equal("/api/users")
}

pub fn build_route_empty_fails_test() {
  matchem.build_route("", 123) |> should.be_error()
}

pub fn build_route_basic_test() {
  let route = matchem.build_route("/test/abc/123", 123)

  let head = Node("/test/abc/123", matchem.Static, Some(123), dict.new())

  route
  |> should.equal(Ok(matchem.root([head])))
}

pub fn build_route_param_test() {
  let route = matchem.build_route("/test/{abc}/123", 123)

  let last = Node("/123", matchem.Static, Some(123), dict.new())
  let next =
    Node("/{abc}", matchem.Param, None, dict.from_list([#("/123", last)]))
  let head =
    Node("/test", matchem.Static, None, dict.from_list([#("/{abc}", next)]))

  route
  |> should.equal(Ok(matchem.root([head])))
}

pub fn build_route_param_missing_closing_brace_test() {
  let route = matchem.build_route("/test/{abc/123", 123)

  route
  |> should.equal(Error(Nil))
}

pub fn merge_empty_test() {
  let a = matchem.root([])
  let b = matchem.root([])

  matchem.merge(a, b) |> should.equal(Ok(a))
}

/// Convert a node into a single-element list of pairs for use with `dict.from_list`.
fn as_children(node: Node(a)) -> Dict(String, Node(a)) {
  dict.from_list([#(node.prefix, node)])
}

fn as_entry(node: Node(a)) -> #(String, Node(a)) {
  #(node.prefix, node)
}

pub fn merge_empty_with_child_test() {
  let a = matchem.root([])

  let child = Node("/test", matchem.Static, None, dict.new())
  let b = Node("", matchem.Root, None, as_children(child))

  matchem.merge(a, b) |> should.equal(Ok(b))
}

pub fn merge_child_with_empty_test() {
  let b = matchem.root([])

  let child = Node("/test", matchem.Static, None, dict.new())
  let a = Node("", matchem.Root, None, as_children(child))

  matchem.merge(a, b) |> should.equal(Ok(a))
}

pub fn merge_different_type_fails_test() {
  let child_a = Node("/test", matchem.Static, None, dict.new())
  let a = Node("", matchem.Root, None, as_children(child_a))

  let child_b = Node("/test", matchem.Param, None, dict.new())
  let b = Node("", matchem.Root, None, as_children(child_b))

  matchem.merge(a, b) |> should.be_error()
}

pub fn merge_different_prefix_fails_test() {
  let child_a = Node("/test", matchem.Static, None, dict.new())
  let a = Node("", matchem.Root, None, as_children(child_a))

  let child_b = Node("/other", matchem.Static, None, dict.new())
  let b = Node("", matchem.Root, None, as_children(child_b))

  // The nodes being merged have the same prefix, but their children don't
  matchem.merge(a, b) |> should.be_ok()
}

pub fn merge_nested_children_test() {
  // Build first trie: /api/users
  let user_node = Node("/users", matchem.Static, Some(1), dict.new())
  let api_node = Node("/api", matchem.Static, None, as_children(user_node))
  let a = Node("", matchem.Root, None, as_children(api_node))

  // Build second trie: /api/posts
  let posts_node = Node("/posts", matchem.Static, Some(2), dict.new())
  let api_node_b = Node("/api", matchem.Static, None, as_children(posts_node))
  let b = Node("", matchem.Root, None, as_children(api_node_b))

  // After merging, we should have /api with both /users and /posts as children
  let result = matchem.merge(a, b)
  result |> should.be_ok()

  // Expected: a trie with both routes
  let expected_api_node =
    Node(
      "/api",
      matchem.Static,
      None,
      dict.from_list([#("/users", user_node), #("/posts", posts_node)]),
    )
  let expected = Node("", matchem.Root, None, as_children(expected_api_node))

  result |> should.equal(Ok(expected))
}

pub fn merge_recursive_test() {
  // Build first trie: /api/users/profile
  let profile_node = Node("/profile", matchem.Static, Some(1), dict.new())
  let users_node =
    Node("/users", matchem.Static, None, as_children(profile_node))
  let api_node = Node("/api", matchem.Static, None, as_children(users_node))
  let a = Node("", matchem.Root, None, as_children(api_node))

  // Build second trie: /api/users/settings
  let settings_node = Node("/settings", matchem.Static, Some(2), dict.new())
  let users_node_b =
    Node("/users", matchem.Static, None, as_children(settings_node))
  let api_node_b = Node("/api", matchem.Static, None, as_children(users_node_b))
  let b = Node("", matchem.Root, None, as_children(api_node_b))

  // After merging, we should have /api/users with both /profile and /settings as children
  let result = matchem.merge(a, b)
  result |> should.be_ok()

  // Expected: a trie with both nested routes
  let expected_users_node =
    Node(
      "/users",
      matchem.Static,
      None,
      dict.from_list([
        #("/profile", profile_node),
        #("/settings", settings_node),
      ]),
    )
  let expected_api_node =
    Node("/api", matchem.Static, None, as_children(expected_users_node))
  let expected = Node("", matchem.Root, None, as_children(expected_api_node))

  result |> should.equal(Ok(expected))
}

// pub fn merge_built_test() {
//   let assert Ok(a) = matchem.build_route("/api/users/profile", 1)
//   let assert Ok(b) = matchem.build_route("/api/users/settings", 2)
//
//   a
//   |> should.equal(
//     matchem.root([
//       Node("/api/users/profile", matchem.Static, Some(1), dict.new()),
//     ]),
//   )
//   b
//   |> should.equal(
//     matchem.root([
//       Node("/api/users/settings", matchem.Static, Some(2), dict.new()),
//     ]),
//   )
//
//   // After merging, we should have:
//   //
//   // /api/users
//   // |- /profile
//   // |- /settings
//
//   let assert Ok(merged) = matchem.merge(a, b)
//
//   merged
//   |> should.equal(
//     matchem.root([
//       Node(
//         "/api/users",
//         matchem.Static,
//         None,
//         dict.from_list([
//           #("/profile", Node("/profile", matchem.Static, Some(1), dict.new())),
//           #("/settings", Node("/settings", matchem.Static, Some(2), dict.new())),
//         ]),
//       ),
//     ]),
//   )
// }

pub fn insert_basic_test() {
  let route = matchem.insert(matchem.root([]), "/test/abc/123", 123)

  let head = Node("/test/abc/123", matchem.Static, Some(123), dict.new())

  route
  |> should.equal(matchem.root([head]))

  let route = matchem.insert(route, "/test/123", 321)

  route
  |> should.equal(
    matchem.root([
      Node(
        "/test",
        matchem.Static,
        None,
        dict.from_list([
          #("/abc/123", Node("/abc/123", matchem.Static, Some(123), dict.new())),
          #("/123", Node("/123", matchem.Static, Some(321), dict.new())),
        ]),
      ),
    ]),
  )
}
