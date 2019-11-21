defmodule GG do
  @moduledoc """
  A module for writing log messages from a cluster of VMs to the same
  file on disk
  """

  @logfile "/tmp/gg.log"
  @endpoint HeraklesWeb.Endpoint


  @doc """
  """
  def format(string) when is_binary(string) do
    output = List.flatten(:io_lib.format("~s~n", [string]))
    :ok = to_disk(output)
  end

  def format(format, term) when is_binary(format) do
    output = List.flatten(:io_lib.format(format, term))
    :ok = to_disk(output)
  end

  def l() do
    Phoenix.CodeReloader.reload!(@endpoint)
  end

  def c(compile_mods) when is_list(compile_mods) do
    for m <- compile_mods, do: c(m)
  end

  def c(compile_mod) when is_atom(compile_mod) do
    modules = :lists.sort(:code.all_loaded())
    [{_m, beampath}] = for {loaded_mod, path} <- modules, loaded_mod == compile_mod do
      {loaded_mod, path}
    end
    {root, appname, path_ext, src_file} = get_paths_and_appname(to_string(beampath))
    file = find(root, appname, path_ext, src_file)
    {:module, compiled_mod} = compile(file, beampath, root)
    compiled_mod
  end

  defp compile(file, beampath, root) do
    deppath = Path.join([root, "deps"])
    libpath = Path.join([root, "deps"])
    outdir = Path.dirname(beampath)
    {"", 0} = System.cmd("elixirc", ["-o", outdir, "-pa", deppath, "-pa", libpath, file], stderr_to_stdout: :true)
    module = String.to_atom(Path.basename(beampath, ".beam"))
    _delete = :code.delete(module)
    _purge = :code.purge(module)
    _load = :code.load_file(module)
  end

  defp find(root, appname, path_ext, src_file) do
    case find2(root, "deps", appname, path_ext, src_file, :true) do
      {:ok, file} -> file
      :not_found  -> find2(root, "lib", appname, path_ext, src_file, :false)
    end
  end

  defp find2(root, dir, appname, path_ext, srcfile, add_app_name) do
    search_path = Path.join([root, dir])
    {:ok, found_files} = File.ls(search_path)
    candidates = for f <- found_files, f == appname, do: f
    case candidates do
      []  -> :not_found
      [d] -> dirpath = Path.join([search_path, d])
             case File.dir?(dirpath) do
               :true  -> case add_app_name do
                           :true  -> Path.join([root, dir, appname, path_ext, srcfile])
                           :false -> Path.join([root, dir, path_ext, srcfile])
                          end
               :false -> :not_foundxxx
            end
    end
  end

  defp get_paths_and_appname(path) do
    segs = String.split(path, "/")
    extract(segs)
  end

  defp extract(list), do: ext2(list, [])

  defp ext2(["_build", "dev", "lib" | t], acc) do
     root = Enum.join(["/", Path.join(Enum.reverse(acc))])
     [beamname, _ebin, appname] = Enum.reverse(t)
     {path_ext, srcfile} = parse(beamname)
     {root, appname, path_ext, srcfile}
  end
  defp ext2([h | t], acc), do: ext2(t, [h | acc])

  defp parse(beamname) do
    ["Elixir"| segs] = String.split(beamname, ".")
    ["beam", file | rest] = Enum.reverse(segs)
    path_ext = case rest do
      [] -> []
      _  -> downcase = for r <- rest, do: String.downcase(r)
            Path.join(Enum.reverse(downcase))
    end
    {path_ext, elixir_downcase(Enum.join([file, "ex"], "."))}
  end

  defp elixir_downcase(beamname) do
    [initial_letter | chars] = for x <- String.to_charlist(beamname), do: List.to_string([x])
    down = for c <- chars, do: elixir_d2(c)
    String.downcase(initial_letter) <> Enum.join(down)
  end

  defp elixir_d2(char) do
      case String.downcase(char) do
        ^char -> char
        diff  -> "_" <> diff
      end
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
