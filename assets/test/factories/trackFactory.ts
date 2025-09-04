import { faker } from "@faker-js/faker";
import { artistFactory } from "@test/factory/artistFactory";
import { type DeepPartial, Factory } from "fishery";
import type { Album, Artist, Track, UUID } from "@/types";

type TrackParams = DeepPartial<Track> & {
  artist?: Artist;
  album?: Album;
  albumId?: UUID;
};

// biome-ignore lint/complexity/noBannedTypes: its what fishery docs said
export const trackFactory = Factory.define<Track, {}, Track, TrackParams>(
  ({ sequence, params }) => {
    const artist = params.artist || artistFactory.build();
    const albumId = params.albumId || faker.string.uuid();

    return {
      __type: "track",
      id: faker.string.uuid(),
      artist,
      artistId: artist.id,
      albumArtistId: artist.id,
      albumId,
      name: faker.lorem.sentence({ min: 1, max: 10 }),
      duration: faker.number.float({ min: 5, max: 600 }),
      number: sequence,
      disc: 1,
      mimetype: "audio/mp4",
      streamUrl: faker.internet.url(),
    };
  },
);
