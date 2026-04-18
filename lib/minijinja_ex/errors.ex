defmodule MinijinjaEx.Error do
  @moduledoc """
  Base error type for MinijinjaEx.
  """

  defexception [:message]

  @type t :: %__MODULE__{message: String.t()}
end

defmodule MinijinjaEx.SyntaxError do
  @moduledoc """
  Error raised for template syntax errors.
  """

  defexception [:message, :line, :template]

  @type t :: %__MODULE__{
          message: String.t(),
          line: nil | pos_integer(),
          template: nil | String.t()
        }
end

defmodule MinijinjaEx.TemplateNotFound do
  @moduledoc """
  Error raised when a template is not found.
  """

  defexception [:message, :name]

  @type t :: %__MODULE__{message: String.t(), name: nil | String.t()}
end

defmodule MinijinjaEx.UnknownFilter do
  @moduledoc """
  Error raised when an unknown filter is used.
  """

  defexception [:message, :filter_name]

  @type t :: %__MODULE__{message: String.t(), filter_name: nil | String.t()}
end

defmodule MinijinjaEx.RenderError do
  @moduledoc """
  General rendering error.
  """

  defexception [:message]

  @type t :: %__MODULE__{message: String.t()}
end
