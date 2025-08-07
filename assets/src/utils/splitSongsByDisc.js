export function splitSongsByDisc(songs) {
  const discs = songs.reduce((result, song) => {
    if (!(song.disc in result)) result[song.disc] = [];
    result[song.disc].push(song);
    return result;
  }, {});

  return Object.keys(discs).map((n) => ({ number: n, songs: discs[n] }));
}
