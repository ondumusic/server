defmodule MusicBoxWeb.LibraryControllerTest do
  use MusicBoxWeb.ConnCase, async: false

  alias MusicBox.Artists
  alias MusicBox.Tracks.Track

  import Ecto.Query, only: [from: 2]

  describe "artists" do
    setup :register_and_log_in_user

    test "returns paginated list of artists", %{conn: conn} do
      assert %{
               "pageNumber" => 1,
               "totalPages" => 1,
               "totalEntries" => 1,
               "pageSize" => 100,
               "entries" => [
                 %{
                   "albumCount" => 1,
                   "name" => "The Beatles",
                   "slug" => "the-beatles"
                 }
               ]
             } =
               conn
               |> get(~p"/api/artists")
               |> api_response(200, "ArtistPage")
    end

    test "returns artist details", %{conn: conn} do
      assert %{
               "albumCount" => 1,
               "name" => "The Beatles",
               "slug" => "the-beatles"
             } =
               conn
               |> get(~p"/api/artists/the-beatles")
               |> api_response(200, "Artist")
    end

    test "returns paginated list of albums for given artist", %{conn: conn} do
      assert %{
               "entries" => [
                 %{
                   "name" => "With the Beatles",
                   "slug" => "with-the-beatles",
                   "isUnknown" => false,
                   "releaseYear" => 1963,
                   "tracks" => [
                     %{
                       "duration" => 133.0,
                       "name" => "It Won't Be Long",
                       "number" => 1
                     },
                     %{
                       "duration" => 125.0,
                       "name" => "All I've Got To Do",
                       "number" => 2
                     },
                     %{
                       "duration" => 129.0,
                       "name" => "All My Loving",
                       "number" => 3
                     },
                     %{
                       "duration" => 149.0,
                       "name" => "Don't Bother Me",
                       "number" => 4
                     },
                     %{
                       "duration" => 108.0,
                       "name" => "Little Child",
                       "number" => 5
                     },
                     %{
                       "duration" => 137.0,
                       "name" => "Till There Was You",
                       "number" => 6
                     },
                     %{
                       "duration" => 155.0,
                       "name" => "Please Mister Postman",
                       "number" => 7
                     },
                     %{
                       "duration" => 168.0,
                       "name" => "Roll Over Beethoven",
                       "number" => 8
                     },
                     %{
                       "duration" => 153.0,
                       "name" => "Hold Me Tight",
                       "number" => 9
                     },
                     %{
                       "duration" => 183.0,
                       "name" => "You've Really Got a Hold on Me",
                       "number" => 10
                     },
                     %{
                       "duration" => 120.0,
                       "name" => "I Wanna Be Your Man",
                       "number" => 11
                     },
                     %{
                       "duration" => 148.0,
                       "name" => "Devil In Her Heart",
                       "number" => 12
                     },
                     %{
                       "duration" => 127.0,
                       "name" => "Not a Second Time",
                       "number" => 13
                     },
                     %{
                       "duration" => 170.0,
                       "name" => "Money (That's What I Want)",
                       "number" => 14
                     }
                   ]
                 }
               ],
               "pageNumber" => 1,
               "pageSize" => 50,
               "totalEntries" => 1,
               "totalPages" => 1
             } =
               conn
               |> get(~p"/api/artists/the-beatles/albums")
               |> api_response(200, "AlbumPage")
    end

    test "returns artist albums details ", %{conn: conn} do
      assert %{
               "name" => "With the Beatles",
               "slug" => "with-the-beatles",
               "isUnknown" => false,
               "releaseYear" => 1963,
               "tracks" => [
                 %{
                   "disc" => 1,
                   "duration" => 133.0,
                   "name" => "It Won't Be Long",
                   "number" => 1
                 },
                 %{
                   "disc" => 1,
                   "duration" => 125.0,
                   "name" => "All I've Got To Do",
                   "number" => 2
                 },
                 %{
                   "disc" => 1,
                   "duration" => 129.0,
                   "name" => "All My Loving",
                   "number" => 3
                 },
                 %{
                   "disc" => 1,
                   "duration" => 149.0,
                   "name" => "Don't Bother Me",
                   "number" => 4
                 },
                 %{
                   "disc" => 1,
                   "duration" => 108.0,
                   "name" => "Little Child",
                   "number" => 5
                 },
                 %{
                   "disc" => 1,
                   "duration" => 137.0,
                   "name" => "Till There Was You",
                   "number" => 6
                 },
                 %{
                   "disc" => 1,
                   "duration" => 155.0,
                   "name" => "Please Mister Postman",
                   "number" => 7
                 },
                 %{
                   "disc" => 1,
                   "duration" => 168.0,
                   "name" => "Roll Over Beethoven",
                   "number" => 8
                 },
                 %{
                   "disc" => 1,
                   "duration" => 153.0,
                   "name" => "Hold Me Tight",
                   "number" => 9
                 },
                 %{
                   "disc" => 1,
                   "duration" => 183.0,
                   "name" => "You've Really Got a Hold on Me",
                   "number" => 10
                 },
                 %{
                   "disc" => 1,
                   "duration" => 120.0,
                   "name" => "I Wanna Be Your Man",
                   "number" => 11
                 },
                 %{
                   "disc" => 1,
                   "duration" => 148.0,
                   "name" => "Devil In Her Heart",
                   "number" => 12
                 },
                 %{
                   "disc" => 1,
                   "duration" => 127.0,
                   "name" => "Not a Second Time",
                   "number" => 13
                 },
                 %{
                   "disc" => 1,
                   "duration" => 170.0,
                   "name" => "Money (That's What I Want)",
                   "number" => 14
                 }
               ]
             } =
               conn
               |> get(~p"/api/artists/the-beatles/albums/with-the-beatles")
               |> api_response(200, "Album")
    end
  end

  describe "albums" do
    setup :register_and_log_in_user

    test "returns paginated list of albums", %{conn: conn} do
      assert %{
               "pageNumber" => 1,
               "totalPages" => 1,
               "totalEntries" => 1,
               "pageSize" => 50,
               "entries" => [
                 %{
                   "name" => "With the Beatles",
                   "slug" => "with-the-beatles",
                   "isUnknown" => false,
                   "releaseYear" => 1963,
                   "tracks" => [
                     %{
                       "duration" => 133.0,
                       "name" => "It Won't Be Long",
                       "number" => 1
                     },
                     %{
                       "duration" => 125.0,
                       "name" => "All I've Got To Do",
                       "number" => 2
                     },
                     %{
                       "duration" => 129.0,
                       "name" => "All My Loving",
                       "number" => 3
                     },
                     %{
                       "duration" => 149.0,
                       "name" => "Don't Bother Me",
                       "number" => 4
                     },
                     %{
                       "duration" => 108.0,
                       "name" => "Little Child",
                       "number" => 5
                     },
                     %{
                       "duration" => 137.0,
                       "name" => "Till There Was You",
                       "number" => 6
                     },
                     %{
                       "duration" => 155.0,
                       "name" => "Please Mister Postman",
                       "number" => 7
                     },
                     %{
                       "duration" => 168.0,
                       "name" => "Roll Over Beethoven",
                       "number" => 8
                     },
                     %{
                       "duration" => 153.0,
                       "name" => "Hold Me Tight",
                       "number" => 9
                     },
                     %{
                       "duration" => 183.0,
                       "name" => "You've Really Got a Hold on Me",
                       "number" => 10
                     },
                     %{
                       "duration" => 120.0,
                       "name" => "I Wanna Be Your Man",
                       "number" => 11
                     },
                     %{
                       "duration" => 148.0,
                       "name" => "Devil In Her Heart",
                       "number" => 12
                     },
                     %{
                       "duration" => 127.0,
                       "name" => "Not a Second Time",
                       "number" => 13
                     },
                     %{
                       "duration" => 170.0,
                       "name" => "Money (That's What I Want)",
                       "number" => 14
                     }
                   ]
                 }
               ]
             } =
               conn
               |> get(~p"/api/albums")
               |> api_response(200, "AlbumPage")
    end

    test "get album details", %{conn: conn} do
      album = MusicBox.Repo.get_by(MusicBox.Albums.Album, slug: "with-the-beatles")

      assert %{
               "name" => "With the Beatles",
               "slug" => "with-the-beatles",
               "isUnknown" => false,
               "releaseYear" => 1963,
               "tracks" => [
                 %{
                   "duration" => 133.0,
                   "name" => "It Won't Be Long",
                   "number" => 1
                 },
                 %{
                   "duration" => 125.0,
                   "name" => "All I've Got To Do",
                   "number" => 2
                 },
                 %{
                   "duration" => 129.0,
                   "name" => "All My Loving",
                   "number" => 3
                 },
                 %{
                   "duration" => 149.0,
                   "name" => "Don't Bother Me",
                   "number" => 4
                 },
                 %{
                   "duration" => 108.0,
                   "name" => "Little Child",
                   "number" => 5
                 },
                 %{
                   "duration" => 137.0,
                   "name" => "Till There Was You",
                   "number" => 6
                 },
                 %{
                   "duration" => 155.0,
                   "name" => "Please Mister Postman",
                   "number" => 7
                 },
                 %{
                   "duration" => 168.0,
                   "name" => "Roll Over Beethoven",
                   "number" => 8
                 },
                 %{
                   "duration" => 153.0,
                   "name" => "Hold Me Tight",
                   "number" => 9
                 },
                 %{
                   "duration" => 183.0,
                   "name" => "You've Really Got a Hold on Me",
                   "number" => 10
                 },
                 %{
                   "duration" => 120.0,
                   "name" => "I Wanna Be Your Man",
                   "number" => 11
                 },
                 %{
                   "duration" => 148.0,
                   "name" => "Devil In Her Heart",
                   "number" => 12
                 },
                 %{
                   "duration" => 127.0,
                   "name" => "Not a Second Time",
                   "number" => 13
                 },
                 %{
                   "duration" => 170.0,
                   "name" => "Money (That's What I Want)",
                   "number" => 14
                 }
               ]
             } =
               conn
               |> get(~p"/api/albums/#{album.id}")
               |> api_response(200, "Album")
    end
  end

  describe "tracks" do
    setup :register_and_log_in_user

    test "paginate tracks", %{conn: conn} do
      assert %{
               "pageNumber" => 1,
               "totalPages" => 1,
               "totalEntries" => 14,
               "pageSize" => 50,
               "entries" => tracks
             } =
               conn
               |> get(~p"/api/tracks")
               |> api_response(200, "TrackPage")

      assert [
               %{
                 "duration" => 133.0,
                 "name" => "It Won't Be Long",
                 "number" => 1,
                 "artist" => %{
                   "name" => "The Beatles",
                   "albumCount" => 1
                 }
               },
               %{
                 "duration" => 125.0,
                 "name" => "All I've Got To Do",
                 "number" => 2
               },
               %{
                 "duration" => 129.0,
                 "name" => "All My Loving",
                 "number" => 3
               },
               %{
                 "duration" => 149.0,
                 "name" => "Don't Bother Me",
                 "number" => 4
               },
               %{
                 "duration" => 108.0,
                 "name" => "Little Child",
                 "number" => 5
               },
               %{
                 "duration" => 137.0,
                 "name" => "Till There Was You",
                 "number" => 6
               },
               %{
                 "duration" => 155.0,
                 "name" => "Please Mister Postman",
                 "number" => 7
               },
               %{
                 "duration" => 168.0,
                 "name" => "Roll Over Beethoven",
                 "number" => 8
               },
               %{
                 "duration" => 153.0,
                 "name" => "Hold Me Tight",
                 "number" => 9
               },
               %{
                 "duration" => 183.0,
                 "name" => "You've Really Got a Hold on Me",
                 "number" => 10
               },
               %{
                 "duration" => 120.0,
                 "name" => "I Wanna Be Your Man",
                 "number" => 11
               },
               %{
                 "duration" => 148.0,
                 "name" => "Devil In Her Heart",
                 "number" => 12
               },
               %{
                 "duration" => 127.0,
                 "name" => "Not a Second Time",
                 "number" => 13
               },
               %{
                 "duration" => 170.0,
                 "name" => "Money (That's What I Want)",
                 "number" => 14
               }
             ] = tracks
    end

    test "paginate tracks (sort random)", %{conn: conn} do
      seed1 = 0.12_345
      seed2 = 0.98_765_432

      TestSeeds.generate_artists(50)

      assert %{
               "entries" => tracks
             } =
               conn
               |> get(~p"/api/tracks?sort_by=random&random_seed=#{seed1}")
               |> api_response(200, "TrackPage")

      assert %{
               "entries" => tracks2
             } =
               conn
               |> get(~p"/api/tracks?sort_by=random&random_seed=#{seed2}")
               |> api_response(200, "TrackPage")

      assert tracks != tracks2
      assert length(tracks) == length(tracks2)
    end

    test "filter by artist id", %{conn: conn} do
      artist =
        TestSeeds.insert_artist(%{
          name: "dodie",
          albums: [
            %{
              name: "Build A Problem",
              release_year: 2021,
              tracks: [
                %{
                  disc: 1,
                  track: 2,
                  name: "Hate Myself"
                }
              ]
            }
          ]
        })

      assert %{
               "entries" => tracks
             } =
               conn
               |> get(~p"/api/tracks?artist_id=#{artist.id}")
               |> api_response(200, "TrackPage")

      assert [
               %{
                 "disc" => 1,
                 "number" => 2,
                 "name" => "Hate Myself",
                 "artist" => %{
                   "name" => "dodie"
                 },
                 "album" => %{
                   "name" => "Build A Problem",
                   "releaseYear" => 2021
                 }
               }
             ] = tracks
    end

    test "filter by album id", %{conn: conn} do
      artist = Artists.get_artist!("the-beatles")

      album =
        TestSeeds.insert_album(artist, %{
          name: "Revolver",
          release_year: 1966,
          tracks: [
            %{
              disc: 1,
              track: 1,
              name: "Taxman"
            },
            %{
              disc: 1,
              track: 2,
              name: "Eleanor Rigby"
            }
          ]
        })

      assert %{
               "entries" => tracks
             } =
               conn
               |> get(~p"/api/tracks?album_id=#{album.id}")
               |> api_response(200, "TrackPage")

      assert [
               %{
                 "disc" => 1,
                 "number" => 1,
                 "name" => "Taxman",
                 "artist" => %{
                   "name" => "The Beatles"
                 },
                 "album" => %{
                   "name" => "Revolver",
                   "releaseYear" => 1966
                 }
               },
               %{
                 "disc" => 1,
                 "number" => 2,
                 "name" => "Eleanor Rigby",
                 "artist" => %{
                   "name" => "The Beatles"
                 },
                 "album" => %{
                   "name" => "Revolver",
                   "releaseYear" => 1966
                 }
               }
             ] = tracks
    end

    test "filter by search query", %{conn: conn} do
      assert %{
               "entries" => tracks
             } =
               conn
               |> get(~p"/api/tracks?query=post")
               |> api_response(200, "TrackPage")

      assert [
               %{
                 "disc" => 1,
                 "number" => 7,
                 "name" => "Please Mister Postman",
                 "artist" => %{
                   "name" => "The Beatles"
                 },
                 "album" => %{
                   "name" => "With the Beatles",
                   "releaseYear" => 1963
                 }
               }
             ] = tracks
    end

    test "returns track details", %{conn: conn} do
      track = Repo.get_by(Track, name: "Roll Over Beethoven")

      assert %{
               "name" => "Roll Over Beethoven",
               "artist" => %{
                 "name" => "The Beatles",
                 "slug" => "the-beatles"
               },
               "disc" => 1,
               "duration" => 168.0,
               "mimetype" => "audio/mpeg",
               "number" => 8
             } =
               conn
               |> get(~p"/api/tracks/#{track.id}")
               |> api_response(200, "Track")
    end
  end

  describe "track loudness" do
    setup :register_and_log_in_user

    setup do
      track = Repo.get_by(Track, name: "Roll Over Beethoven") |> Repo.preload(:file)
      [track: track]
    end

    test "is null until measured", %{conn: conn, track: track} do
      assert %{"loudness" => nil} =
               conn
               |> get(~p"/api/tracks/#{track.id}")
               |> api_response(200, "Track")
    end

    test "returns the measurement", %{conn: conn, track: track} do
      set_loudness(track, %{lufs: -9.2, peak: -0.3})

      assert %{"loudness" => %{"lufs" => -9.2, "peak" => -0.3}} =
               conn
               |> get(~p"/api/tracks/#{track.id}")
               |> api_response(200, "Track")
    end

    test "is null when measuring failed", %{conn: conn, track: track} do
      set_loudness(track, %{lufs: nil, peak: nil})

      assert %{"loudness" => nil} =
               conn
               |> get(~p"/api/tracks/#{track.id}")
               |> api_response(200, "Track")
    end

    defp set_loudness(track, values) do
      loudness =
        struct!(MusicBox.Files.Loudness, Map.put(values, :measured_at, DateTime.utc_now(:second)))

      Repo.update_all(from(f in MusicBox.Files.File, where: f.id == ^track.file.id),
        set: [loudness: loudness]
      )
    end
  end

  describe "forbidden when not authenticated" do
    test "forbidden on /api/artists", %{conn: conn} do
      assert_raise MusicBoxWeb.UnauthorizedError, fn ->
        get(conn, "/api/artists")
      end
    end

    test "forbidden on /api/albums", %{conn: conn} do
      assert_raise MusicBoxWeb.UnauthorizedError, fn ->
        get(conn, "/api/albums")
      end
    end
  end
end
