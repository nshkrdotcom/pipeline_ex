defmodule Pipeline.Schemas.AnalysisResponse do
  @moduledoc """
  Schema for basic analysis responses from Gemini.
  """

  use Ecto.Schema
  use InstructorLite.Instruction

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field(:text, :string)
    field(:analysis, :string)
    field(:summary, :string)
  end
end
