# MinijinjaEx

Elixir wrapper for [minijinja](https://github.com/mitsuhiko/minijinja), a minimal template engine written in Rust by Armin Ronacher.

Licensed under Apache License 2.0.

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:minijinja_ex, "~> 0.1"}
  ]
end
```

Precompiled binaries are available for:
- macOS arm64 (Apple Silicon)
- Linux arm64 (gnu)
- Linux x86_64 (gnu and musl)

Intel macOS users need to build from source. No Rust installation required for supported platforms.

### Force Build from Source

If you need to build from source (e.g., unsupported platform):

```bash
export MINIJINJA_EX_BUILD=1
mix deps.compile minijinja_ex
```

## Usage

### Direct Rendering

Render a template string without creating an environment:

```elixir
{:ok, result} = MinijinjaEx.render_string("Hello {{ name }}!", %{"name" => "World"})
# => "Hello World!"

# Raise on error
result = MinijinjaEx.render_string!("{{ x }}", %{"x" => 42})
# => "42"
```

### Environment-Based Rendering

Create an environment to manage multiple templates:

```elixir
env = MinijinjaEx.new_env()

{:ok, env} = MinijinjaEx.add_template(env, "greeting", "Hello {{ name }}!")
{:ok, env} = MinijinjaEx.add_template(env, "footer", "Copyright {{ year }}")

{:ok, result} = MinijinjaEx.render(env, "greeting", %{"name" => "Alice"})
# => "Hello Alice!"
```

### Configuration Options

```elixir
env = MinijinjaEx.new_env(
  trim_blocks: true,        # Remove first newline after block tags
  lstrip_blocks: true,      # Remove leading whitespace before block tags
  keep_trailing_newline: true
)
```

### Pipe-Friendly API

```elixir
env = MinijinjaEx.new_env()
|> MinijinjaEx.add_template!("greeting", "Hello {{ name }}!")
|> MinijinjaEx.add_template!("footer", "Copyright {{ year }}")
|> MinijinjaEx.add_global!("site_name", "MyApp")
|> MinijinjaEx.set_trim_blocks(true)
```

### Global Variables

Add variables available in all templates:

```elixir
env = MinijinjaEx.new_env()
|> MinijinjaEx.add_global!("version", "1.0.0")
|> MinijinjaEx.add_global!("site", "MyApp")

{:ok, result} = MinijinjaEx.render_string(env, "{{ site }} v{{ version }}", %{})
# => "MyApp v1.0.0"
```

### Template Includes

```elixir
env = MinijinjaEx.new_env()
|> MinijinjaEx.add_template!("base", "Header\n{% include 'content' %}\nFooter")
|> MinijinjaEx.add_template!("content", "This is the content")

{:ok, result} = MinijinjaEx.render(env, "base", %{})
# => "Header\nThis is the content\nFooter"
```

## Template Syntax

Minijinja supports Jinja2-like syntax:

### Variables

```
{{ variable }}
{{ object.property }}
{{ items.0 }}
```

### Conditionals

```
{% if user.admin %}
  Admin panel
{% elif user.mod %}
  Moderator panel
{% else %}
  User panel
{% endif %}
```

### Loops

```
{% for item in items %}
  {{ item.name }}
{% endfor %}

{% for i in range(5) %}
  {{ i }}
{% endfor %}
```

### Set Statements

```
{% set counter = 0 %}
{% set total = price * quantity %}
```

### Macros

```
{% macro render_item(name, price) %}
  <div>{{ name }}: {{ price }}</div>
{% endmacro %}

{{ render_item("Widget", 99) }}
```

### Filters

```
{{ name|upper }}
{{ name|lower }}
{{ items|length }}
{{ items|join(',') }}
{{ items|sort }}
{{ items|reverse }}
{{ items|first }}
{{ items|last }}
{{ value|default('none') }}
```

## Error Handling

The API returns structured errors:

```elixir
{:error, %MinijinjaEx.SyntaxError{message: "syntax error: ..."}}
{:error, %MinijinjaEx.TemplateNotFound{message: "template 'foo' not found"}}
{:error, %MinijinjaEx.UnknownFilter{message: "unknown filter: 'bar'"}}
{:error, %MinijinjaEx.RenderError{message: "..."}}
```

Bang versions raise exceptions:

```elixir
MinijinjaEx.render_string!("{{ 1 + }}", %{})
# => raises MinijinjaEx.SyntaxError

MinijinjaEx.render!(env, "missing_template", %{})
# => raises MinijinjaEx.TemplateNotFound
```

Undefined variables render as empty strings (not errors):

```elixir
{:ok, ""} = MinijinjaEx.render_string("{{ undefined_var }}", %{})
```

## API Reference

### Environment

| Function | Description |
|----------|-------------|
| `new_env(opts)` | Create new environment with optional config |
| `add_template(env, name, source)` | Add template, returns `{:ok, env}` or `{:error, error}` |
| `add_template!(env, name, source)` | Add template, raises on error |
| `render(env, name, context)` | Render template by name |
| `render!(env, name, context)` | Render template, raises on error |
| `reload(env)` | Clear all templates |

### Direct Rendering

| Function | Description |
|----------|-------------|
| `render_string(template, context)` | Render string directly |
| `render_string!(template, context)` | Render string, raises on error |
| `render_string(env, template, context)` | Render string using env settings |

### Configuration

| Function | Description |
|----------|-------------|
| `set_trim_blocks(env, bool)` | Toggle trim_blocks |
| `set_lstrip_blocks(env, bool)` | Toggle lstrip_blocks |
| `set_keep_trailing_newline(env, bool)` | Toggle keep_trailing_newline |
| `add_global(env, name, value)` | Add global variable |

## License

Apache License 2.0

This project is a wrapper for minijinja by Armin Ronacher, also licensed under Apache 2.0.