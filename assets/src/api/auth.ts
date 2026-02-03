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

type SignupResult =
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
  getCurrentUser() {
    return {
      queryKey: ["currentUser"],
      queryFn: ({ signal }: { signal?: AbortSignal }) =>
        client.get<undefined, User>(`/auth/me`, { signal }),
    };
  },

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

  signup(
    username?: string,
    password?: string,
    password_confirmation?: string,
    opts?: RequestOptions,
  ) {
    return client.post<
      {
        username?: string;
        password?: string;
        password_confirmation?: string;
      },
      SignupResult
    >(
      "/auth/signup",
      {
        username,
        password,
        password_confirmation,
      },
      opts,
    );
  },

  getCurrentUser() {
    return queryClient.ensureQueryData<User>(authQueries.getCurrentUser());
  },

  getPlayToken() {
    return queryClient.ensureQueryData<PlayTokenResult>(
      authQueries.getPlayToken(),
    );
  },
};
