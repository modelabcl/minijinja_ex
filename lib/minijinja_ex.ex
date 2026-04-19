defmodule MinijinjaEx do
  @moduledoc """
  Idiomatic Elixir wrapper for minijinja template engine.

  ## Features

  - Template rendering with context
  - Environment-based template management
  - Pipe-friendly API
  - Structured error handling
  - Configuration options (trim_blocks, lstrip_blocks, keep_trailing_newline)

  ## Quick Start

      # Direct rendering
      {:ok, result} = MinijinjaEx.render_string("Hello {{ name }}!", %{"name" => "World"})

      # Environment-based
      env = MinijinjaEx.new_env(trim_blocks: true)
      env = MinijinjaEx.add_template!(env, "greeting", "Hello {{ name }}!")
      {:ok, result} = MinijinjaEx.render(env, "greeting", %{"name" => "World"})

  """

  alias MinijinjaEx.NIF
  alias MinijinjaEx.Error
  alias MinijinjaEx.SyntaxError
  alias MinijinjaEx.TemplateNotFound
  alias MinijinjaEx.UnknownFilter
  alias MinijinjaEx.RenderError

  defstruct [:reference]

  @type env :: %__MODULE__{reference: reference()}
  @type render_result :: {:ok, String.t()} | {:error, Error.t()}
  @type template_result :: {:ok, env()} | {:error, Error.t()}

  @doc """
  Creates a new environment with optional configuration.

  ## Options

    - `:trim_blocks` - When true, removes first newline after block tags
    - `:lstrip_blocks` - When true, removes leading whitespace before block tags
    - `:keep_trailing_newline` - When true, keeps trailing newline in output

  ## Examples

      iex> env = MinijinjaEx.new_env()
      iex> %MinijinjaEx{} = env

      iex> env = MinijinjaEx.new_env(trim_blocks: true, lstrip_blocks: true)
      iex> %MinijinjaEx{} = env

  """
  @spec new_env(keyword()) :: env()
  def new_env(opts \\ []) do
    env = %__MODULE__{reference: NIF.env_new()}

    env
    |> maybe_set_option(:trim_blocks, opts)
    |> maybe_set_option(:lstrip_blocks, opts)
    |> maybe_set_option(:keep_trailing_newline, opts)
  end

  defp maybe_set_option(env, key, opts) do
    case Keyword.get(opts, key) do
      nil -> env
      value -> apply_setter(key, env, value)
    end
  end

  defp apply_setter(:trim_blocks, env, value), do: set_trim_blocks(env, value)
  defp apply_setter(:lstrip_blocks, env, value), do: set_lstrip_blocks(env, value)
  defp apply_setter(:keep_trailing_newline, env, value), do: set_keep_trailing_newline(env, value)

  @doc """
  Adds a template to the environment.

  ## Examples

      iex> env = MinijinjaEx.new_env()
      iex> {:ok, env} = MinijinjaEx.add_template(env, "greeting", "Hello {{ name }}")
      iex> {:ok, "Hello World"} = MinijinjaEx.render(env, "greeting", %{"name" => "World"})

  """
  @spec add_template(env(), String.t(), String.t()) :: {:ok, env()} | {:error, Error.t()}
  def add_template(%__MODULE__{reference: ref} = env, name, source) do
    case NIF.env_add_template(ref, name, source) do
      :ok -> {:ok, env}
      {:error, msg} -> {:error, parse_error(msg)}
    end
  end

  @doc """
  Adds a template to the environment, raising on error.

  ## Examples

      iex> env = MinijinjaEx.new_env()
      iex> env = MinijinjaEx.add_template!(env, "greeting", "Hello")
      iex> {:ok, "Hello"} = MinijinjaEx.render(env, "greeting", %{})

  """
  @spec add_template!(env(), String.t(), String.t()) :: env()
  def add_template!(env, name, source) do
    case add_template(env, name, source) do
      {:ok, env} -> env
      {:error, error} -> raise error
    end
  end

  @doc """
  Renders a template by name.

  ## Examples

      iex> env = MinijinjaEx.new_env()
      iex> env = MinijinjaEx.add_template!(env, "test", "{{ x }}")
      iex> {:ok, "42"} = MinijinjaEx.render(env, "test", %{"x" => 42})

      iex> env = MinijinjaEx.new_env()
      iex> env = MinijinjaEx.add_template!(env, "test", "{{ x }}")
      iex> "42" = MinijinjaEx.render!(env, "test", %{"x" => 42})

  """
  @spec render(env(), String.t(), map()) :: render_result()
  def render(%__MODULE__{reference: ref} = _env, name, context) do
    case NIF.env_render_template(ref, name, context) do
      result when is_binary(result) -> {:ok, result}
      {:error, msg} -> {:error, parse_error(msg)}
    end
  end

  @doc """
  Renders a template by name, raising on error.
  """
  @spec render!(env(), String.t(), map()) :: String.t()
  def render!(env, name, context) do
    case render(env, name, context) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Renders a template string directly.

  ## Examples

      iex> {:ok, "Hello World!"} = MinijinjaEx.render_string("Hello {{ name }}!", %{"name" => "World"})

      iex> "Hello World!" = MinijinjaEx.render_string!("Hello {{ name }}!", %{"name" => "World"})

  """
  @spec render_string(String.t(), map()) :: render_result()
  def render_string(template, context) do
    case NIF.render_string(template, context) do
      result when is_binary(result) -> {:ok, result}
      {:error, msg} -> {:error, parse_error(msg)}
    end
  end

  @doc """
  Renders a template string directly, raising on error.
  """
  @spec render_string!(String.t(), map()) :: String.t()
  def render_string!(template, context) do
    case render_string(template, context) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Renders a template string using the environment settings.

  ## Examples

      iex> env = MinijinjaEx.new_env()
      iex> {:ok, "Hello World!"} = MinijinjaEx.render_string(env, "Hello {{ name }}!", %{"name" => "World"})

  """
  @spec render_string(env(), String.t(), map()) :: render_result()
  def render_string(%__MODULE__{reference: ref} = _env, template, context) do
    case NIF.env_render_str(ref, template, context) do
      result when is_binary(result) -> {:ok, result}
      {:error, msg} -> {:error, parse_error(msg)}
    end
  end

  @doc """
  Renders a template string using environment settings, raising on error.
  """
  @spec render_string!(env(), String.t(), map()) :: String.t()
  def render_string!(env, template, context) do
    case render_string(env, template, context) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Sets the trim_blocks option.

  When enabled, the first newline after a block tag is removed.

  """
  @spec set_trim_blocks(env(), boolean()) :: env()
  def set_trim_blocks(%__MODULE__{reference: ref} = env, value) do
    NIF.env_set_trim_blocks(ref, value)
    env
  end

  @doc """
  Sets the lstrip_blocks option.

  When enabled, leading whitespace before a block tag is removed.

  """
  @spec set_lstrip_blocks(env(), boolean()) :: env()
  def set_lstrip_blocks(%__MODULE__{reference: ref} = env, value) do
    NIF.env_set_lstrip_blocks(ref, value)
    env
  end

  @doc """
  Sets the keep_trailing_newline option.

  When enabled, trailing newlines in templates are preserved in the output.

  """
  @spec set_keep_trailing_newline(env(), boolean()) :: env()
  def set_keep_trailing_newline(%__MODULE__{reference: ref} = env, value) do
    NIF.env_set_keep_trailing_newline(ref, value)
    env
  end

  @doc """
  Reloads the environment, clearing all templates.

  ## Examples

      iex> env = MinijinjaEx.new_env()
      iex> env = MinijinjaEx.add_template!(env, "temp", "Hello")
      iex> {:ok, "Hello"} = MinijinjaEx.render(env, "temp", %{})
      iex> {:ok, env} = MinijinjaEx.reload(env)
      iex> {:error, _} = MinijinjaEx.render(env, "temp", %{})

  """
  @spec reload(env()) :: {:ok, env()}
  def reload(%__MODULE__{} = env) do
    NIF.env_reload(env.reference)
    {:ok, env}
  end

  @doc """
  Adds a global variable to the environment.

  ## Examples

      iex> env = MinijinjaEx.new_env()
      iex> {:ok, env} = MinijinjaEx.add_global(env, "version", "1.0")
      iex> {:ok, "v1.0"} = MinijinjaEx.render_string(env, "v{{ version }}", %{})

      iex> env = MinijinjaEx.new_env()
      iex> env = MinijinjaEx.add_global!(env, "x", 42)
      iex> {:ok, "42"} = MinijinjaEx.render_string(env, "{{ x }}", %{})

  """
  @spec add_global(env(), String.t(), term()) :: {:ok, env()} | {:error, Error.t()}
  def add_global(%__MODULE__{reference: ref} = env, name, value) do
    case NIF.env_add_global(ref, name, value) do
      :ok -> {:ok, env}
      {:error, msg} -> {:error, parse_error(msg)}
    end
  end

  @doc """
  Adds a global variable to the environment, raising on error.
  """
  @spec add_global!(env(), String.t(), term()) :: env()
  def add_global!(env, name, value) do
    case add_global(env, name, value) do
      {:ok, env} -> env
      {:error, error} -> raise error
    end
  end

  defp parse_error(msg) when is_binary(msg) do
    cond do
      String.contains?(msg, "syntax error") ->
        %SyntaxError{message: msg}

      String.contains?(msg, "not found") or String.contains?(msg, "TemplateNotFound") ->
        %TemplateNotFound{message: msg}

      String.contains?(msg, "unknown filter") ->
        %UnknownFilter{message: msg}

      true ->
        %RenderError{message: msg}
    end
  end
end
