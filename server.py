#!/usr/bin/env python3
import os, sys, json, base64, smtplib, mimetypes, email.encoders
from http.server import HTTPServer, BaseHTTPRequestHandler
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email.mime.text import MIMEText
from email.utils import formatdate
from datetime import datetime

DIR = os.path.dirname(os.path.abspath(__file__))
CFG = os.path.join(DIR, "config.json")
WWW = os.path.join(DIR, "www")

def load_config():
    d = {"smtpServer":"smtp.163.com","smtpPort":25,"smtpUseSSL":False,"smtpUsername":"youthofnua@163.com","smtpPassword":"","targetEmail":"youthofnua@163.com","maxFileSizeMB":25}
    try:
        with open(CFG, encoding="utf-8-sig") as f: c = json.load(f)
        for k in d:
            if k not in c: c[k] = d[k]
        return c
    except FileNotFoundError:
        with open(CFG,"w") as f: json.dump(d,f,indent=2)
        print(f"Config created at {CFG}\nEdit smtpPassword and run again."); sys.exit(1)

def send_email(cfg, data, name, ctype):
    msg = MIMEMultipart()
    msg["From"] = cfg["smtpUsername"]; msg["To"] = cfg["targetEmail"]
    msg["Subject"] = f"[Upload] {name}"; msg["Date"] = formatdate(localtime=True)
    msg.attach(MIMEText(f"File: {name}\nSize: {len(data)/1024:.1f} KB\nTime: {datetime.now()}\n---\nSent by upload server","plain","utf-8"))
    p = MIMEBase("application","octet-stream"); p.set_payload(data)
    email.encoders.encode_base64(p); p.add_header("Content-Disposition",f'attachment; filename="{name}"')
    msg.attach(p)
    try:
        if cfg["smtpPort"]==465:
            s = smtplib.SMTP_SSL(cfg["smtpServer"],cfg["smtpPort"],timeout=10)
        else:
            s = smtplib.SMTP(cfg["smtpServer"],cfg["smtpPort"],timeout=10)
            if cfg["smtpUseSSL"]: s.starttls()
        s.login(cfg["smtpUsername"],cfg["smtpPassword"]); s.send_message(msg); s.quit()
        return True
    except Exception as e: print("Email error:", e); return False

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): print(f"[{datetime.now().strftime('%H:%M:%S')}] {a[1]} {a[2]} - {self.client_address[0]}")
    def do_GET(self):
        p = self.path.rstrip("/") or "/"
        if p == "/config":
            self.send_response(200); self.send_header("Content-Type","application/json"); self.send_header("Access-Control-Allow-Origin","*"); self.end_headers()
            self.wfile.write(json.dumps({"maxFileSizeMB":self.server.cfg["maxFileSizeMB"]}).encode()); return
        fp = os.path.join(WWW, p.lstrip("/") if p != "/" else "index.html")
        if not os.path.realpath(fp).startswith(os.path.realpath(WWW)): self.send_error(403); return
        if os.path.isfile(fp):
            ct,_ = mimetypes.guess_type(fp)
            if not ct: ct = "application/octet-stream"
            if "text" in ct: ct += "; charset=utf-8"
            self.send_response(200); self.send_header("Content-Type",ct); self.send_header("Access-Control-Allow-Origin","*"); self.end_headers()
            with open(fp,"rb") as f: self.wfile.write(f.read())
        else: self.send_error(404)
    def do_POST(self):
        if self.path != "/upload": self.send_error(404); return
        d = json.loads(self.rfile.read(int(self.headers.get("Content-Length",0))).decode())
        fb = base64.b64decode(d.get("fileData",""))
        if len(fb) > self.server.cfg["maxFileSizeMB"]*1048576: self.send_json(413,{"error":"Too large"}); return
        print(f"  Received: {d.get('filename','')} ({len(fb)} bytes)")
        ok = send_email(self.server.cfg, fb, d.get("filename",""), d.get("contentType",""))
        print(f"  {'Sent!' if ok else 'Failed'}")
        self.send_json(200, {"success":ok,"message":"Sent!" if ok else "Failed"})
    def send_json(self, code, obj):
        self.send_response(code); self.send_header("Content-Type","application/json"); self.send_header("Access-Control-Allow-Origin","*"); self.end_headers()
        self.wfile.write(json.dumps(obj).encode())

c = load_config()
if not c.get("smtpPassword"): print("Edit config.json first!"); sys.exit(1)
port = int(os.environ.get("PORT", 8080))
s = HTTPServer(("0.0.0.0",port), H); s.cfg = c
print("Server started on port", port); s.serve_forever()
