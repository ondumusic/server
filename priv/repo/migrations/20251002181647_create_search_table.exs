defmodule MusicBox.Repo.Migrations.CreateSearchTable do
  use Ecto.Migration

  def up do
    execute """
    create virtual table search using fts5(
      track_id unindexed,
      artist_id unindexed,
      album_id unindexed,
      file_id unindexed,
      artist_name,
      album_name,
      track_name,
      tokenize='unicode61 remove_diacritics 2'
    )
    """

    # Backfill
    execute """
    insert into search (
      file_id,
      track_id,
      artist_id,
      album_id,
      artist_name,
      album_name,
      track_name
    )
    select
      t.file_id as file_id,
      t.id as track_id,
      ar.id as artist_id,
      al.id as album_id,
      ar.name as artist_name,
      al.name as album_name,
      t.name as track_name
    from tracks t
    left join albums al on al.id = t.album_id
    left join artists ar on ar.id = t.artist_id or ar.id = al.artist_id
    """

    # Trigger for track insert (this happens after artist/album so then
    # all data should be available already. At file insert this data is
    # not yet persisted to database so will be a lot of nulls)
    execute """
    create trigger tracks_after_insert after insert on tracks begin
      insert into search (
        file_id,
        track_id,
        artist_id,
        album_id,
        artist_name,
        album_name,
        track_name
      )
      select
        t.file_id as file_id,
        t.id as track_id,
        ar.id as artist_id,
        al.id as album_id,
        ar.name as artist_name,
        al.name as album_name,
        t.name as track_name
      from tracks t
      left join albums al on al.id = t.album_id
      left join artists ar on ar.id = t.artist_id or ar.id = al.artist_id
      where t.id = new.id;
    end;
    """

    # Currently only updates are done when the filescanner does a full scan,
    # but probably in the future we need to have more triggers and/or just
    # move the logic to the codebase.
    execute """
    create trigger files_after_update after update on files begin
      update search
      set
        file_id = f.id,
        track_id = t.id,
        artist_id = ar.id,
        album_id = al.id,
        artist_name = ar.name,
        album_name = al.name,
        track_name = t.name
      from files f
      left join tracks t on t.file_id = f.id
      left join albums al on al.id = t.album_id
      left join artists ar on ar.id = t.artist_id or ar.id = al.artist_id
      where search.file_id = new.id;
    end;
    """

    # Since we are file driven deleting a file should delete the search entry.
    execute """
    create trigger files_after_delete after delete on files begin
      delete from search where file_id = old.id;
    end;
    """
  end

  def down do
    execute("drop trigger if exists tracks_after_insert;")
    execute("drop trigger if exists files_after_update;")
    execute("drop trigger if exists files_after_delete;")
    execute "drop table if exists search"
  end
end
