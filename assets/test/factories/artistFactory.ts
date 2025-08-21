import { faker } from "@faker-js/faker";
import { Factory } from "fishery";
import type { Artist } from "@/types";

export const artistFactory = Factory.define<Artist>(({ params }) => {
  const name = params.name || faker.lorem.sentence({ min: 1, max: 4 });

  return {
    __type: "artist",
    id: faker.string.uuid(),
    name,
    slug: faker.helpers.slugify(name.toLowerCase().replace(/\./g, "")),
    albumCount: faker.number.int({ max: 20 }),
  };
});
