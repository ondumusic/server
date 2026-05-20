import { client, type RequestOptions } from "./client";

interface UpdatePasswordRequest {
  password: string;
  passwordConfirmation: string;
  currentPassword: string;
}

type UpdatePasswordResult =
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
    };

export const userApi = {
  updatePassword(params: UpdatePasswordRequest, opts?: RequestOptions) {
    return client.patch<UpdatePasswordRequest, UpdatePasswordResult>(
      "/user/password",
      params,
      opts,
    );
  },
};
