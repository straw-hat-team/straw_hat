defmodule StrawHat.Utils.Map do
  @moduledoc """
  Functions for transforming maps, keys and values.
  """

  defmodule AtomizeKeyError do
    @type t :: %__MODULE__{key: any}

    defexception [:key]

    @spec message(%{key: String.t()}) :: String.t()
    def message(%{key: key}) do
      "\"#{key}\" binary hasn't been used on the system as an atom before"
    end
  end

  @doc ~S"""
  Recursively traverse a map and invoke a function for each key/
  value pair that transforms the map.

  ## Examples

      iex> map = %{a: "a", b: %{c: "c"}}
      iex> StrawHat.Utils.Map.deep_map map, fn {k, v} ->
      ...>   {k, String.upcase(v)}
      ...> end
      %{a: "A", b: %{c: "C"}}

  """
  @spec deep_map(Map.t(), function :: function()) :: Map.t()
  # Don't deep map structs since they have atom keys anyway and they
  # also don't support enumerable
  def deep_map(%{__struct__: _any} = map, _function) do
    map
  end

  def deep_map(map, function) when is_map(map) do
    Enum.into(map, %{}, fn
      {k, v} when is_map(v) or is_list(v) ->
        {k, deep_map(v, function)}

      {k, v} ->
        function.({k, v})
    end)
  end

  def deep_map([head | rest], fun) do
    [deep_map(head, fun) | deep_map(rest, fun)]
  end

  def deep_map(nil, _fun) do
    nil
  end

  def deep_map(value, fun) do
    fun.(value)
  end

  @doc """
  Recursively traverse a map and invoke a function for each key
  and a function for each value that transform the map.

  * `key_function` is a function or function reference that
    is called for each key of the provided map and any keys
    of any submaps

  * `value_function` is a function or function reference that
    is called for each value of the provided map and any values
    of any submaps
  """
  @spec deep_map(Map.t(), key_function :: function(), value_function :: function()) :: Map.t()
  def deep_map(map, key_function, value_function)

  def deep_map(%{__struct__: _any} = map, _key_function, _value_function) do
    map
  end

  def deep_map(map, key_function, value_function) when is_map(map) do
    Enum.into(map, %{}, fn
      {k, v} when is_map(v) or is_list(v) ->
        {key_function.(k), deep_map(v, key_function, value_function)}

      {k, v} ->
        {key_function.(k), value_function.(v)}
    end)
  end

  def deep_map([head | rest], key_fun, value_fun) do
    [deep_map(head, key_fun, value_fun) | deep_map(rest, key_fun, value_fun)]
  end

  def deep_map(nil, _key_fun, _value_fun) do
    nil
  end

  def deep_map(value, _key_fun, value_fun) do
    value_fun.(value)
  end

  @doc """
  Transforms a `map`'s `String.t` keys to `atom()` keys.

  * `options` is a keyword list of options.  The
    available option is:

    * `:only_existing` which is set to `true` will
      only convert the binary key to an atom if the atom
      already exists.  The default is `false`.
  """
  @spec atomize_keys(map(), keyword()) :: map()
  def atomize_keys(map, options \\ [only_existing: true]) do
    deep_map(map, &atomize_element(&1, options[:only_existing]), &StrawHat.identity/1)
  end

  @doc """
  Transforms a `map`'s `String.t` values to `atom()` values.

  * `options` is a keyword list of options.  The
    available option is:

    * `:only_existing` which is set to `true` will
      only convert the binary value to an atom if the atom
      already exists.  The default is `false`.
  """
  @spec atomize_values(map(), keyword()) :: map()
  def atomize_values(map, options \\ [only_existing: false]) do
    deep_map(map, &StrawHat.identity/1, &atomize_element(&1, options[:only_existing]))
  end

  @doc """
  Transforms a `map`'s `atom()` keys to `String.t` keys.
  """
  @spec stringify_keys(map()) :: map()
  def stringify_keys(map) do
    deep_map(
      map,
      fn
        k when is_atom(k) -> Atom.to_string(k)
        k -> k
      end,
      &StrawHat.identity/1
    )
  end

  defp atomize_element(x, true) when is_binary(x) do
    try do
      String.to_existing_atom(x)
    rescue
      ArgumentError ->
        reraise(AtomizeKeyError, [key: x], __STACKTRACE__)
    end
  end

  defp atomize_element(x, false) when is_binary(x), do: String.to_atom(x)

  defp atomize_element(x, _), do: x
end
