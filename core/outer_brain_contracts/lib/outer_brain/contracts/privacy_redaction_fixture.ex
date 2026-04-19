defmodule OuterBrain.Contracts.PrivacyRedactionFixture do
  @moduledoc """
  Phase 4 public DTO and search-attribute redaction fixture contract.

  The fixture proves raw prompts, provider-native payloads, secrets, and tenant
  identifiers do not cross public DTO, operator, incident, or search-attribute
  boundaries.
  """

  alias OuterBrain.Contracts.Phase4SemanticContract

  @contract_name "Platform.PrivacyRedactionFixture.v1"
  @fields Phase4SemanticContract.scope_fields() ++
            [
              :principal_ref,
              :system_actor_ref,
              :redaction_policy_ref,
              :raw_field_name,
              :public_field_name,
              :redaction_class,
              :fixture_ref,
              :scan_ref,
              :public_payload,
              :search_attributes
            ]

  @required_strings [
    :redaction_policy_ref,
    :raw_field_name,
    :public_field_name,
    :redaction_class,
    :fixture_ref,
    :scan_ref
  ]

  defstruct [:contract_name | @fields]

  @type t :: %__MODULE__{}

  @spec new(map() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = contract), do: contract |> to_map() |> new()

  def new(attrs) when is_map(attrs) do
    with :ok <- Phase4SemanticContract.required_scope(attrs),
         :ok <- Phase4SemanticContract.required_strings(attrs, @required_strings),
         {:ok, public_payload} <- Phase4SemanticContract.required_map(attrs, :public_payload),
         :ok <- Phase4SemanticContract.reject_forbidden_public_payload(public_payload),
         {:ok, search_attributes} <-
           Phase4SemanticContract.required_map(attrs, :search_attributes),
         :ok <- Phase4SemanticContract.reject_search_attribute_leaks(search_attributes) do
      {:ok, build(attrs, public_payload, search_attributes)}
    end
  end

  def new(_attrs), do: {:error, :invalid_privacy_redaction_fixture}

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = contract),
    do: Map.from_struct(contract) |> Map.delete(:contract_name)

  defp build(attrs, public_payload, search_attributes) do
    struct!(
      __MODULE__,
      Map.new(@fields, &{&1, Phase4SemanticContract.fetch_value(attrs, &1)})
      |> Map.put(:contract_name, @contract_name)
      |> Map.put(:public_payload, public_payload)
      |> Map.put(:search_attributes, search_attributes)
    )
  end
end
