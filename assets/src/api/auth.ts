import type { User } from "../types";
import { client, type RequestOptions } from "./client";

type LoginResult =
  | {
      ok: false;
      fields: {
        [key: string]: {
          message: string;
        };
      };
    }
  | {
      ok: true;
      currentUser: User;
      sessionToken: string;
    };

export const authApi = {
  async login(username?: string, password?: string, opts?: RequestOptions) {
    return await client.post<
      {
        username?: string;
        password?: string;
      },
      LoginResult
    >(
      "/auth/login",
      {
        username,
        password,
      },
      opts,
    );
  },
};
