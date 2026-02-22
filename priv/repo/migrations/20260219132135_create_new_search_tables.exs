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
      create view albums_fts_content as
          select
            al.rowid, al.name, al.slug,
            a.name as artist_name,
            a.slug as artist_slug
          from albums al
          left join artists a on a.id = al.artist_id;
    """

    execute """
      create virtual table albums_fts using fts5(
          name,
          slug,
          artist_name,
          artist_slug,
          content=albums_fts_content,
          content_rowid=rowid,
          tokenize='unicode61 remove_diacritics 2'
      );
    """

    execute """
      create view tracks_fts_content as
          select
            t.rowid, t.name, t.slug,
            al.name as album_name,
            al.slug as album_slug,
            a.name as artist_name,
            a.slug as artist_slug,
            a2.name as album_artist_name,
            a2.slug as album_artist_slug
          from tracks t
          left join albums al on al.id = t.album_id
          left join artists a on a.id = t.artist_id
          left join artists a2 on a2.id = al.artist_id;
    """

    execute """
      create virtual table tracks_fts using fts5(
          name,
          slug,
          artist_name,
          artist_slug,
          album_name,
          album_slug,
          album_artist_name,
          album_artist_slug,
          content=tracks_fts_content,
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
    execute "drop view if exists albums_fts_content;"
    execute "drop view if exists tracks_fts_content;"
  end
end
