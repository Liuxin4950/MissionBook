# -*- coding: utf-8 -*-
"""
重庆移通学院「智慧教务」课表抓取 · 单文件可直接运行版
=====================================================

特点：
  * 纯后端，无需浏览器 / 无需 CDP
  * 自带 AES 解密（CryptoJS 格式）与 CAS 密码加密，不依赖外部 openssl.exe
  * 凭证仅从参数 / 环境变量读取，不在仓库内嵌
  * 抓完自动调用工作区 build.py 解析，并分发到 D:\\xiaoai-bridge\\data
  * 不落盘明文密码、不落盘 token

用法（默认全流程：抓取 -> 解析 -> 分发）：
    python cqyt_timetable.py
    python cqyt_timetable.py --no-build        # 只抓原始数据，不解析
    python cqyt_timetable.py --raw out.json    # 指定原始数据输出路径

依赖：
    pip install requests cryptography
    （cryptography 缺失时会自动回退调用系统 openssl）

链路（8 步，2026-10 实测可用）：
    1) AES 解出学号/密码
    2) WebVPN /api/access/authentication/list 取 CAS 认证方式 externalId
    3) CAS GET /authserver/login 取 pwdEncryptSalt + execution
    4) CAS POST 表单（AES-128-CBC 加密密码）-> 302 里拿 ticket
    5) WebVPN POST /api/access/auth/finish 用 ticket 换会话
    6) zhjw GET /authserver/casLogin 预热 authserver 会话（不能省！）
    7) zhjw /authserver/oauth/authorize 取 code -> /oauth/token 换 access_token
    8) 业务接口取课表 -> 写 raw_dump.json -> 调 build.py
"""

from __future__ import annotations

import argparse
import base64
import datetime
import hashlib
import json
import os
import random
import re
import shutil
import subprocess
import sys
from urllib.parse import parse_qs, quote, urlparse

import requests

# ============================ 配置区 ============================

# 凭证从 CQYT_CIPHER_USER / CQYT_CIPHER_PASS / CQYT_AES_KEY 或命令行读取。
CIPHER_USER = ""
CIPHER_PASS = ""
AES_KEY = ""

# 站点
VPN_BASE = "https://vpn.cqytxy.edu.cn"
CAS_BASE = "https://ids.cqytxy.edu.cn"
APP_BASE = "https://zhjw.cqytxy.edu.cn"

# 前端硬编码的 OAuth 客户端
CLIENT_ID = "personal-prod"
CLIENT_SECRET = "app-a-1234"
# ⚠️ redirect_uri 必须是已注册值 token-index；用 /workspace/cas 会 400 invalid_grant
REDIRECT_URI = APP_BASE + "/workspace/token-index"
CAS_WARMUP = APP_BASE + "/workspace/cas"

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36 Edg/140.0.0.0")

# CAS 加密用的随机字符表（与 wisedu encrypt.js 一致）
CHARS = "ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678"

WORKDIR = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(WORKDIR, "output")
DEFAULT_RAW = os.path.join(OUT_DIR, "raw_dump.json")
BUILD_PY = os.path.join(WORKDIR, "build.py")
PUBLISH_DIR = os.environ.get("TT_PUBLISH_DIR") or r"D:\xiaoai-bridge\data"

TIMEOUT = 30


def log(*a):
    print(*a, flush=True)


# ============================ AES 工具 ============================
# 说明：CryptoJS 的 AES 密文格式为 base64("Salted__" + salt(8) + ciphertext)，
#       key/iv 由 EVP_BytesToKey(MD5, 无迭代) 从 (password, salt) 派生。

def _evp_bytes_to_key(password: bytes, salt: bytes, key_len: int = 32, iv_len: int = 16):
    """OpenSSL EVP_BytesToKey（MD5，1 轮），返回 (key, iv)。"""
    d, prev = b"", b""
    while len(d) < key_len + iv_len:
        prev = hashlib.md5(prev + password + salt).digest()
        d += prev
    return d[:key_len], d[key_len:key_len + iv_len]


def _pkcs7_unpad(data: bytes, block: int = 16) -> bytes:
    if not data:
        raise ValueError("密文为空")
    n = data[-1]
    if n < 1 or n > block or data[-n:] != bytes([n]) * n:
        raise ValueError("PKCS7 填充非法")
    return data[:-n]


