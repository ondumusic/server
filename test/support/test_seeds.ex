defmodule TestSeeds do
  @moduledoc false

  alias MusicBox.Accounts
  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist
  alias MusicBox.Cleanup
  alias MusicBox.Files.File
  alias MusicBox.Files.FileMetadata
  alias MusicBox.FileScanner.Utils
  alias MusicBox.Repo
  alias MusicBox.Tracks.Track

  def reset do
    [
      %{
        name: "The Beatles",
        albums: [
          %{
            name: "With the Beatles",
            release_year: 1963,
            tracks: [
              %{track: 1, name: "It Won't Be Long", duration: seconds("2:13")},
              %{track: 2, name: "All I've Got To Do", duration: seconds("2:05")},
              %{track: 3, name: "All My Loving", duration: seconds("2:09")},
              %{track: 4, name: "Don't Bother Me", duration: seconds("2:29")},
              %{track: 5, name: "Little Child", duration: seconds("1:48")},
              %{track: 6, name: "Till There Was You", duration: seconds("2:17")},
              %{track: 7, name: "Please Mister Postman", duration: seconds("2:35")},
              %{track: 8, name: "Roll Over Beethoven", duration: seconds("2:48")},
              %{track: 9, name: "Hold Me Tight", duration: seconds("2:33")},
              %{track: 10, name: "You've Really Got a Hold on Me", duration: seconds("3:03")},
              %{track: 11, name: "I Wanna Be Your Man", duration: seconds("2:00")},
              %{track: 12, name: "Devil In Her Heart", duration: seconds("2:28")},
              %{track: 13, name: "Not a Second Time", duration: seconds("2:07")},
              %{track: 14, name: "Money (That's What I Want)", duration: seconds("2:50")}
            ]
          }
        ]
      }
    ]
    |> Enum.each(&insert_artist/1)

    [:update_album_counts, :update_fts]
    |> Enum.each(&Cleanup.Worker.do_step/1)

    Repo.query!("INSERT INTO artists_fts(artists_fts) VALUES('rebuild');")
    Repo.query!("INSERT INTO albums_fts(albums_fts) VALUES('rebuild');")
    Repo.query!("INSERT INTO tracks_fts(tracks_fts) VALUES('rebuild');")

    Accounts.register_user(%{
      username: "testuser",
      password: "testtest123!",
      password_confirmation: "testtest123!"
    })
  end

  def generate_artists(count) do
    for i <- 1..count do
      album_count = Enum.random(1..5)

      %{
        name: "Artist #{i}",
        albums:
          for j <- 1..album_count do
            track_count = Enum.random(5..15)

            %{
              name: "Album #{j} by Artist #{i}",
              release_year: Enum.random(1960..2025),
              tracks:
                for k <- 1..track_count do
                  %{
                    track: k,
                    name: "Track #{j}.#{i}.#{k}",
                    duration: Enum.random(90..420) * 1.0
                  }
                end
            }
          end
      }
    end
    |> Enum.each(&insert_artist/1)
  end

  def insert_artist(seed) do
    artist =
      Repo.insert!(%Artist{
        name: seed.name,
        slug: Utils.slugify(seed.name)
      })

    if albums = Map.get(seed, :albums),
      do: Enum.each(albums, &insert_album(artist, &1))

    if tracks = Map.get(seed, :tracks),
      do: Enum.each(tracks, &insert_track(artist, nil, &1))

    artist
  end

  def insert_album(artist, seed) do
    album =
      Repo.insert!(%Album{
        artist_id: artist.id,
        name: seed.name,
        slug: Utils.slugify(seed.name),
        compilation: Map.get(seed, :compilation) == true,
        release_year: seed.release_year
      })

    if tracks = Map.get(seed, :tracks),
      do: Enum.each(tracks, &insert_track(artist, album, &1))

    album
  end

  def insert_track(artist, album, seed) do
    duration = Map.get(seed, :duration, 21.0 + :rand.uniform() * 500.5)

    file =
      Repo.insert!(%File{
        path: "/Path/to/Music/#{seed.name}.mp3",
        type: Map.get(seed, :type, :mp3),
        size: Map.get(seed, :size, round(:rand.uniform() * 1024 * 1024 * 4)),
        metadata: %FileMetadata{
          artist: if(artist, do: artist.name),
          album: if(album, do: album.name),
          album_artist: Map.get(seed, :album_artist, if(artist, do: artist.name)),
          disc: Map.get(seed, :disc),
          track: Map.get(seed, :track),
          release_year: Map.get(seed, :release_year),
          compilation: Map.get(seed, :compilation) == true,
          duration: duration,
          genres: Map.get(seed, :genres, [])
        }
      })

    Repo.insert!(%Track{
      file_id: file.id,
      artist_id: if(artist, do: artist.id),
      album_id: if(album, do: album.id),
      name: seed.name,
      duration: duration,
      number: Map.get(seed, :track),
      disc: Map.get(seed, :disc)
    })
  end

  def seconds(duration) do
    [minutes, seconds] =
      duration
      |> String.split(":")
      |> Enum.map(&Float.parse/1)
      |> Enum.map(&elem(&1, 0))

    minutes * 60.0 + seconds
  end
end
