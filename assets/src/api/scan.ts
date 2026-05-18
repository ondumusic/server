import { client, type RequestOptions } from "./client";

type ScanResponse = {
  ok: true;
};

export const scanApi = {
  startScanner(opts?: RequestOptions) {
    return client.post<undefined, ScanResponse>("/scan", undefined, opts);
  },
};
