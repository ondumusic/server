import type { User } from "../types";
import { client, type RequestOptions } from "./client";
import { queryClient } from "./queryClient";

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

type PlayTokenResult =
  | {
      ok: false;
    }
  | {
      ok: true;
      playToken: string;
    };

export const authQueries = {
  getPlayToken() {
    return {
      queryKey: ["playToken"],
      queryFn: ({ signal }: { signal?: AbortSignal }) =>
        client.get<undefined, PlayTokenResult>(`/auth/playtoken`, { signal }),
    };
  },
};

export const authApi = {
  login(username?: string, password?: string, opts?: RequestOptions) {
    return client.post<
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

  getPlayToken() {
    return queryClient.ensureQueryData<PlayTokenResult>(
      authQueries.getPlayToken(),
    );
  },
};
