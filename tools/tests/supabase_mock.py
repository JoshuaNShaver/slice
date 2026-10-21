#!/usr/bin/env python3
"""A tiny stand-in for Supabase, for the online tests (no Docker needed).

Implements only what the game uses:
  PostgREST: GET/POST/DELETE /rest/v1/families, GET/POST /rest/v1/chests,
        GET/POST /rest/v1/unlocks,
        GET/POST /rest/v1/profiles (409 on a taken name, any case)
  Auth: GET /auth/v1/user, GET /auth/v1/authorize (PKCE, redirects at
        once as if Google said yes), POST /auth/v1/token?grant_type=pkce
        and ?grant_type=refresh_token
  Test controls: POST /_mock/fail?n=N (next N REST calls answer 503),
        GET /_mock/dump (tables, counts, bytes sent)

  python3 tools/tests/supabase_mock.py --port 54321 --secret sb_secret_test

Fake tokens: "good-token-1" and "good-token-2" are two users.
"""
import argparse
import base64
import hashlib
import json
import secrets
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlencode, urlparse

USERS = {
    "good-token-1": {"id": "11111111-1111-4111-8111-111111111111", "email": "one@example.com"},
    "good-token-2": {"id": "22222222-2222-4222-8222-222222222222", "email": "two@example.com"},
}
PUBLISHABLE = "sb_publishable_test"

lock = threading.RLock()
state = {"families": {}, "chests": {}, "unlocks": {}, "profiles": {}, "fail": 0, "requests": 0, "bytes_out": 0, "writes": 0,
         "codes": {}, "refresh": {}}


def eq(qs, name):
    v = qs.get(name, [""])[0]
    return v[3:] if v.startswith("eq.") else None