def _pkcs7_pad(data: bytes, block: int = 16) -> bytes:
    n = block - len(data) % block
    return data + bytes([n]) * n


# --- 优先 cryptography，其次系统 openssl ---
try:
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

    _HAS_CRYPTO = True
except Exception:  # pragma: no cover
    _HAS_CRYPTO = False


def _find_openssl() -> str | None:
    for p in (
        shutil.which("openssl"),
        r"D:\software\workBuddy\WorkBuddyAI\resources\vendor\PortableGit\usr\bin\openssl.exe",
        r"C:\Program Files\Git\usr\bin\openssl.exe",
    ):
        if p and os.path.exists(p):
            return p
    return None


def _aes_cbc(key: bytes, iv: bytes, data: bytes, encrypt: bool) -> bytes:
    """AES-CBC 加/解密（PKCS7 填充）。cryptography 优先，否则回退 openssl。"""
    if _HAS_CRYPTO:
        if encrypt:
            data = _pkcs7_pad(data)
            c = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
            return c.update(data) + c.finalize()
        c = Cipher(algorithms.AES(key), modes.CBC(iv)).decryptor()
        return _pkcs7_unpad(c.update(data) + c.finalize())

    ossl = _find_openssl()
    if not ossl:
        raise RuntimeError("缺少 cryptography 且未找到 openssl，请先 pip install cryptography")
    args = [ossl, "enc", "-aes-%d-cbc" % (len(key) * 8), "-K", key.hex(), "-iv", iv.hex()]
    stdin = data
    if not encrypt:
        args += ["-d", "-a", "-A"]
        stdin = base64.b64encode(data)
    p = subprocess.run(args, input=stdin, capture_output=True)
    if p.returncode != 0:
        raise RuntimeError("openssl 失败: %s" % p.stderr.decode(errors="ignore")[:200])
    return p.stdout


def decrypt_credential(cipher_b64: str, password: str = AES_KEY) -> str:
    """解密 CryptoJS AES 密文（Salted__ 格式）。"""
    raw = base64.b64decode(cipher_b64)
    if raw[:8] != b"Salted__":
        raise ValueError("不是 CryptoJS Salted__ 格式")
    salt, body = raw[8:16], raw[16:]
    key, iv = _evp_bytes_to_key(password.encode(), salt)
    if _HAS_CRYPTO:
        c = Cipher(algorithms.AES(key), modes.CBC(iv)).decryptor()
        return _pkcs7_unpad(c.update(body) + c.finalize()).decode("utf-8")
    ossl = _find_openssl()
    if not ossl:
        raise RuntimeError("缺少 cryptography 且未找到 openssl")
    p = subprocess.run([ossl, "enc", "-d", "-aes-256-cbc", "-md", "md5", "-a", "-A",
                        "-k", password], input=cipher_b64.encode(), capture_output=True)
    if p.returncode != 0 or not p.stdout:
        raise RuntimeError("解密失败: %s" % p.stderr.decode(errors="ignore")[:200])
    return p.stdout.decode("utf-8")


def _rnd(n: int) -> str:
    return "".join(random.choice(CHARS) for _ in range(n))


def cas_encrypt(password: str, salt: str) -> str:
    """复刻 wisedu encrypt.js：AES-128-CBC / PKCS7 / key=salt(16B) / iv=随机16 / 明文=random64+密码。"""
    iv = _rnd(16).encode()
    plain = (_rnd(64) + password).encode("utf-8")
    cipher = _aes_cbc(salt.strip().encode()[:16], iv, plain, encrypt=True)
    return base64.b64encode(cipher).decode()


# ============================ 登录 ============================

