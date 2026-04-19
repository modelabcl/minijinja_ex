defmodule MinijinjaEx.NIF do
  @moduledoc false

  version = Mix.Project.config()[:version]

  use RustlerPrecompiled,
    otp_app: :minijinja_ex,
    crate: "minijinja_ex",
    base_url: "https://github.com/modelabcl/minijinja_ex/releases/download/v#{version}",
    force_build: System.get_env("MINIJINJA_EX_BUILD") in ["1", "true"],
    version: version

  @spec render_string(String.t(), map()) :: String.t() | {:error, String.t()}
  def render_string(_template_source, _context), do: :erlang.nif_error(:nif_not_loaded)

  @spec env_new() :: reference()
  def env_new, do: :erlang.nif_error(:nif_not_loaded)

  @spec env_add_template(reference(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def env_add_template(_env, _name, _source), do: :erlang.nif_error(:nif_not_loaded)

  @spec env_render_template(reference(), String.t(), map()) :: String.t() | {:error, String.t()}
  def env_render_template(_env, _name, _context), do: :erlang.nif_error(:nif_not_loaded)

  @spec env_render_str(reference(), String.t(), map()) :: String.t() | {:error, String.t()}
  def env_render_str(_env, _source, _context), do: :erlang.nif_error(:nif_not_loaded)

  @spec env_set_trim_blocks(reference(), boolean()) :: :ok
  def env_set_trim_blocks(_env, _value), do: :erlang.nif_error(:nif_not_loaded)

  @spec env_set_lstrip_blocks(reference(), boolean()) :: :ok
  def env_set_lstrip_blocks(_env, _value), do: :erlang.nif_error(:nif_not_loaded)

  @spec env_set_keep_trailing_newline(reference(), boolean()) :: :ok
  def env_set_keep_trailing_newline(_env, _value), do: :erlang.nif_error(:nif_not_loaded)

  @spec env_reload(reference()) :: :ok
  def env_reload(_env), do: :erlang.nif_error(:nif_not_loaded)

  @spec env_add_global(reference(), String.t(), term()) :: :ok | {:error, String.t()}
  def env_add_global(_env, _name, _value), do: :erlang.nif_error(:nif_not_loaded)
end
