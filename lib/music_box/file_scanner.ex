defmodule MusicBox.FileScanner do
  def scan(scan_type \\ :full) do
    # TODO: Make this configurable
    music_dir = "/Users/max/Music"

    DynamicSupervisor.start_child(
      MusicBox.FileScanner.Supervisor,
      {MusicBox.FileScanner.Pipeline, path: music_dir, scan_type: scan_type}
    )
  end

  def stop do
    DynamicSupervisor.stop(MusicBox.FileScanner.Supervisor)
  end
end
