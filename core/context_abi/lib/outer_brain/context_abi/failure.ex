defmodule OuterBrain.ContextABI.Failure do
  @moduledoc """
  Owner-local, safe failure shape for Context ABI and adjacent AI execution seams.
  """

  @owners [
    :outer_brain,
    :citadel,
    :mezzanine,
    :jido_integration,
    :app_kit,
    :aitrace,
    :trinity,
    :gepa,
    :stack_lab
  ]

  @enforce_keys [:owner, :reason_code, :safe_message]
  defstruct [
    :owner,
    :reason_code,
    :safe_message,
    retryable?: false,
    trace_ref: nil,
    evidence_refs: []
  ]

  @type owner ::
          :outer_brain
          | :citadel
          | :mezzanine
          | :jido_integration
          | :app_kit
          | :aitrace
          | :trinity
          | :gepa
          | :stack_lab

  @type t :: %__MODULE__{
          owner: owner(),
          reason_code: String.t(),
          safe_message: String.t(),
          retryable?: boolean(),
          trace_ref: String.t() | nil,
          evidence_refs: [String.t()]
        }

  @spec owners() :: [owner()]
  def owners, do: @owners

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = failure), do: {:ok, failure}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    with {:ok, owner} <- owner(value(attrs, :owner)),
         {:ok, reason_code} <- string(attrs, :reason_code),
         :ok <- reason_code_owner(owner, reason_code),
         :ok <- reason_code_version(reason_code),
         {:ok, safe_message} <- string(attrs, :safe_message),
         {:ok, evidence_refs} <- optional_string_list(attrs, :evidence_refs) do
      {:ok,
       %__MODULE__{
         owner: owner,
         reason_code: reason_code,
         safe_message: safe_message,
         retryable?: value(attrs, :retryable?) == true,
         trace_ref: optional_string(attrs, :trace_ref),
         evidence_refs: evidence_refs
       }}
    end
  end

  def new(_attrs), do: {:error, :invalid_failure}

  @spec new!(map() | keyword() | t()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, failure} -> failure
      {:error, reason} -> raise ArgumentError, "invalid Context ABI failure: #{inspect(reason)}"
    end
  end

  defp owner(owner) when owner in @owners, do: {:ok, owner}

  defp owner(owner) when is_binary(owner) do
    Enum.find(@owners, &(Atom.to_string(&1) == owner))
    |> case do
      nil -> {:error, :invalid_failure_owner}
      found -> {:ok, found}
    end
  end

  defp owner(_owner), do: {:error, :invalid_failure_owner}

  defp reason_code_owner(owner, reason_code) do
    prefix = Atom.to_string(owner) <> "."

    if String.starts_with?(reason_code, prefix) do
      :ok
    else
      {:error, :reason_code_owner_mismatch}
    end
  end

  defp reason_code_version(reason_code) do
    if String.match?(reason_code, ~r/\.v[0-9]+$/) do
      :ok
    else
      {:error, :unversioned_reason_code}
    end
  end

  defp string(attrs, field) do
    case value(attrs, field) do
      candidate when is_binary(candidate) and candidate != "" -> {:ok, candidate}
      _other -> {:error, {:missing_failure_field, field}}
    end
  end

  defp optional_string(attrs, field) do
    case value(attrs, field) do
      candidate when is_binary(candidate) and candidate != "" -> candidate
      _other -> nil
    end
  end

  defp optional_string_list(attrs, field) do
    case value(attrs, field) do
      nil -> {:ok, []}
      values when is_list(values) -> validate_string_list(values, field)
      _other -> {:error, {:invalid_failure_field, field}}
    end
  end

  defp validate_string_list(values, field) do
    if Enum.all?(values, &(is_binary(&1) and &1 != "")) do
      {:ok, values}
    else
      {:error, {:invalid_failure_field, field}}
    end
  end

  defp value(attrs, field), do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
end
