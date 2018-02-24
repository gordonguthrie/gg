defmodule GG do
  @moduledoc """
  A module for writing log messages from a cluster of VMs to the same
  file on disk
  """

  @logfile "/tmp/gg.log"

  @doc """
  """
  def format(string) when is_binary(string) do
    output = List.flatten(:io_lib.format("~s~n", [string]))
    :ok = to_disk(output)
  end

  def format(format, term) when is_binary(format) do
    output = List.flatten(:io_lib.format(format, [term]))
    :ok = to_disk(output)
  end

  defp to_disk(output) do
    IO.inspect output
    # Macros and shit prevent you using an attribute in File.open
    log = @logfile
    case File.exists?(log) do
      true  -> :ok
      false -> File.touch(log)
    end
    {:ok, file} = File.open(log, [:append])
    IO.binwrite(file, [output])
    :ok = File.close(file)
  end

end
