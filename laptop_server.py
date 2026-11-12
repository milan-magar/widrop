#!/usr/bin/env python3
"""
Simple Laptop Server for WiDrop Link Sender
Listens on all local network interfaces (0.0.0.0) at port 8080.
Receives { link, deviceName, folder, timestamp } and handles it.
Requires Python 3. No external pip install required!
"""

import http.server
import json
import os
import sys
import webbrowser
from datetime import datetime

PORT = 8080
BASE_DIR = os.path.expanduser("~/Downloads/WiDrop")

class LinkReceiverHandler(http.server.BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Accept")

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        """Health check endpoint"""
        self.send_response(200)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        response = {
            "status": "online",
            "server": "WiDrop Laptop Server",
            "port": PORT,
            "time": datetime.now().isoformat()
        }
        self.wfile.write(json.dumps(response).encode("utf-8"))

    def do_POST(self):
        """Receives link, deviceName, and folder from Flutter app"""
        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length).decode("utf-8")

        try:
            payload = json.loads(post_data)
            link = payload.get("link", "")
            device = payload.get("deviceName", "Unknown Device")
            folder = payload.get("folder", "Downloads")
            ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

            print("\n" + "=" * 55)
            print(f"📥 NEW LINK RECEIVED at {ts}")
            print(f"📱 From Device : {device}")
            print(f"🔗 Link        : {link}")
            print(f"📁 Target Dir  : {folder}")
            print("=" * 55)

            # Create destination folder if specified
            target_path = os.path.expanduser(f"~/{folder}")
            try:
                os.makedirs(target_path, exist_ok=True)
                log_file = os.path.join(target_path, "received_links.txt")
                with open(log_file, "a", encoding="utf-8") as f:
                    f.write(f"[{ts}] ({device}) {link}\n")
                print(f"💾 Appended to {log_file}")
            except Exception as fe:
                print(f"⚠️  Folder log notice: {fe}")

            # Send success response back to Flutter app
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            
            res = {
                "status": "success",
                "message": f"Link received by laptop from {device}!",
                "savedIn": folder,
                "link": link
            }
            self.wfile.write(json.dumps(res).encode("utf-8"))

        except Exception as e:
            print(f"❌ Error processing payload: {e}")
            self.send_response(400)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "error", "message": str(e)}).encode("utf-8"))

if __name__ == "__main__":
    server_address = ("0.0.0.0", PORT)
    httpd = http.server.HTTPServer(server_address, LinkReceiverHandler)
    print("=" * 60)
    print(f"🚀 WiDrop Laptop Server running on PORT {PORT} (0.0.0.0)")
    print(f"📡 Ready to receive links from Flutter app on the same Wi-Fi!")
    print("Press Ctrl+C to stop.")
    print("=" * 60)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Server stopped.")
        sys.exit(0)
