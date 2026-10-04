import { client, type RequestOptions } from "./client";

export type Notice = {
  id: string;
  code: string;
  level: "info" | "warning";
  message: string;
  raisedAt: string;
};

export const noticeApi = {
  dismiss(id: string, opts?: RequestOptions) {
    return client.post<undefined, { notices: Notice[] }>(
      `/notices/${id}/dismiss`,
      undefined,
      opts,
    );
  },
};
