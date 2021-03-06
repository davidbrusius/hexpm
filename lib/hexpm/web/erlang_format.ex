defmodule Hexpm.Web.ErlangFormat do
  def encode_to_iodata!(term) do
    term
    |> Hexpm.Utils.binarify()
    |> :erlang.term_to_binary()
  end

  @spec decode(binary) :: term
  def decode("") do
    {:ok, nil}
  end

  def decode(binary) do
    case Hexpm.Utils.safe_binary_to_term(binary, [:safe]) do
      {:ok, term} ->
        {:ok, term}

      :error ->
        {:error, "bad binary_to_term"}
    end
  rescue
    ArgumentError ->
      {:error, "bad binary_to_term"}
  end
end
