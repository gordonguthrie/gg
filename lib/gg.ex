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
    # Macros and shit prevent you using an attribute in File.open
    log = @logfile
    case File.exists?(log) do
      true  -> :ok
      false -> File.touch(log)
    end
    {:ok, file} = File.open(log, [:append])
    [{:registered_name, rn}] = :erlang.process_info(self(), [:registered_name])
     time = :calendar.now_to_universal_time(:erlang.now())
     :ok = :io.fwrite(file, "On ~p as {~p, ~p} at ~p~n- ~s~n",
       [node(), self(), rn, time, output])
     :ok = File.close(file)
  end

end
