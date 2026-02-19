defmodule MusicBox.Repo.Migrations.CreateNewSearchTables do
  use Ecto.Migration

  def up do
    execute "drop table if exists search;"

    execute """
      create virtual table artists_fts using fts5(
          name,
          slug,
          content=artists,
          content_rowid=rowid,
          tokenize='unicode61 remove_diacritics 2'
      );
    """

    execute """
      create virtual table albums_fts using fts5(
          name,
          slug,
          content=albums,
          content_rowid=rowid,
          tokenize='unicode61 remove_diacritics 2'
      );
    """

    execute """
      create virtual table tracks_fts using fts5(
          name,
          slug,
          content=tracks,
          content_rowid=rowid,
          tokenize='unicode61 remove_diacritics 2'
      );
    """

    execute "insert into artists_fts(artists_fts) values('rebuild');"
    execute "insert into albums_fts(albums_fts) values('rebuild');"
    execute "insert into tracks_fts(tracks_fts) values('rebuild');"
  end

  def down do
    execute "drop table if exists artists_fts;"
    execute "drop table if exists albums_fts;"
    execute "drop table if exists tracks_fts;"
  end
end
