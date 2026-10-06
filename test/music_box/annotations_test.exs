defmodule MusicBox.AnnotationsTest do
  use MusicBox.DataCase, async: true

  alias MusicBox.Albums.Album
  alias MusicBox.Annotations
  alias MusicBox.Annotations.Annotation
  alias MusicBox.Artists.Artist
  alias MusicBox.Cleanup
  alias MusicBox.Tracks.Track

  setup do
    [artist: Artist |> first() |> Repo.one!(), album: Album |> first() |> Repo.one!()]
  end

  defp entry(entity, data), do: %{"entity_id" => entity.id, "data" => data}

  defp list!(namespace, entity_type) do
    {:ok, page} = Annotations.paginate_annotations(namespace, entity_type)
    page.entries
  end

  test "writes, replaces and removes annotations", %{artist: artist} do
    assert {:ok, %{skipped: []}} =
             Annotations.put_annotations("musicbrainz", "artists", [entry(artist, %{"id" => "a"})])

    assert {:ok, %{skipped: []}} =
             Annotations.put_annotations("musicbrainz", "artists", [entry(artist, %{"id" => "b"})])

    assert [%Annotation{entity_id: id, data: %{"id" => "b"}}] = list!("musicbrainz", "artists")
    assert id == artist.id

    assert {:ok, _} = Annotations.put_annotations("musicbrainz", "artists", [entry(artist, nil)])
    assert list!("musicbrainz", "artists") == []
  end

  test "keeps namespaces and entity types apart", %{artist: artist, album: album} do
    {:ok, _} =
      Annotations.put_annotations("musicbrainz", "artists", [entry(artist, %{"id" => "a"})])

    {:ok, _} =
      Annotations.put_annotations("musicbrainz", "albums", [entry(album, %{"id" => "b"})])

    {:ok, _} = Annotations.put_annotations("other.tool", "artists", [entry(artist, %{"x" => 1})])

    assert [%{data: %{"id" => "a"}}] = list!("musicbrainz", "artists")
    assert [%{data: %{"id" => "b"}}] = list!("musicbrainz", "albums")
    assert [%{data: %{"x" => 1}}] = list!("other.tool", "artists")
  end

  test "skips entities that don't exist", %{artist: artist, album: album} do
    missing = Ecto.UUID.generate()

    assert {:ok, %{skipped: skipped}} =
             Annotations.put_annotations("musicbrainz", "artists", [
               entry(artist, %{"id" => "a"}),
               %{"entity_id" => missing, "data" => %{"id" => "b"}},
               # An album is not an artist.
               entry(album, %{"id" => "c"})
             ])

    assert Enum.sort(skipped) == Enum.sort([missing, album.id])
    assert [%{entity_id: id}] = list!("musicbrainz", "artists")
    assert id == artist.id
  end

  test "accepts uppercase entity ids", %{artist: artist} do
    entry = %{"entity_id" => String.upcase(artist.id), "data" => %{"id" => "a"}}

    assert {:ok, %{skipped: []}} = Annotations.put_annotations("musicbrainz", "artists", [entry])
    assert [%{entity_id: id}] = list!("musicbrainz", "artists")
    assert id == artist.id
  end

  test "the last entry of an entity in a batch wins", %{artist: artist} do
    entries = [entry(artist, %{"id" => "a"}), entry(artist, %{"id" => "b"})]

    assert {:ok, _} = Annotations.put_annotations("musicbrainz", "artists", entries)
    assert [%{data: %{"id" => "b"}}] = list!("musicbrainz", "artists")
  end

  test "refuses invalid batches", %{artist: artist} do
    valid = entry(artist, %{"id" => "a"})

    assert {:error, :invalid_namespace} =
             Annotations.put_annotations("MusicBrainz", "artists", [valid])

    assert {:error, :invalid_namespace} =
             Annotations.put_annotations(String.duplicate("a", 65), "artists", [valid])

    assert {:error, :invalid_entity_type} =
             Annotations.put_annotations("musicbrainz", "tracks", [valid])

    for invalid <- [
          %{"entity_id" => "not-a-uuid", "data" => %{}},
          %{"entity_id" => artist.id},
          %{"entity_id" => artist.id, "data" => ["not", "a", "map"]},
          entry(artist, %{"big" => String.duplicate("x", 4 * 1024)}),
          "entry"
        ] do
      assert {:error, :invalid_entries} =
               Annotations.put_annotations("musicbrainz", "artists", [valid, invalid])
    end

    assert {:error, :too_many_entries} =
             Annotations.put_annotations("musicbrainz", "artists", List.duplicate(valid, 501))

    assert Repo.aggregate(Annotation, :count) == 0
  end

  test "removes the annotations of deleted entities", %{artist: artist, album: album} do
    {:ok, _} =
      Annotations.put_annotations("musicbrainz", "artists", [entry(artist, %{"id" => "a"})])

    {:ok, _} =
      Annotations.put_annotations("musicbrainz", "albums", [entry(album, %{"id" => "b"})])

    Repo.delete!(album)

    assert Annotations.remove_orphaned() == 1
    assert [_artist] = list!("musicbrainz", "artists")
    assert list!("musicbrainz", "albums") == []
  end

  test "is part of removing unused artists and albums", %{artist: artist} do
    {:ok, _} =
      Annotations.put_annotations("musicbrainz", "artists", [entry(artist, %{"id" => "a"})])

    Repo.delete_all(Track)

    Cleanup.Worker.do_step(:unused)

    refute Repo.get(Artist, artist.id)
    assert list!("musicbrainz", "artists") == []
  end
end
