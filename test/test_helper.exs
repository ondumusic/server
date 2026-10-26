# Tests tagged :ffmpeg run the real ffmpeg/ffprobe, they are skipped when those
# are not installed.
ffmpeg_exclude = if System.find_executable("ffmpeg"), do: [], else: [:ffmpeg]

ExUnit.start(
  exclude: [:skip] ++ ffmpeg_exclude,
  assert_receive_timeout: 1_500,
  max_cases: 4
)

Mox.defmock(Ondu.Tool.ProbeMock, for: Ondu.Tool)
Mox.defmock(Ondu.Tool.TranscodeMock, for: Ondu.Tool)
Mox.defmock(Ondu.Tool.ExtractArtworkMock, for: Ondu.Tool)
Mox.defmock(Ondu.Tool.LoudnessMock, for: Ondu.Tool)
Ecto.Adapters.SQL.Sandbox.mode(Ondu.Repo, :manual)
