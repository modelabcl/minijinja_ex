defmodule MinijinjaEx.APITest do
  use ExUnit.Case

  describe "new_env/1" do
    test "creates environment without options" do
      env = MinijinjaEx.new_env()
      assert %MinijinjaEx{reference: ref} = env
      assert is_reference(ref)
    end

    test "creates environment with options" do
      env =
        MinijinjaEx.new_env(trim_blocks: true, lstrip_blocks: true, keep_trailing_newline: true)

      {:ok, result} = MinijinjaEx.render_string(env, "  {% if true %}\nfoo{% endif %}", %{})
      assert result == "foo"
    end
  end

  describe "add_template/3" do
    test "adds template successfully" do
      env = MinijinjaEx.new_env()
      {:ok, env} = MinijinjaEx.add_template(env, "greeting", "Hello {{ name }}!")
      {:ok, result} = MinijinjaEx.render(env, "greeting", %{"name" => "World"})
      assert result == "Hello World!"
    end

    test "returns error for invalid template" do
      env = MinijinjaEx.new_env()

      {:error, %MinijinjaEx.SyntaxError{} = error} =
        MinijinjaEx.add_template(env, "bad", "{{ 1 + }}")

      assert error.message =~ "unexpected"
    end
  end

  describe "add_template!/3" do
    test "adds template and returns env" do
      env = MinijinjaEx.new_env()
      env = MinijinjaEx.add_template!(env, "greeting", "Hello!")
      assert %MinijinjaEx{} = env
    end

    test "raises on invalid template" do
      env = MinijinjaEx.new_env()

      assert_raise MinijinjaEx.SyntaxError, fn ->
        MinijinjaEx.add_template!(env, "bad", "{{ 1 + }}")
      end
    end
  end

  describe "render/3" do
    test "renders template by name" do
      env = MinijinjaEx.new_env()
      {:ok, env} = MinijinjaEx.add_template(env, "test", "{{ x }}")
      {:ok, result} = MinijinjaEx.render(env, "test", %{"x" => 42})
      assert result == "42"
    end

    test "returns error for missing template" do
      env = MinijinjaEx.new_env()
      {:error, %MinijinjaEx.TemplateNotFound{} = error} = MinijinjaEx.render(env, "missing", %{})
      assert error.message =~ "not found"
    end
  end

  describe "render!/3" do
    test "renders and returns string" do
      env = MinijinjaEx.new_env()
      env = MinijinjaEx.add_template!(env, "test", "{{ x }}")
      result = MinijinjaEx.render!(env, "test", %{"x" => 42})
      assert result == "42"
    end

    test "raises on missing template" do
      env = MinijinjaEx.new_env()

      assert_raise MinijinjaEx.TemplateNotFound, fn ->
        MinijinjaEx.render!(env, "missing", %{})
      end
    end
  end

  describe "render_string/2 (direct)" do
    test "renders template string directly" do
      {:ok, result} = MinijinjaEx.render_string("Hello {{ name }}!", %{"name" => "World"})
      assert result == "Hello World!"
    end

    test "returns error on syntax error" do
      {:error, %MinijinjaEx.SyntaxError{} = error} = MinijinjaEx.render_string("{{ 1 + }}", %{})
      assert error.message =~ "unexpected"
    end
  end

  describe "render_string!/2" do
    test "renders and returns result" do
      result = MinijinjaEx.render_string!("Hello {{ name }}!", %{"name" => "World"})
      assert result == "Hello World!"
    end

    test "raises on error" do
      assert_raise MinijinjaEx.SyntaxError, fn ->
        MinijinjaEx.render_string!("{{ 1 + }}", %{})
      end
    end
  end

  describe "render_string/3 (with env)" do
    test "renders using environment settings" do
      env = MinijinjaEx.new_env(trim_blocks: true)
      {:ok, result} = MinijinjaEx.render_string(env, "{% if true %}\nfoo{% endif %}", %{})
      assert result == "foo"
    end
  end

  describe "pipe-friendly operations" do
    test "can chain operations" do
      env = MinijinjaEx.new_env()

      env =
        env
        |> MinijinjaEx.add_template!("greeting", "Hello {{ name }}!")
        |> MinijinjaEx.add_global!("site", "My Site")

      {:ok, result} = MinijinjaEx.render(env, "greeting", %{"name" => "World"})
      assert result == "Hello World!"
    end

    test "can chain configuration" do
      env = MinijinjaEx.new_env()

      env =
        env
        |> MinijinjaEx.set_trim_blocks(true)
        |> MinijinjaEx.set_lstrip_blocks(true)

      {:ok, result} = MinijinjaEx.render_string(env, "  {% if true %}\nfoo{% endif %}", %{})
      assert result == "foo"
    end
  end

  describe "set_trim_blocks/2" do
    test "enables trim blocks" do
      env = MinijinjaEx.new_env()
      env = MinijinjaEx.set_trim_blocks(env, true)
      {:ok, result} = MinijinjaEx.render_string(env, "{% if true %}\nfoo{% endif %}", %{})
      assert result == "foo"
    end

    test "disables trim blocks" do
      env = MinijinjaEx.new_env(trim_blocks: true)
      env = MinijinjaEx.set_trim_blocks(env, false)
      {:ok, result} = MinijinjaEx.render_string(env, "{% if true %}\nfoo{% endif %}", %{})
      assert result == "\nfoo"
    end
  end

  describe "set_lstrip_blocks/2" do
    test "enables lstrip blocks" do
      env = MinijinjaEx.new_env()
      env = MinijinjaEx.set_lstrip_blocks(env, true)
      {:ok, result} = MinijinjaEx.render_string(env, "  {% if true %}\nfoo{% endif %}", %{})
      assert result == "\nfoo"
    end
  end

  describe "set_keep_trailing_newline/2" do
    test "keeps trailing newline" do
      env = MinijinjaEx.new_env()
      env = MinijinjaEx.set_keep_trailing_newline(env, true)
      {:ok, result} = MinijinjaEx.render_string(env, "foo\n", %{})
      assert result == "foo\n"
    end

    test "removes trailing newline" do
      env = MinijinjaEx.new_env(keep_trailing_newline: true)
      env = MinijinjaEx.set_keep_trailing_newline(env, false)
      {:ok, result} = MinijinjaEx.render_string(env, "foo\n", %{})
      assert result == "foo"
    end
  end

  describe "add_global/3" do
    test "adds global variable" do
      env = MinijinjaEx.new_env()
      {:ok, env} = MinijinjaEx.add_global(env, "version", "1.0")
      {:ok, result} = MinijinjaEx.render_string(env, "v{{ version }}", %{})
      assert result == "v1.0"
    end
  end

  describe "add_global!/3" do
    test "adds global and returns env" do
      env = MinijinjaEx.new_env()
      env = MinijinjaEx.add_global!(env, "x", 42)
      {:ok, result} = MinijinjaEx.render_string(env, "{{ x }}", %{})
      assert result == "42"
    end
  end

  describe "reload/1" do
    test "clears templates" do
      env = MinijinjaEx.new_env()
      env = MinijinjaEx.add_template!(env, "temp", "Hello")
      {:ok, result} = MinijinjaEx.render(env, "temp", %{})
      assert result == "Hello"

      {:ok, env} = MinijinjaEx.reload(env)
      {:error, _} = MinijinjaEx.render(env, "temp", %{})
    end
  end

  describe "include templates" do
    test "include works with registered templates" do
      env = MinijinjaEx.new_env()
      env = MinijinjaEx.add_template!(env, "base", "{% include 'child' %}")
      env = MinijinjaEx.add_template!(env, "child", "Hello from child")
      {:ok, result} = MinijinjaEx.render(env, "base", %{})
      assert result == "Hello from child"
    end
  end

  describe "filters" do
    test "lower filter" do
      {:ok, result} = MinijinjaEx.render_string("{{ 'HELLO'|lower }}", %{})
      assert result == "hello"
    end

    test "upper filter" do
      {:ok, result} = MinijinjaEx.render_string("{{ 'hello'|upper }}", %{})
      assert result == "HELLO"
    end

    test "length filter" do
      {:ok, result} = MinijinjaEx.render_string("{{ items|length }}", %{"items" => [1, 2, 3]})
      assert result == "3"
    end

    test "join filter" do
      {:ok, result} = MinijinjaEx.render_string("{{ items|join(',') }}", %{"items" => [1, 2, 3]})
      assert result == "1,2,3"
    end

    test "sort filter" do
      {:ok, result} =
        MinijinjaEx.render_string("{{ items|sort|join(',') }}", %{"items" => [3, 1, 2]})

      assert result == "1,2,3"
    end

    test "reverse filter" do
      {:ok, result} =
        MinijinjaEx.render_string("{{ items|reverse|join(',') }}", %{"items" => [1, 2, 3]})

      assert result == "3,2,1"
    end

    test "default filter" do
      {:ok, result} = MinijinjaEx.render_string("{{ val|default('fallback') }}", %{})
      assert result == "fallback"
    end
  end

  describe "conditionals" do
    test "if/else" do
      {:ok, result} =
        MinijinjaEx.render_string("{% if x > 5 %}big{% else %}small{% endif %}", %{"x" => 10})

      assert result == "big"

      {:ok, result} =
        MinijinjaEx.render_string("{% if x > 5 %}big{% else %}small{% endif %}", %{"x" => 3})

      assert result == "small"
    end

    test "elif" do
      {:ok, result} =
        MinijinjaEx.render_string(
          "{% if x == 1 %}one{% elif x == 2 %}two{% else %}other{% endif %}",
          %{"x" => 1}
        )

      assert result == "one"

      {:ok, result} =
        MinijinjaEx.render_string(
          "{% if x == 1 %}one{% elif x == 2 %}two{% else %}other{% endif %}",
          %{"x" => 2}
        )

      assert result == "two"

      {:ok, result} =
        MinijinjaEx.render_string(
          "{% if x == 1 %}one{% elif x == 2 %}two{% else %}other{% endif %}",
          %{"x" => 3}
        )

      assert result == "other"
    end
  end

  describe "loops" do
    test "for loop" do
      {:ok, result} =
        MinijinjaEx.render_string("{% for x in items %}{{ x }}{% endfor %}", %{
          "items" => [1, 2, 3]
        })

      assert result == "123"
    end

    test "range" do
      {:ok, result} = MinijinjaEx.render_string("{% for x in range(5) %}{{ x }}{% endfor %}", %{})
      assert result == "01234"
    end
  end

  describe "set statements" do
    test "set variable" do
      {:ok, result} = MinijinjaEx.render_string("{% set x = 42 %}{{ x }}", %{})
      assert result == "42"
    end

    test "set with expression" do
      {:ok, result} = MinijinjaEx.render_string("{% set x = 1 + 2 %}{{ x }}", %{})
      assert result == "3"
    end
  end

  describe "macros" do
    test "simple macro" do
      {:ok, result} =
        MinijinjaEx.render_string(
          "{% macro greet(name) %}Hello {{ name }}!{% endmacro %}{{ greet('World') }}",
          %{}
        )

      assert result =~ "Hello World!"
    end
  end

  describe "nested data" do
    test "nested map access" do
      {:ok, result} =
        MinijinjaEx.render_string("{{ data.nested.value }}", %{
          "data" => %{"nested" => %{"value" => 42}}
        })

      assert result == "42"
    end

    test "list index access" do
      {:ok, result} = MinijinjaEx.render_string("{{ items.1 }}", %{"items" => ["a", "b", "c"]})
      assert result == "b"
    end
  end
end
