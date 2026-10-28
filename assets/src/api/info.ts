import type { ServerInfo } from "../types";
import { client, type RequestOptions } from "./client";

export const infoApi = {
  getInfo(opts?: RequestOptions) {
    return client.get<undefined, ServerInfo>("/info", opts);
  },
};
