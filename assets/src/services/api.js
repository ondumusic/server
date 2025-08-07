class APIClient {
  #baseURL = "/api";

  constructor(opts) {
    this.#baseURL = (opts.baseURL || this.#baseURL).replace(/\/$/, "");
  }

  get(path, search = {}) {
    return this.#request("GET", path, search);
  }

  #request(method, path, search) {
    if (path[0] !== "/") path = `/${path}`;
    const requestPath = this.#baseURL + path;
    const url = new URL(requestPath, window.location.href);
    url.search = new URLSearchParams(search).toString();

    return fetch(url.toString(), {
      method,
      credentials: "omit",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
      },
    }).then((res) => res.json());
  }
}

export const api = new APIClient({
  baseURL: "/api",
});