class Handler(BaseHTTPRequestHandler):
    secret = ""

    def log_message(self, fmt, *args):
        print("mock:", self.command, self.path.split("?")[0], fmt % args if "%" in fmt else "", flush=True)

    def reply(self, code, body=None, headers=None):
        data = b"" if body is None else json.dumps(body).encode()
        self.send_response(code)
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        if data:
            self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
        with lock:
            state["requests"] += 1
            state["bytes_out"] += len(data)

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"null")

    def route(self):
        url = urlparse(self.path)
        qs = parse_qs(url.query)
        if url.path.startswith("/_mock/"):
            return self.control(url.path, qs)
        if url.path.startswith("/rest/v1/"):
            return self.rest(url.path[len("/rest/v1/"):], qs)
        if url.path.startswith("/auth/v1/"):
            return self.auth(url.path[len("/auth/v1/"):], qs)
        self.reply(404, {"message": "no route"})

    do_GET = do_POST = do_DELETE = route

    def control(self, path, qs):
        if path == "/_mock/fail":
            with lock:
                state["fail"] = int(qs.get("n", ["1"])[0])
            return self.reply(200, {"fail": state["fail"]})
        if path == "/_mock/dump":
            with lock:
                dump = {"families": {f"{k[0]}:{k[1]}": v for k, v in state["families"].items()},
                        "chests": state["chests"], "unlocks": state["unlocks"], "profiles": state["profiles"], "requests": state["requests"],
                        "bytes_out": state["bytes_out"], "writes": state["writes"]}
            return self.reply(200, dump)
        self.reply(404, {})

    def rest(self, table, qs):
        if self.headers.get("apikey") != self.secret:
            return self.reply(401, {"message": "Invalid API key"})
        with lock:
            if state["fail"] > 0:
                state["fail"] -= 1
                return self.reply(503, {"message": "mock outage"})
        minimal = "return=minimal" in (self.headers.get("Prefer") or "")
        user = eq(qs, "user_id")
        if table == "families":
            if self.command == "GET":
                with lock:
                    rows = [{"slot": s, "data": v["data"]} for (u, s), v in state["families"].items() if u == user]
                return self.reply(200, rows)
            if self.command == "POST":
                row = self.body()
                with lock:
                    state["families"][(row["user_id"], row["slot"])] = row
                    state["writes"] += 1
                return self.reply(201, None if minimal else [row])
            if self.command == "DELETE":
                with lock:
                    state["families"].pop((user, int(eq(qs, "slot"))), None)
                    state["writes"] += 1
                return self.reply(204)
        if table == "chests":
            if self.command == "GET":
                with lock:
                    rows = [{"items": state["chests"][user]["items"]}] if user in state["chests"] else []
                return self.reply(200, rows)
            if self.command == "POST":
                row = self.body()
                with lock:
                    state["chests"][row["user_id"]] = row
                    state["writes"] += 1
                return self.reply(201, None if minimal else [row])
        if table == "unlocks":
            if self.command == "GET":
                with lock:
                    rows = [{"names": state["unlocks"][user]["names"]}] if user in state["unlocks"] else []
                return self.reply(200, rows)
            if self.command == "POST":
                row = self.body()
                with lock:
                    state["unlocks"][row["user_id"]] = row
                    state["writes"] += 1
                return self.reply(201, None if minimal else [row])
        if table == "profiles":
            if self.command == "GET":
                with lock:
                    rows = [{"username": state["profiles"][user], "role": "player"}] if user in state["profiles"] else []
                return self.reply(200, rows)
            if self.command == "POST":
                row = self.body()
                name = row.get("username", "")
                with lock:
                    taken = row["user_id"] in state["profiles"] or any(
                        n.lower() == name.lower() for n in state["profiles"].values())
                    if not taken:
                        state["profiles"][row["user_id"]] = name
                        state["writes"] += 1
                if taken:
                    return self.reply(409, {"code": "23505", "message": "duplicate key value"})
                return self.reply(201, None if minimal else [row])
        self.reply(404, {"message": "no table"})

    def session(self, user):
        access = "good-token-1" if user["id"] == USERS["good-token-1"]["id"] else "good-token-2"
        refresh = secrets.token_hex(8)
        with lock:
            state["refresh"][refresh] = user
        return {"access_token": access, "token_type": "bearer", "expires_in": 3600,
                "refresh_token": refresh, "user": user}

    def auth(self, path, qs):
        key = self.headers.get("apikey")
        if path == "authorize":  # a browser: no apikey header
            if qs.get("code_challenge_method", [""])[0] != "s256":
                return self.reply(400, {"msg": "PKCE needed"})
            code = secrets.token_hex(8)
            with lock:
                state["codes"][code] = qs["code_challenge"][0]
            target = qs["redirect_to"][0] + "?" + urlencode({"code": code})
            return self.reply(302, None, {"Location": target})
        if key not in (self.secret, PUBLISHABLE):
            return self.reply(401, {"message": "Invalid API key"})
        if path == "user":
            token = (self.headers.get("Authorization") or "").removeprefix("Bearer ")
            if token in USERS:
                return self.reply(200, USERS[token])
            return self.reply(401, {"msg": "invalid JWT: unable to parse or verify signature"})
        if path == "token":
            grant = qs.get("grant_type", [""])[0]
            body = self.body() or {}
            if grant == "pkce":
                with lock:
                    challenge = state["codes"].pop(body.get("auth_code"), None)
                digest = hashlib.sha256((body.get("code_verifier") or "").encode()).digest()
                mine = base64.urlsafe_b64encode(digest).decode().rstrip("=")
                if challenge is None or challenge != mine:
                    return self.reply(400, {"error_description": "invalid flow state or code verifier"})
                return self.reply(200, self.session(USERS["good-token-1"]))
            if grant == "refresh_token":
                with lock:
                    user = state["refresh"].pop(body.get("refresh_token"), None)
                if user is None:
                    return self.reply(400, {"error_description": "Invalid Refresh Token"})
                return self.reply(200, self.session(user))
        self.reply(404, {"msg": "no route"})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=54321)
    ap.add_argument("--secret", default="sb_secret_test")
    args = ap.parse_args()
    Handler.secret = args.secret
    print(f"mock Supabase on http://127.0.0.1:{args.port}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
