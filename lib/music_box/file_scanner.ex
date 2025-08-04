defmodule MusicBox.FileScanner do
  def scan(path, scan_type \\ :full) do
    DynamicSupervisor.start_child(
      MusicBox.FileScanner.Supervisor,
      {MusicBox.FileScanner.Pipeline, path: path, scan_type: scan_type}
    )
  end

  def stop do
    DynamicSupervisor.stop(MusicBox.FileScanner.Supervisor)
  end
end