def webvpn_login(user: str, pwd: str) -> tuple[requests.Session, str]:
    """走 WebVPN -> CAS，返回已带 webvpn-token 的会话。"""
    s = requests.Session()
    s.headers.update({"User-Agent": UA, "Accept-Language": "zh-CN,zh;q=0.9"})

    r = s.get(VPN_BASE + "/api/access/authentication/list", timeout=TIMEOUT,
              headers={"Accept": "application/json"})
    r.raise_for_status()
    methods = r.json()["data"]["list"]
    cas = [m for m in methods if m.get("authType") == 4]
    if not cas:
        raise RuntimeError("未找到 CAS 认证方式：%s" % methods)
    ext_id = cas[0]["externalId"]
    service = "%s/callback/cas/%s" % (VPN_BASE, ext_id)

    r = s.get(CAS_BASE + "/authserver/login", params={"service": service}, timeout=TIMEOUT)
    m_salt = re.search(r'id="pwdEncryptSalt"\s+value="([^"]*)"', r.text)
    m_exec = re.search(r'id="execution"\s+name="execution"\s+value="([^"]*)"', r.text)
    if not m_salt or not m_exec:
        raise RuntimeError("CAS 登录页结构变化，未取到 pwdEncryptSalt / execution")
    salt = m_salt.group(1)

    form = {
        "username": user,
        "password": cas_encrypt(pwd, salt),
        "captcha": "",
        "_eventId": "submit",
        "cllt": "userNameLogin",
        "dllt": "generalLogin",
        "lt": "",
        "execution": m_exec.group(1),
        "rmShown": "1",
    }
    r = s.post(CAS_BASE + "/authserver/login", params={"service": service}, data=form,
               timeout=TIMEOUT, allow_redirects=False,
               headers={"Referer": CAS_BASE + "/authserver/login?service=" + service,
                        "Origin": CAS_BASE})
    m = re.search(r"[?&]ticket=([^&]+)", r.headers.get("Location", ""))
    if not m:
        raise RuntimeError("CAS 登录失败：未拿到 ticket（status=%s）" % r.status_code)
    ticket = m.group(1)

    payload = {"externalId": ext_id,
               "data": json.dumps({"callbackUrl": service, "ticket": ticket,
                                   "deviceId": _rnd(32)})}
    r = s.post(VPN_BASE + "/api/access/auth/finish", json=payload, timeout=TIMEOUT,
               headers={"Accept": "application/json", "Origin": VPN_BASE})
    j = r.json()
    if j.get("code") != 0:
        raise RuntimeError("WebVPN auth/finish 失败：%s" % r.text[:200])
    return s, j["data"].get("token", "")


def get_access_token(s: requests.Session) -> str:
    """CAS 会话预热 -> oauth/authorize 取 code -> oauth/token 换 access_token。"""
    # ⚠️ 第 6 步不能省：不预热的话 authorize 只会 302 回登录页，拿不到 code
    s.get(APP_BASE + "/authserver/casLogin?redirect_uri=" + quote(CAS_WARMUP, safe=""),
          timeout=TIMEOUT, allow_redirects=True)

    az = ("%s/authserver/oauth/authorize?client_id=%s&response_type=code&scope=all"
          "&state=tt&redirect_uri=%s" % (APP_BASE, CLIENT_ID, quote(REDIRECT_URI, safe="")))
    r = s.get(az, timeout=TIMEOUT, allow_redirects=False)
    if r.status_code != 302:
        raise RuntimeError("authorize 未返回 302（%s）：%s" % (r.status_code, r.text[:200]))
    code = parse_qs(urlparse(r.headers["Location"]).query).get("code")
    if not code:
        raise RuntimeError("authorize 未返回 code：%s" % r.headers["Location"][:200])

    r = s.post(APP_BASE + "/authserver/oauth/token", timeout=TIMEOUT,
               auth=(CLIENT_ID, CLIENT_SECRET),
               data={"client_id": CLIENT_ID, "client_secret": CLIENT_SECRET,
                     "code": code[0], "redirect_uri": REDIRECT_URI,
                     "grant_type": "authorization_code"},
               headers={"Content-Type": "application/x-www-form-urlencoded"})
    if r.status_code != 200:
        raise RuntimeError("换 token 失败：%s" % r.text[:200])
    tok = r.json().get("access_token")
    if not tok:
        raise RuntimeError("响应中无 access_token")
    return tok


# ============================ 业务接口 ============================

