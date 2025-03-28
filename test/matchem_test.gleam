import gleam/dict
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should

import matchem.{Node}

pub fn main() {
  gleeunit.main()
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

pub fn build_route_empty_fails_test() {
  matchem.build_route("", 123) |> should.be_error()
}

pub fn build_route_basic_test() {
  let route = matchem.build_route("/test/abc/123", 123)

  let last = Node("/123", matchem.Static, Some(123), dict.new())
  let next =
    Node("/abc", matchem.Static, None, dict.from_list([#("/123", last)]))
  let head =
    Node("/test", matchem.Static, None, dict.from_list([#("/abc", next)]))

  route
  |> should.equal(Ok(head))
}

pub fn build_route_param_test() {
  let route = matchem.build_route("/test/{abc}/123", 123)

  let last = Node("/123", matchem.Static, Some(123), dict.new())
  let next =
    Node("/abc", matchem.Param, None, dict.from_list([#("/123", last)]))
  let head =
    Node("/test", matchem.Static, None, dict.from_list([#("/abc", next)]))

  route
  |> should.equal(Ok(head))
}

pub fn build_route_param_missing_closing_brace_test() {
  let route = matchem.build_route("/test/{abc/123", 123)

  route
  |> should.equal(Error(Nil))
}
