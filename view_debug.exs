#!/usr/bin/env elixir

# Debug Log and Output Viewer
# Usage: ./view_debug.exs [options]

Mix.install([
  {:pipeline, path: "."},
  {:jason, "~> 1.4"}
])

defmodule DebugViewer do
  alias Pipeline.Debug
  
  def main(args) do
    options = parse_args(args)
    
    output_dir = options[:output_dir] || "outputs"
    
    # Show debug log
    if !options[:files_only] do
      case Debug.find_latest_debug_log(output_dir) do
        {:ok, log_path} ->
          print_separator("Debug Log: #{log_path}")
          
          if options[:no_content] do
            IO.puts("Path: #{log_path}")
          else
            case File.read(log_path) do
              {:ok, content} -> IO.puts(content)
              _ -> IO.puts("Error reading debug log")
            end
          end
          
        {:error, _} ->
          IO.puts("No debug logs found.")
      end
    end
    
    # Show output files
    if !options[:log_only] do
      output_files = Debug.find_output_files(output_dir)
      
      if output_files != [] do
        # Group by directory
        by_dir = Enum.group_by(output_files, &Path.dirname/1)
        
        # Show most recent directory's files
        if map_size(by_dir) > 0 do
          {latest_dir, files} = by_dir |> Enum.sort_by(fn {_, files} ->
            files |> List.first() |> File.stat!() |> Map.get(:mtime)
          end, :desc) |> List.first()
          
          print_separator("Output Files from: #{Path.basename(latest_dir)}")
          
          Enum.each(files, fn file ->
            if options[:no_content] do
              IO.puts("Path: #{file}")
            else
              IO.puts("\n--- #{Path.basename(file)} ---")
              
              case File.read(file) do
                {:ok, content} ->
                  # Try to pretty-print JSON
                  case Jason.decode(content) do
                    {:ok, json} ->
                      IO.puts(Jason.encode!(json, pretty: true))
                    _ ->
                      IO.puts(content)
                  end
                  
                {:error, reason} ->
                  IO.puts("Error reading #{file}: #{inspect(reason)}")
              end
            end
          end)
        end
      end
    end
    
    # Show workspace files
    if options[:workspace] do
      workspace_files = Debug.find_workspace_files()
      
      if workspace_files != [] do
        print_separator("Workspace Files Created by Claude")
        IO.puts("Total files: #{length(workspace_files)}\n")
        
        Enum.each(workspace_files, fn file_info ->
          IO.puts("📄 #{file_info.relative_path}")
          IO.puts("   Size: #{Debug.format_size(file_info.size)}")
          IO.puts("   Modified: #{Debug.format_timestamp(file_info.mtime)}")
          IO.puts("   Full path: #{file_info.path}")
          IO.puts("")
        end)
      end
    end
  end
  
  defp parse_args(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [
        output_dir: :string,
        no_content: :boolean,
        log_only: :boolean,
        files_only: :boolean,
        workspace: :boolean
      ],
      aliases: [
        o: :output_dir,
        n: :no_content,
        l: :log_only,
        f: :files_only,
        w: :workspace
      ]
    )
    
    Enum.into(opts, %{})
  end
  
  defp print_separator(title) do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("=== #{title} ===")
    IO.puts(String.duplicate("=", 80) <> "\n")
  end
end

# Run the viewer
DebugViewer.main(System.argv())