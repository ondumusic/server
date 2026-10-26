# Minimal test server: serves ./assets with Range support (like a finished cache
# file), or with ?chunked=1 as a chunked response without Content-Length (like a
# live transcode), optionally throttled with ?kbps=N to mimic a slow encoder.
# ?live=N simulates a transcode in progress: the file becomes available at N bytes
# per second from the moment it is first asked for, and a request waits for the
# bytes it needs, as the real server does; ?tail=M makes the last M bytes
# available from the start, like the server's early tail.
import http.server, os, sys, time, urllib.parse, re
LIVE = {}
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets")
MIME = {".m4a":"audio/mp4",".mp4":"audio/mp4",".aac":"audio/aac",".opus":"audio/ogg",".webm":"audio/webm",".flac":"audio/flac",".wav":"audio/wav",".m3u8":"application/vnd.apple.mpegurl",".html":"text/html",".m4s":"video/iso.segment"}
class H(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, f, *a): sys.stderr.write("%s %s\n" % (self.command, self.path if '?' not in self.path else self.path) + ("   range=%s\n" % self.headers.get("Range") if self.headers.get("Range") else ""))
    def do_HEAD(self): self.do_GET(head=True)
    def do_GET(self, head=False):
        u = urllib.parse.urlparse(self.path); q = urllib.parse.parse_qs(u.query)
        p = os.path.normpath(os.path.join(ROOT, u.path.lstrip("/")))
        if not p.startswith(ROOT) or not os.path.isfile(p): self.send_error(404); return
        data = open(p, "rb").read(); size = len(data)
        ctype = MIME.get(os.path.splitext(p)[1], "application/octet-stream")
        kbps = int(q.get("kbps", ["0"])[0])
        if q.get("chunked") == ["1"]:
            self.send_response(200); self.send_header("Content-Type", ctype)
            self.send_header("Transfer-Encoding", "chunked"); self.send_header("Accept-Ranges", "none"); self.end_headers()
            if head: return
            for i in range(0, size, 16384):
                part = data[i:i+16384]
                try: self.wfile.write(b"%x\r\n%s\r\n" % (len(part), part))
                except BrokenPipeError: return
                if kbps: time.sleep(len(part)*8/1000/kbps)
            self.wfile.write(b"0\r\n\r\n"); return
        start, end = 0, size-1; status = 200
        m = re.match(r"bytes=(\d*)-(\d*)", self.headers.get("Range", "") or "")
        if m:
            if m.group(1): start = int(m.group(1)); end = int(m.group(2)) if m.group(2) else size-1
            else: start = size-int(m.group(2))
            end = min(end, size-1)
            if start >= size: self.send_response(416); self.send_header("Content-Range", "bytes */%d" % size); self.end_headers(); return
            status = 206
        self.send_response(status); self.send_header("Content-Type", ctype); self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(end-start+1))
        if status == 206: self.send_header("Content-Range", "bytes %d-%d/%d" % (start, end, size))
        self.end_headers()
        if head: return
        body = data[start:end+1]
        live = int(q.get("live", ["0"])[0]); tail = int(q.get("tail", ["0"])[0])
        if live: began = LIVE.setdefault(p, time.time())
        for i in range(0, len(body), 16384):
            if live:
                # wait until this piece is "encoded", unless it lies in the early tail
                piece_end = start + i + min(16384, len(body) - i)
                while piece_end > min(size, (time.time() - began) * live) and piece_end <= size - tail:
                    time.sleep(0.05)
            try: self.wfile.write(body[i:i+16384])
            except BrokenPipeError: return
            if kbps: time.sleep(16384*8/1000/kbps)
http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1]) if len(sys.argv) > 1 else 8765), H).serve_forever()
