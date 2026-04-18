defmodule MinijinjaEx.ReadmeTest do
  use ExUnit.Case

  describe "README: Direct Rendering" do
    test "render_string example" do
      {:ok, result} = MinijinjaEx.render_string("Hello {{ name }}!", %{"name" => "World"})
      assert result == "Hello World!"
    end

    test "render_string! example" do
      result = MinijinjaEx.render_string!("{{ x }}", %{"x" => 42})
      assert result == "42"
    end
  end

  describe "README: Environment-Based Rendering" do
    test "add_template and render example" do
      env = MinijinjaEx.new_env()
      {:ok, env} = MinijinjaEx.add_template(env, "greeting", "Hello {{ name }}!")
      {:ok, env} = MinijinjaEx.add_template(env, "footer", "Copyright {{ year }}")
      {:ok, result} = MinijinjaEx.render(env, "greeting", %{"name" => "Alice"})
      assert result == "Hello Alice!"
    end
  end

  describe "README: Configuration Options" do
    test "new_env with options" do
      env =
        MinijinjaEx.new_env(trim_blocks: true, lstrip_blocks: true, keep_trailing_newline: true)

      {:ok, result} = MinijinjaEx.render_string(env, "  {% if true %}\nfoo{% endif %}", %{})
      assert result == "foo"
    end

    test "trim_blocks removes first newline after block" do
      env = MinijinjaEx.new_env(trim_blocks: true)
      {:ok, result} = MinijinjaEx.render_string(env, "{% if true %}\nfoo{% endif %}", %{})
      assert result == "foo"
    end

    test "lstrip_blocks removes leading whitespace" do
      env = MinijinjaEx.new_env(lstrip_blocks: true)
      {:ok, result} = MinijinjaEx.render_string(env, "  {% if true %}\nfoo{% endif %}", %{})
      assert result == "\nfoo"
    end

    test "keep_trailing_newline preserves trailing newline" do
      env = MinijinjaEx.new_env(keep_trailing_newline: true)
      {:ok, result} = MinijinjaEx.render_string(env, "foo\n", %{})
      assert result == "foo\n"
    end
  end

  describe "README: Pipe-Friendly API" do
    test "chaining operations" do
      env =
        MinijinjaEx.new_env()
        |> MinijinjaEx.add_template!("greeting", "Hello {{ name }}!")
        |> MinijinjaEx.add_template!("footer", "Copyright {{ year }}")
        |> MinijinjaEx.add_global!("site_name", "MyApp")
        |> MinijinjaEx.set_trim_blocks(true)

      {:ok, result} = MinijinjaEx.render(env, "greeting", %{"name" => "World"})
      assert result == "Hello World!"
    end
  end

  describe "README: Global Variables" do
    test "globals are available in all templates" do
      env =
        MinijinjaEx.new_env()
        |> MinijinjaEx.add_global!("version", "1.0.0")
        |> MinijinjaEx.add_global!("site", "MyApp")

      {:ok, result} = MinijinjaEx.render_string(env, "{{ site }} v{{ version }}", %{})
      assert result == "MyApp v1.0.0"
    end
  end

  describe "README: Template Includes" do
    test "include statement" do
      env =
        MinijinjaEx.new_env()
        |> MinijinjaEx.add_template!("base", "Header\n{% include 'content' %}\nFooter")
        |> MinijinjaEx.add_template!("content", "This is the content")

      {:ok, result} = MinijinjaEx.render(env, "base", %{})
      assert result == "Header\nThis is the content\nFooter"
    end
  end

  describe "README: Variables" do
    test "simple variable" do
      {:ok, result} = MinijinjaEx.render_string("{{ variable }}", %{"variable" => "test"})
      assert result == "test"
    end

    test "object property" do
      {:ok, result} =
        MinijinjaEx.render_string("{{ object.property }}", %{"object" => %{"property" => "value"}})

      assert result == "value"
    end

    test "list index" do
      {:ok, result} = MinijinjaEx.render_string("{{ items.0 }}", %{"items" => ["a", "b", "c"]})
      assert result == "a"
    end
  end

  describe "README: Conditionals" do
    test "if statement" do
      {:ok, result} =
        MinijinjaEx.render_string("{% if user.admin %}Admin{% endif %}", %{
          "user" => %{"admin" => true}
        })

      assert result == "Admin"
    end

    test "if/elif/else" do
      {:ok, result} =
        MinijinjaEx.render_string(
          "{% if user.admin %}Admin{% elif user.mod %}Mod{% else %}User{% endif %}",
          %{"user" => %{"admin" => true}}
        )

      assert result == "Admin"

      {:ok, result} =
        MinijinjaEx.render_string(
          "{% if user.admin %}Admin{% elif user.mod %}Mod{% else %}User{% endif %}",
          %{"user" => %{"mod" => true}}
        )

      assert result == "Mod"

      {:ok, result} =
        MinijinjaEx.render_string(
          "{% if user.admin %}Admin{% elif user.mod %}Mod{% else %}User{% endif %}",
          %{"user" => %{}}
        )

      assert result == "User"
    end
  end

  describe "README: Loops" do
    test "for loop over items" do
      {:ok, result} =
        MinijinjaEx.render_string("{% for item in items %}{{ item }}{% endfor %}", %{
          "items" => [1, 2, 3]
        })

      assert result == "123"
    end

    test "for loop with range" do
      {:ok, result} = MinijinjaEx.render_string("{% for i in range(5) %}{{ i }}{% endfor %}", %{})
      assert result == "01234"
    end
  end

  describe "README: Set Statements" do
    test "set variable" do
      {:ok, result} = MinijinjaEx.render_string("{% set counter = 0 %}{{ counter }}", %{})
      assert result == "0"
    end

    test "set with expression" do
      {:ok, result} =
        MinijinjaEx.render_string("{% set total = price * quantity %}{{ total }}", %{
          "price" => 10,
          "quantity" => 5
        })

      assert result == "50"
    end
  end

  describe "README: Macros" do
    test "simple macro" do
      {:ok, result} =
        MinijinjaEx.render_string(
          "{% macro render_item(name, price) %}{{ name }}: {{ price }}{% endmacro %}{{ render_item(\"Widget\", 99) }}",
          %{}
        )

      assert result == "Widget: 99"
    end
  end

  describe "README: Filters" do
    test "upper filter" do
      {:ok, result} = MinijinjaEx.render_string("{{ name|upper }}", %{"name" => "hello"})
      assert result == "HELLO"
    end

    test "lower filter" do
      {:ok, result} = MinijinjaEx.render_string("{{ name|lower }}", %{"name" => "HELLO"})
      assert result == "hello"
    end

    test "length filter" do
      {:ok, result} = MinijinjaEx.render_string("{{ items|length }}", %{"items" => [1, 2, 3]})
      assert result == "3"
    end

    test "join filter" do
      {:ok, result} =
        MinijinjaEx.render_string("{{ items|join(',') }}", %{"items" => ["a", "b", "c"]})

      assert result == "a,b,c"
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

    test "first filter" do
      {:ok, result} =
        MinijinjaEx.render_string("{{ items|first }}", %{"items" => ["a", "b", "c"]})

      assert result == "a"
    end

    test "last filter" do
      {:ok, result} = MinijinjaEx.render_string("{{ items|last }}", %{"items" => ["a", "b", "c"]})
      assert result == "c"
    end

    test "default filter" do
      {:ok, result} = MinijinjaEx.render_string("{{ value|default('none') }}", %{})
      assert result == "none"
    end
  end

  describe "README: Error Handling" do
    test "SyntaxError on invalid syntax" do
      {:error, %MinijinjaEx.SyntaxError{} = error} = MinijinjaEx.render_string("{{ 1 + }}", %{})
      assert error.message =~ "unexpected"
    end

    test "TemplateNotFound on missing template" do
      env = MinijinjaEx.new_env()
      {:error, %MinijinjaEx.TemplateNotFound{} = error} = MinijinjaEx.render(env, "foo", %{})
      assert error.message =~ "not found"
    end

    test "UnknownFilter on unknown filter" do
      {:error, %MinijinjaEx.UnknownFilter{} = error} =
        MinijinjaEx.render_string("{{ x|bar }}", %{"x" => 1})

      assert error.message =~ "unknown filter"
    end

    test "render_string! raises SyntaxError" do
      assert_raise MinijinjaEx.SyntaxError, fn ->
        MinijinjaEx.render_string!("{{ 1 + }}", %{})
      end
    end

    test "render! raises TemplateNotFound" do
      env = MinijinjaEx.new_env()

      assert_raise MinijinjaEx.TemplateNotFound, fn ->
        MinijinjaEx.render!(env, "missing_template", %{})
      end
    end

    test "undefined variable renders as empty" do
      {:ok, result} = MinijinjaEx.render_string("{{ undefined_var }}", %{})
      assert result == ""
    end
  end

  describe "README: reload" do
    test "reload clears templates" do
      env = MinijinjaEx.new_env()
      env = MinijinjaEx.add_template!(env, "temp", "Hello")
      {:ok, "Hello"} = MinijinjaEx.render(env, "temp", %{})
      {:ok, env} = MinijinjaEx.reload(env)
      {:error, _} = MinijinjaEx.render(env, "temp", %{})
    end
  end
end
