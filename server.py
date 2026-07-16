import os, sys, json, base64, datetime
from http.server import HTTPServer, BaseHTTPRequestHandler

UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "uploads")
WWW_DIR = os.path.join(os.path.dirname(__file__), "www")
MAX_MB = int(os.environ.get("MAX_FILE_SIZE", "500"))

def list_files():
    files = []
    if os.path.isdir(UPLOAD_DIR):
        for f in os.listdir(UPLOAD_DIR):
            fp = os.path.join(UPLOAD_DIR, f)
            if os.path.isfile(fp):
                size = os.path.getsize(fp)
                mtime = datetime.datetime.fromtimestamp(os.path.getmtime(fp)).strftime("%m-%d %H:%M")
                files.append({"name": f, "size": size, "time": mtime})
    files.sort(key=lambda x: x["time"], reverse=True)
    return files

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        t = datetime.datetime.now().strftime("%H:%M:%S")
        print(t, a[1], a[2], "-", self.client_address[0])

    def _header(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")

    def _json(self, code, obj):
        self.send_response(code)
        self._header()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(obj).encode())

    def do_OPTIONS(self):
        self.send_response(200)
        self._header()
        self.end_headers()

    def do_GET(self):
        if self.path.startswith("/download/"):
            name = self.path[len("/download/"):]
            fp = os.path.join(UPLOAD_DIR, name)
            if not os.path.realpath(fp).startswith(os.path.realpath(UPLOAD_DIR)):
                self.send_error(403); return
            if os.path.isfile(fp):
                self.send_response(200)
                self._header()
                self.send_header("Content-Disposition", 'attachment; filename="' + name + '"')
                self.end_headers()
                with open(fp, "rb") as f:
                    self.wfile.write(f.read())
                return
        if self.path == "/files":
            return self._json(200, {"files": list_files()})
        fp = os.path.join(WWW_DIR, "index.html")
        if not os.path.isfile(fp):
            self.send_error(404); return
        self.send_response(200)
        self._header()
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        with open(fp, "rb") as f:
            self.wfile.write(f.read())

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        d = json.loads(raw.decode())
        data = base64.b64decode(d.get("fileData", ""))
        if len(data) > MAX_MB * 1048576:
            return self._json(413, {"success": False, "message": "文件太大"})
        name = d.get("filename", "file")
        if not os.path.isdir(UPLOAD_DIR):
            os.makedirs(UPLOAD_DIR)
        safe = name
        fp = os.path.join(UPLOAD_DIR, safe)
        n = 1
        while os.path.exists(fp):
            p = name.rfind(".")
            if p > 0:
                safe = name[:p] + "_" + str(n) + name[p:]
            else:
                safe = name + "_" + str(n)
            fp = os.path.join(UPLOAD_DIR, safe)
            n += 1
        with open(fp, "wb") as f:
            f.write(data)
        print("Saved:", safe, "(" + str(len(data)) + " bytes)")
        self._json(200, {"success": True, "message": "上传成功！可在文件列表下载", "file": safe})

port = int(os.environ.get("PORT", 8080))
s = HTTPServer(("0.0.0.0", port), Handler)
print("Server ready on port", port)
s.serve_forever()
