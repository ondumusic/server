import { faker } from "@faker-js/faker";
import { artistFactory } from "@test/factory/artistFactory";
import { trackFactory } from "@test/factory/trackFactory";
import { type DeepPartial, Factory } from "fishery";
import type { Album, Artist, Track } from "@/types";

type AlbumParams = DeepPartial<Album> & {
  artist?: Artist;
  tracks?: Track[];
};

// biome-ignore lint/complexity/noBannedTypes: its what fishery docs said
export const albumFactory = Factory.define<Album, {}, Album, AlbumParams>(
  ({ params }) => {
    const albumId = faker.string.uuid();
    const artist = params.artist || artistFactory.build();
    const trackCount = faker.number.int({ min: 1, max: 20 });
    const tracks =
      params.tracks || trackFactory.buildList(trackCount, { albumId, artist });

    return {
      __type: "album",
      id: albumId,
      name: faker.lorem.sentence({ min: 1, max: 10 }),
      artistId: artist.id,
      releaseYear: faker.date
        .birthdate({ mode: "age", min: 0, max: 30 })
        .getFullYear(),
      isUnknown: faker.datatype.boolean(0.9),
      tracks,
    };
  },
);
