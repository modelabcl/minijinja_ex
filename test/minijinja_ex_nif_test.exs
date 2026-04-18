defmodule MinijinjaEx.NIFTest do
  use ExUnit.Case

  alias MinijinjaEx.NIF

  describe "render_string basic tests" do
    test "renders simple template with variable" do
      assert NIF.render_string("Hello, {{ name }}!", %{"name" => "World"}) == "Hello, World!"
    end

    test "renders template with addition" do
      assert NIF.render_string("Sum: {{ a + b }}", %{"a" => 1, "b" => 2}) == "Sum: 3"
    end

    test "renders template with for loop" do
      assert NIF.render_string("{% for item in items %}{{ item }}{% endfor %}", %{
               "items" => [1, 2, 3]
             }) == "123"
    end

    test "renders template with basic types map" do
      result =
        NIF.render_string("{{ data }}", %{"data" => %{"a" => 42, "b" => 42.5, "c" => "blah"}})

      assert result =~ "42"
      assert result =~ "42.5"
      assert result =~ "blah"
    end

    test "renders template with boolean values" do
      assert NIF.render_string("{{ val }}", %{"val" => true}) == "true"
      assert NIF.render_string("{{ val }}", %{"val" => false}) == "false"
    end

    test "renders template with nil value" do
      assert NIF.render_string("{{ val }}", %{"val" => nil}) == "none"
    end

    test "renders template with list iteration" do
      result =
        NIF.render_string("{% for x in values %}{{ x }} {% endfor %}", %{"values" => [1, 2, 3]})

      assert result == "1 2 3 "
    end
  end

  describe "Environment NIF tests" do
    test "creates new environment" do
      env = NIF.env_new()
      assert is_reference(env)
    end

    test "adds and renders template" do
      env = NIF.env_new()
      :ok = NIF.env_add_template(env, "greeting", "Hello, {{ name }}!")
      assert NIF.env_render_template(env, "greeting", %{"name" => "World"}) == "Hello, World!"
    end

    test "renders template string via environment" do
      env = NIF.env_new()
      result = NIF.env_render_str(env, "Hello, {{ name }}!", %{"name" => "World"})
      assert result == "Hello, World!"
    end

    test "adds global variable" do
      env = NIF.env_new()
      :ok = NIF.env_add_global(env, "x", 23)
      result = NIF.env_render_str(env, "{{ x }}", %{})
      assert result == "23"
    end

    test "reloads environment" do
      env = NIF.env_new()
      :ok = NIF.env_add_template(env, "temp", "Hello")
      assert NIF.env_render_template(env, "temp", %{}) == "Hello"
      :ok = NIF.env_reload(env)
      assert {:error, _} = NIF.env_render_template(env, "temp", %{})
    end
  end

  describe "trim_blocks NIF tests" do
    test "trim_blocks disabled keeps newline after block" do
      env = NIF.env_new()
      :ok = NIF.env_set_trim_blocks(env, false)
      result = NIF.env_render_str(env, "{% if true %}\nfoo{% endif %}", %{})
      assert result == "\nfoo"
    end

    test "trim_blocks enabled removes newline after block" do
      env = NIF.env_new()
      :ok = NIF.env_set_trim_blocks(env, true)
      result = NIF.env_render_str(env, "{% if true %}\nfoo{% endif %}", %{})
      assert result == "foo"
    end
  end

  describe "lstrip_blocks NIF tests" do
    test "lstrip_blocks disabled keeps leading whitespace" do
      env = NIF.env_new()
      :ok = NIF.env_set_lstrip_blocks(env, false)
      result = NIF.env_render_str(env, "  {% if true %}\nfoo{% endif %}", %{})
      assert result == "  \nfoo"
    end

    test "lstrip_blocks enabled removes leading whitespace" do
      env = NIF.env_new()
      :ok = NIF.env_set_lstrip_blocks(env, true)
      result = NIF.env_render_str(env, "  {% if true %}\nfoo{% endif %}", %{})
      assert result == "\nfoo"
    end

    test "trim_blocks and lstrip_blocks combined" do
      env = NIF.env_new()
      :ok = NIF.env_set_trim_blocks(env, true)
      :ok = NIF.env_set_lstrip_blocks(env, true)
      result = NIF.env_render_str(env, "  {% if true %}\nfoo{% endif %}", %{})
      assert result == "foo"
    end
  end

  describe "keep_trailing_newline NIF tests" do
    test "keep_trailing_newline disabled removes trailing newline" do
      env = NIF.env_new()
      :ok = NIF.env_set_keep_trailing_newline(env, false)
      result = NIF.env_render_str(env, "foo\n", %{})
      assert result == "foo"
    end

    test "keep_trailing_newline enabled keeps trailing newline" do
      env = NIF.env_new()
      :ok = NIF.env_set_keep_trailing_newline(env, true)
      result = NIF.env_render_str(env, "foo\n", %{})
      assert result == "foo\n"
    end
  end

  describe "error handling NIF tests" do
    test "syntax error" do
      env = NIF.env_new()
      result = NIF.env_render_str(env, "{{ 1 + }}", %{})
      assert {:error, msg} = result
      assert msg =~ "unexpected"
    end

    test "undefined variable renders as empty" do
      result = NIF.render_string("{{ undefined_var }}", %{})
      assert result == ""
    end
  end

  describe "expression NIF tests" do
    test "range expression" do
      env = NIF.env_new()
      result = NIF.env_render_str(env, "{% for x in range(5) %}{{ x }}{% endfor %}", %{})
      assert result == "01234"
    end

    test "filter lower" do
      result = NIF.render_string("{{ 'HELLO'|lower }}", %{})
      assert result == "hello"
    end

    test "filter upper" do
      result = NIF.render_string("{{ 'hello'|upper }}", %{})
      assert result == "HELLO"
    end

    test "filter length" do
      result = NIF.render_string("{{ items|length }}", %{"items" => [1, 2, 3]})
      assert result == "3"
    end

    test "filter join" do
      result = NIF.render_string("{{ items|join(',') }}", %{"items" => [1, 2, 3]})
      assert result == "1,2,3"
    end

    test "filter sort" do
      result = NIF.render_string("{{ items|sort|join(',') }}", %{"items" => [3, 1, 2]})
      assert result == "1,2,3"
    end

    test "filter reverse" do
      result = NIF.render_string("{{ items|reverse|join(',') }}", %{"items" => [1, 2, 3]})
      assert result == "3,2,1"
    end

    test "filter first" do
      result = NIF.render_string("{{ items|first }}", %{"items" => [1, 2, 3]})
      assert result == "1"
    end

    test "filter last" do
      result = NIF.render_string("{{ items|last }}", %{"items" => [1, 2, 3]})
      assert result == "3"
    end

    test "filter default" do
      result = NIF.render_string("{{ val|default('fallback') }}", %{})
      assert result == "fallback"
    end
  end

  describe "nested data NIF tests" do
    test "access nested map value" do
      result =
        NIF.render_string("{{ data.nested.value }}", %{"data" => %{"nested" => %{"value" => 42}}})

      assert result == "42"
    end

    test "access list by index" do
      result = NIF.render_string("{{ items.1 }}", %{"items" => ["a", "b", "c"]})
      assert result == "b"
    end
  end

  describe "conditionals NIF tests" do
    test "if else statement" do
      result = NIF.render_string("{% if x > 5 %}big{% else %}small{% endif %}", %{"x" => 10})
      assert result == "big"
      result = NIF.render_string("{% if x > 5 %}big{% else %}small{% endif %}", %{"x" => 3})
      assert result == "small"
    end

    test "elif statement" do
      result =
        NIF.render_string("{% if x == 1 %}one{% elif x == 2 %}two{% else %}other{% endif %}", %{
          "x" => 1
        })

      assert result == "one"

      result =
        NIF.render_string("{% if x == 1 %}one{% elif x == 2 %}two{% else %}other{% endif %}", %{
          "x" => 2
        })

      assert result == "two"

      result =
        NIF.render_string("{% if x == 1 %}one{% elif x == 2 %}two{% else %}other{% endif %}", %{
          "x" => 3
        })

      assert result == "other"
    end
  end

  describe "set statement NIF tests" do
    test "set variable" do
      result = NIF.render_string("{% set x = 42 %}{{ x }}", %{})
      assert result == "42"
    end

    test "set with expression" do
      result = NIF.render_string("{% set x = 1 + 2 %}{{ x }}", %{})
      assert result == "3"
    end
  end

  describe "macro NIF tests" do
    test "simple macro" do
      result =
        NIF.render_string(
          """
          {% macro greet(name) %}Hello, {{ name }}!{% endmacro %}
          {{ greet('World') }}
          """,
          %{}
        )

      assert result =~ "Hello, World!"
    end
  end

  describe "whitespace control NIF tests" do
    test "lstrip_blocks with trim" do
      env = NIF.env_new()
      :ok = NIF.env_set_lstrip_blocks(env, true)
      :ok = NIF.env_set_trim_blocks(env, true)
      result = NIF.env_render_str(env, "  {% if true %}\nfoo{% endif %}", %{})
      assert result == "foo"
    end
  end

  describe "include NIF tests" do
    test "include statement (if templates registered)" do
      env = NIF.env_new()
      :ok = NIF.env_add_template(env, "base", "{% include 'child' %}")
      :ok = NIF.env_add_template(env, "child", "Hello from child")
      result = NIF.env_render_template(env, "base", %{})
      assert result == "Hello from child"
    end
  end
end
