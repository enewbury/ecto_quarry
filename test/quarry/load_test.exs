defmodule Quarry.LoadTest do
  use ExUnit.Case
  doctest Quarry.Load
  alias Quarry.Load

  import Ecto.Query
  alias Quarry.{Comment, Post, Load}

  setup do
    %{base: {from(p in Post, as: :post), []}}
  end

  test "can preload belongs_to", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        preload: [author: a]
      )

    load = [:author]
    {actual, []} = Load.build(base, load)
    assert inspect(actual) == inspect(expected)
  end

  test "can preload nested belongs_to", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        join: u in assoc(a, :user),
        as: :post_author_user,
        preload: [author: {a, user: u}]
      )

    load = [author: :user]
    {actual, []} = Load.build(base, load)
    assert inspect(actual) == inspect(expected)
  end

  test "can preload has_many", %{base: base} do
    comments_query = from(c in Comment, as: :post_comment)

    expected =
      from(
        p in Post,
        as: :post,
        preload: [comments: ^comments_query]
      )

    load = [:comments]
    {actual, []} = Load.build(base, load)
    assert inspect(actual) == inspect(expected)
  end

  test "can preload belongs_to and has_many with nested belongs_to", %{base: base} do
    comments_query =
      from(
        c in Comment,
        as: :post_comment,
        join: u in assoc(c, :user),
        as: :post_comment_user,
        preload: [user: u]
      )

    expected =
      from(
        p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        preload: [author: a],
        preload: [comments: ^comments_query]
      )

    load = [:author, comments: :user]
    {actual, []} = Load.build(base, load)
    assert inspect(actual) == inspect(expected)
  end

  test "can add filter to nested load", %{base: base} do
    comments_query =
      from(c in Comment,
        as: :post_comment,
        where: as(:post_comment).body == ^"comment"
      )

    expected =
      from(
        p in Post,
        as: :post,
        preload: [comments: ^comments_query]
      )

    load = [comments: [filter: %{body: "comment"}]]
    {actual, []} = Load.build(base, load)
    assert inspect(actual) == inspect(expected)
  end

  test "can fully parameratize has_many preload", %{base: base} do
    comments_query =
      from(c in Comment,
        as: :post_comment,
        where: as(:post_comment).body == ^"comment",
        limit: ^1,
        offset: ^1
      )

    expected =
      from(
        p in Post,
        as: :post,
        preload: [comments: ^comments_query]
      )

    load = [comments: [filter: %{body: "comment"}, load: [], limit: 1, offset: 1]]
    {actual, []} = Load.build(base, load)
    assert inspect(actual) == inspect(expected)
  end

  test "returns error for missing top level field", %{base: base} do
    {_, [error]} = Load.build(base, [:fake])
    assert %{type: :load, path: [:fake], message: _} = error
  end

  test "returns error for missing nested belongs_to field", %{base: base} do
    {_, [error]} = Load.build(base, author: :fake)
    assert %{type: :load, path: [:author, :fake], message: _} = error
  end

  test "returns error for missing nested has_many field", %{base: base} do
    {_, [error]} = Load.build(base, comments: :fake)
    assert %{type: :load, path: [:comments, :fake], message: _} = error
  end

  test "returns error for missing filter field on nested selection", %{base: base} do
    {_, [error]} = Load.build(base, comments: [filter: %{fake: "hi"}])
    assert %{type: :filter, path: [:fake], load_path: [:comments], message: _} = error
  end

  test "returns error for missing sort field on nested selection", %{base: base} do
    {_, [error]} = Load.build(base, comments: [sort: [:fake]])
    assert %{type: :sort, path: [:fake], load_path: [:comments], message: _} = error
  end

  test "returns error with correct load_path for multiple subquery fields" do
    base = from(a in Quarry.Author, as: :author)
    assert {_, [error]} = Load.build({base, []}, posts: [comments: :fake])
    assert %{type: :load, path: [:posts, :comments, :fake], message: _} = error
  end

  test "returns error with correct load_path for multiple subquery filter fields" do
    base = from(a in Quarry.Author, as: :author)
    assert {_, [error]} = Load.build({base, []}, posts: [comments: [filter: %{fake: "hi"}]])
    assert %{type: :filter, path: [:fake], load_path: [:posts, :comments], message: _} = error
  end
end
