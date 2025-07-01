defmodule Pipeline.Meta.DNA do
  @moduledoc """
  The genetic blueprint structure for pipeline organisms.
  Defines the DNA schema used by the Genesis Pipeline and evolution system.
  """

  alias Pipeline.Meta.DNA.{
    StructuralChromosome,
    BehavioralChromosome,
    OptimizationChromosome,
    AdaptationChromosome
  }

  @type t :: %__MODULE__{
          # Identity genes
          id: String.t(),
          name: String.t(),
          lineage: list(String.t()),
          generation: non_neg_integer(),
          birth_timestamp: DateTime.t(),
          
          # Core chromosomes
          structural_chromosome: StructuralChromosome.t(),
          behavioral_chromosome: BehavioralChromosome.t(),
          optimization_chromosome: OptimizationChromosome.t(),
          adaptation_chromosome: AdaptationChromosome.t(),
          
          # Genetic markers
          dominant_traits: list(atom()),
          recessive_traits: list(atom()),
          mutations: list(map()),
          epigenetic_markers: map(),
          
          # Fitness metrics
          fitness_score: float(),
          survival_rate: float(),
          reproduction_rate: float(),
          innovation_index: float()
        }

  defstruct [
    :id,
    :name,
    :lineage,
    :generation,
    :birth_timestamp,
    :structural_chromosome,
    :behavioral_chromosome,
    :optimization_chromosome,
    :adaptation_chromosome,
    :dominant_traits,
    :recessive_traits,
    :mutations,
    :epigenetic_markers,
    :fitness_score,
    :survival_rate,
    :reproduction_rate,
    :innovation_index
  ]

  @doc """
  Creates a new pipeline DNA from a genome specification
  """
  def from_genome(genome) do
    %__MODULE__{
      id: generate_id(),
      name: genome["identity"]["name"],
      lineage: [],
      generation: 0,
      birth_timestamp: DateTime.utc_now(),
      structural_chromosome: build_structural_chromosome(genome),
      behavioral_chromosome: build_behavioral_chromosome(genome),
      optimization_chromosome: build_optimization_chromosome(genome),
      adaptation_chromosome: build_adaptation_chromosome(genome),
      dominant_traits: extract_dominant_traits(genome),
      recessive_traits: [],
      mutations: [],
      epigenetic_markers: %{},
      fitness_score: 0.0,
      survival_rate: 0.0,
      reproduction_rate: 0.0,
      innovation_index: 0.0
    }
  end

  @doc """
  Converts DNA back to a genome specification for pipeline generation
  """
  def to_genome(%__MODULE__{} = dna) do
    %{
      "identity" => %{
        "name" => dna.name,
        "id" => dna.id,
        "generation" => dna.generation,
        "lineage" => dna.lineage
      },
      "traits" => %{
        "performance_profile" => dna.optimization_chromosome.performance_profile,
        "error_handling_strategy" => dna.behavioral_chromosome.error_handling_strategy,
        "optimization_preferences" => dna.optimization_chromosome.preferences,
        "complexity_level" => calculate_complexity(dna)
      },
      "chromosomes" => %{
        "step_sequences" => dna.structural_chromosome.step_sequences,
        "provider_mappings" => dna.structural_chromosome.provider_mappings,
        "prompt_patterns" => dna.structural_chromosome.prompt_patterns
      }
    }
  end

  defp build_structural_chromosome(genome) do
    StructuralChromosome.from_genome(genome["chromosomes"])
  end

  defp build_behavioral_chromosome(genome) do
    BehavioralChromosome.from_traits(genome["traits"])
  end

  defp build_optimization_chromosome(genome) do
    OptimizationChromosome.from_traits(genome["traits"])
  end

  defp build_adaptation_chromosome(_genome) do
    AdaptationChromosome.new()
  end

  defp extract_dominant_traits(genome) do
    genome["traits"]
    |> Map.get("optimization_preferences", [])
    |> Enum.map(&String.to_atom/1)
  end

  defp calculate_complexity(%__MODULE__{} = dna) do
    step_count = length(dna.structural_chromosome.step_sequences)
    
    cond do
      step_count <= 3 -> "simple"
      step_count <= 7 -> "moderate"
      true -> "complex"
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end

defmodule Pipeline.Meta.DNA.StructuralChromosome do
  @moduledoc """
  Controls the fundamental architecture of the pipeline
  """

  @type t :: %__MODULE__{
          step_sequences: list(map()),
          provider_mappings: map(),
          prompt_patterns: list(map()),
          parallelism_factor: float(),
          branching_complexity: non_neg_integer()
        }

  defstruct [
    :step_sequences,
    :provider_mappings,
    :prompt_patterns,
    :parallelism_factor,
    :branching_complexity
  ]

  def from_genome(chromosomes) do
    %__MODULE__{
      step_sequences: chromosomes["step_sequences"] || [],
      provider_mappings: chromosomes["provider_mappings"] || %{},
      prompt_patterns: chromosomes["prompt_patterns"] || [],
      parallelism_factor: 0.0,
      branching_complexity: 0
    }
  end
end

defmodule Pipeline.Meta.DNA.BehavioralChromosome do
  @moduledoc """
  Determines execution patterns and runtime behavior
  """

  @type t :: %__MODULE__{
          error_handling_strategy: String.t(),
          retry_configuration: map(),
          timeout_settings: map(),
          logging_verbosity: atom()
        }

  defstruct [
    :error_handling_strategy,
    :retry_configuration,
    :timeout_settings,
    :logging_verbosity
  ]

  def from_traits(traits) do
    %__MODULE__{
      error_handling_strategy: traits["error_handling_strategy"] || "retry_robust",
      retry_configuration: default_retry_config(),
      timeout_settings: default_timeout_settings(),
      logging_verbosity: :normal
    }
  end

  defp default_retry_config do
    %{
      max_retries: 3,
      backoff_type: :exponential,
      initial_delay_ms: 1000
    }
  end

  defp default_timeout_settings do
    %{
      step_timeout_ms: 30_000,
      total_timeout_ms: 300_000
    }
  end
end

defmodule Pipeline.Meta.DNA.OptimizationChromosome do
  @moduledoc """
  Controls performance optimization characteristics
  """

  @type t :: %__MODULE__{
          performance_profile: String.t(),
          preferences: list(String.t()),
          token_conservation: float(),
          caching_aggressiveness: float()
        }

  defstruct [
    :performance_profile,
    :preferences,
    :token_conservation,
    :caching_aggressiveness
  ]

  def from_traits(traits) do
    %__MODULE__{
      performance_profile: traits["performance_profile"] || "balanced",
      preferences: traits["optimization_preferences"] || [],
      token_conservation: 0.7,
      caching_aggressiveness: 0.5
    }
  end
end

defmodule Pipeline.Meta.DNA.AdaptationChromosome do
  @moduledoc """
  Manages environmental adaptation capabilities
  """

  @type t :: %__MODULE__{
          learning_rate: float(),
          memory_capacity: non_neg_integer(),
          pattern_recognition: boolean(),
          feedback_sensitivity: float()
        }

  defstruct [
    :learning_rate,
    :memory_capacity,
    :pattern_recognition,
    :feedback_sensitivity
  ]

  def new do
    %__MODULE__{
      learning_rate: 0.1,
      memory_capacity: 100,
      pattern_recognition: true,
      feedback_sensitivity: 0.8
    }
  end
end