def fetch_all(s: requests.Session, token: str) -> dict:
    h = {"Authorization": "Bearer " + token, "Accept": "application/json"}
    hj = dict(h, **{"Content-Type": "application/json"})

    def get(path):
        r = s.get(APP_BASE + path, headers=h, timeout=60)
        r.raise_for_status()
        return r.json()

    si = get("/api/resourceapi/session/info-detail")
    si_d = si.get("data") or si
    sid = si_d.get("curSessionId")
    if not sid:
        raise RuntimeError("未取到 curSessionId")

    # 学号从 JWT 的 user_name 声明解出
    pad = "=" * (-len(token.split(".")[1]) % 4)
    claims = json.loads(base64.urlsafe_b64decode(token.split(".")[1] + pad))
    stu = claims.get("user_name") or claims.get("sub")
    if not stu:
        raise RuntimeError("token 中无 user_name")

    r = s.post(APP_BASE + "/api/timetable/class/timetable/student/my-table-detail?sessionId=%s" % sid,
               headers=hj, data=json.dumps([stu]), timeout=90)
    r.raise_for_status()
    tt = r.json()
    tt_d = tt.get("data") or tt

    cw = get("/api/timetable/time/cur-week")
    mw = get("/api/timetable/course/maxWeek/%s" % sid)
    sl = get("/api/resourceapi/session/list")
    tp = get("/api/resourceapi/timePattern/get-large-period?sessionId=%s" % sid)

    return {
        "tt": {
            "list": tt_d.get("classTimetableVOList") or [],
            "sessionInfo": si_d,
            "stu": stu,
            "sessionId": str(sid),
            "maxSection": tt_d.get("maxSection"),
            "curWeek": cw,
            "status": tt.get("status") or tt_d.get("status"),
        },
        "extra": {"mw": mw, "sl": sl, "tp": tp},
    }


# ============================ 主流程 ============================

def dump_raw(data: dict, path: str) -> None:
    """按 build.py 约定的格式写：{capturedAt}\\n=====SPLIT=====\\n{tt,extra}"""
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    header = {"capturedAt": datetime.datetime.now().astimezone().isoformat(timespec="seconds")}
    with open(path, "w", encoding="utf-8") as f:
        f.write(json.dumps(header, ensure_ascii=False) + "\n=====SPLIT=====\n"
                + json.dumps(data, ensure_ascii=False))


def run_build() -> int:
    if not os.path.exists(BUILD_PY):
        log("⚠️ 未找到 build.py，跳过解析：", BUILD_PY)
        return 0
    log("→ 调用 build.py 解析并分发到", PUBLISH_DIR)
    p = subprocess.run([sys.executable, BUILD_PY], cwd=WORKDIR)
    return p.returncode


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="重庆移通学院智慧教务课表抓取（纯后端单文件版）")
    ap.add_argument("--raw", default=DEFAULT_RAW, help="原始数据输出路径")
    ap.add_argument("--no-build", action="store_true", help="只抓原始数据，不调用 build.py")
    ap.add_argument("--cipher-user", default=os.environ.get("CQYT_CIPHER_USER", CIPHER_USER))
    ap.add_argument("--cipher-pass", default=os.environ.get("CQYT_CIPHER_PASS", CIPHER_PASS))
    ap.add_argument("--aes-key", default=os.environ.get("CQYT_AES_KEY", AES_KEY))
    args = ap.parse_args(argv)
    if not args.cipher_user or not args.cipher_pass or not args.aes_key:
        ap.error("请通过 CQYT_CIPHER_USER / CQYT_CIPHER_PASS / CQYT_AES_KEY 或对应参数提供凭据")

    # ⚠️ 先删旧文件：残留的 raw_dump.json 会让成功判据失真
    if os.path.exists(args.raw):
        os.remove(args.raw)
        log("旧原始数据已删除：", args.raw)

    user = decrypt_credential(args.cipher_user, args.aes_key)
    pwd = decrypt_credential(args.cipher_pass, args.aes_key)
    log("① 凭证解密完成（学号 %s）" % user)

    s, _ = webvpn_login(user, pwd)
    log("② WebVPN + CAS 登录成功")

    token = get_access_token(s)
    log("③ access_token 获取成功（长度 %d）" % len(token))

    data = fetch_all(s, token)
    log("④ 课表抓取完成：%d 条记录，sessionId=%s"
        % (len(data["tt"]["list"]), data["tt"]["sessionId"]))

    dump_raw(data, args.raw)
    log("⑤ 原始数据已写入", args.raw, "(%d bytes)" % os.path.getsize(args.raw))

    if args.no_build:
        log("已跳过解析（--no-build）")
        return 0

    rc = run_build()
    if rc != 0:
        log("⚠️ build.py 返回码", rc)
    return rc


if __name__ == "__main__":
    sys.exit(main())
