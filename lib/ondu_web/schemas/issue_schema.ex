defmodule OnduWeb.Schemas.Issue do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Issue",
    description: """
    Missing or bad metadata that should be fixed in the source files. Which
    `details` are set depends on the `code`:

    - `artwork_missing`: no artwork found by any of the fetchers
    - `artwork_not_square`: the found artwork is not a perfect square
    - `artwork_low_res`: the found artwork is of low quality
    - `album_missing`: tracks without an album tag ("Unknown Album")
    - `release_year_missing`: the album has no release year
    - `track_number_missing`: `trackIds` of the tracks without a track number
    - `track_number_duplicate`: `numbers` used by more than one track on `disc`
    - `track_number_gap`: `numbers` missing on `disc`, possibly incomplete album?
    - `title_missing`: `trackIds` of the tracks without a title tag
    - `artist_missing`: the track has no artist at all (invisible in library)
    """,
    type: :object,
    additionalProperties: false,
    properties: %{
      code: %Schema{type: :string, enum: Enum.map(Ondu.Issues.codes(), &to_string/1)},
      details: %Schema{
        type: :object,
        additionalProperties: false,
        properties: %{
          width: %Schema{type: :integer, example: 640},
          height: %Schema{type: :integer, example: 571},
          disc: %Schema{type: :integer, example: 1},
          numbers: %Schema{type: :array, items: %Schema{type: :integer}, example: [5]},
          trackIds: %Schema{type: :array, items: OnduWeb.Schemas.TrackId}
        }
      }
    },
    required: [:code, :details]
  })
end

defmodule OnduWeb.Schemas.AlbumIssues do
  @moduledoc false
  require OpenApiSpex
  alias OnduWeb.Schemas
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AlbumIssues",
    description: "An album with one or more issues.",
    type: :object,
    additionalProperties: false,
    properties: %{
      __type: %Schema{type: :string, enum: ["albumIssues"], default: "albumIssues"},
      album: Schemas.FlatAlbum,
      artist: Schemas.Artist,
      issues: %Schema{type: :array, items: Schemas.Issue}
    },
    required: [:__type, :album, :artist, :issues]
  })
end

defmodule OnduWeb.Schemas.TrackIssues do
  @moduledoc false
  require OpenApiSpex
  alias OnduWeb.Schemas
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "TrackIssues",
    description: "A track with one or more issues",
    type: :object,
    additionalProperties: false,
    properties: %{
      __type: %Schema{type: :string, enum: ["trackIssues"], default: "trackIssues"},
      track: %Schema{
        type: :object,
        additionalProperties: false,
        properties: %{
          id: Schemas.TrackId,
          name: %Schema{type: :string, example: "01 Perth.m4a"},
          path: %Schema{
            type: :string,
            description: "Path of the file relative to the music path.",
            example: "Unknown Artist/Unknown Album/01 Perth.m4a"
          }
        },
        required: [:id, :name, :path]
      },
      issues: %Schema{type: :array, items: Schemas.Issue}
    },
    required: [:__type, :track, :issues]
  })
end

defmodule OnduWeb.Schemas.IssueEntry do
  @moduledoc false
  require OpenApiSpex
  alias OnduWeb.Schemas

  OpenApiSpex.schema(%{
    title: "IssueEntry",
    description: "An album or track with issues, the shape depends on `__type`.",
    oneOf: [Schemas.AlbumIssues, Schemas.TrackIssues],
    discriminator: %OpenApiSpex.Discriminator{
      propertyName: "__type",
      mapping: %{
        "albumIssues" => "#/components/schemas/AlbumIssues",
        "trackIssues" => "#/components/schemas/TrackIssues"
      }
    }
  })
end

defmodule OnduWeb.Schemas.IssuePage do
  @moduledoc false
  require OpenApiSpex
  alias OnduWeb.Schemas.{IssueEntry, Page}

  OpenApiSpex.schema(Page.of(IssueEntry, __subtype: "issues", title: "IssuePage"))
end
