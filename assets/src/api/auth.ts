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

  getCurrentUser(opts?: RequestOptions) {
    return client.get<undefined, User>(`/auth/me`, opts);
  },

  getPlayToken(opts?: RequestOptions) {
    return client.get<undefined, PlayTokenResult>(`/auth/playtoken`, opts);
  },
};
