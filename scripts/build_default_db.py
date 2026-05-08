#!/usr/bin/env python3
"""
build_default_db.py
===================
不需 AI API，直接從官方 PDF 解析題文、答案、通過率，
產生 exam_data.db 作為 iOS app 預設題庫。

用法：
    pip install -r requirements.txt
    python build_default_db.py
"""

import io
import re
import json
import sqlite3
import requests
import pdfplumber
from pathlib import Path

OUTPUT_DIR = Path(__file__).parent / "output"
CACHE_DIR  = Path(__file__).parent / "cache"
DB_PATH    = OUTPUT_DIR / "exam_data.db"

CACHE_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# ─────────────────────────────────────────────
# 各年 Google Drive 檔案 ID
# ─────────────────────────────────────────────

EXAM_DRIVE_IDS: dict[int, dict] = {
    103: {
        # 103年 PDFs 為掃描圖片，無法文字抽取，略過
        "_pass_rate":  "1NcJRiYfPtaynwNHf0-JIk4qLQ1LhmMG3",
        "_answer_key": "1hMiCEiapwaiMyU-VmjvCEvejdAZNLF5X",
    },
    104: {
        "國文": "12b-9611fJFQ1t-miEOxi_Hp_uJTBqsEJ",
        "英語": "1T-dPLJfJMjQAK0JNu_kZJi5cyGlEqbtf",
        "數學": "1bwFaAAZGPoT3GV1Bz78ExXzFpJhaSyZ4",
        "社會": "1iH2RqmpilJ9FcMNC4_QruSUKUhhcCzKx",
        "自然": "1_71XW7z1fj3jCzjTQsKIrkEDHyRxCzGE",
        "_pass_rate":  "1X_NptNz19q-j87vlTHCARIgLZzx5UYiX",
        "_answer_key": "1hR_wM3y_h8iEs0lkmjoipsO3yqu-xVkh",
    },
    105: {
        "國文": "1gpds3aItngE56h2nuTCYZTPWB0x_ugUn",
        "英語": "1obYGSaLt_OTg1wVya-k__JAgZXmuKc7h",
        "數學": "1dmMcIsjV1wA-UmKsQ-DiiwY-BzQx-lA1",
        "社會": "1wbHfZbLPrt3PLizRBuCgU_AX2K6-dv1V",
        "自然": "1MXLxdpcaTtIzNIGRHk_DBMTb5lloTDUN",
        "_pass_rate":  "1Jm_XLqWJu6moSE8oNDRi6FOw1V8yVVPr",
        "_answer_key": "15bDpOsfOw4ucIgdCwH5tggq7TVTlbap7",
    },
    106: {
        "國文": "1lkJulMy3LDaPetCw2kV0eU1K1uiK2Uqv",
        "英語": "1hbGHVdkMmiWxIZL1c5OTO9RUUZPgMUjB",
        "數學": "10JGzIlDxgOyUmcVZVn3E5os8trXbcorr",
        "社會": "1a2FJG15x_aFlDwJEe377et0cau-yYKK-",
        "自然": "1nKOX2Y_Lc97oRP0CNdibx3sdWo4zWj2s",
        "_pass_rate":  "1oDAibMFZd8jdpv3P3NNPSHKWglk60kwq",
        "_answer_key": "1SDrO_xG9MG6Kmcg1H9ibY_NM410de9VF",
    },
    107: {
        "國文": "1o9HsmNT7ydexWB8IhdEeOJ47MEaSN6jq",
        "英語": "1ToSEBw4hLa4GGonGdUUf70Dibg4juSDw",
        "數學": "1331V76tWuKofLTQ2Lx4U_pEJ6ZR4SG0J",
        "社會": "13zTtdH_y-6OR5RDSvMfEKDSRyZe-pqPU",
        "自然": "1liuOGMSy_z_57Gbu9psuWPxQw_8oAt32",
        "_pass_rate":  "1dvKl1yAEf1V7Gw6d92ydWgi6jxoQlbyU",
        "_answer_key": "1XigR8bMEJoG6lwe8yhsbKpHn3MHfUSeY",
    },
    108: {
        "國文": "1kv7IPubkZqdd4Sm9NJQ4TneXHS4Nj5Qu",
        "英語": "1z8bQ38BFxWvXiHr_yxD6pv9UXy8sxW6v",
        "數學": "1ouI9tIEJETAGqzh4V1OwB1t83ouA-CaH",
        "社會": "1ZVi5WqoWsZOq83HmVSoiuy4nCxNLD54o",
        "自然": "1BXf0z9hqcmlnefKk1XKLQQp1ec6V1azI",
        "_pass_rate":  "1DUaGPrKEffWc-XG9sIqx8OqDZbJupIa8",
        "_answer_key": "1M5ObFB8NhhzocLtxc11O2VREq_h1-YBb",
    },
    109: {
        "國文": "1RpB4Y6I7FE2ADaTm-lKQYFLZU8LLjRhx",
        "英語": "14uTgONqVcy8uRMe0rgRWr7CRBvkp5TJ1",
        "數學": "1jZJWQoO6mQZ_vWMmBcpJMC7bHdXIiJf0",
        "社會": "1y_1Sc8yH-iHtS6eBcLOCm_9fnmL2aFjf",
        "自然": "1nDVCh0u-MAApDFlv0kTVhFr_v7VKNVgP",
        "_pass_rate":  "152pYdizLEA7frTUgrMgyHo12qCKWSTyJ",
        "_answer_key": "1zj_iw_7T3M6BgmGZkFOIIGNghr02dWPk",
    },
    110: {
        "國文": "1z5dk4Ar0QaZT_6dPsu2ZVP8_OBwe6LnS",
        "英語": "1jeGXKMm5auA68Z7SGzQo-bXq1opG6Knt",
        "數學": "1sKc4iLzr8WlbbxMA83Y0NNryYv9rqHiG",
        "社會": "1pBrjHnXMCyTGmZgThvLVBpBlZaQkyU9t",
        "自然": "124Y-9HcPGeNzpQPe6Osl4X7A_xNIT0UA",
        "_pass_rate":  "1hfOMmh6c_zmNNXIEkjnCdtZcx-QMfY3a",
        "_answer_key": "1z7jBxC9t24e2Y3WK71XxWe0JOjJRLcNW",
    },
    111: {
        "國文": "174XqqVxF7_kIR7aqRaHpDe9m8-YJBFzY",
        "英語": "1IyJBtIjySeyVAisE1YiCclYsSldQpHBf",
        "數學": "15GDoX37pXdUsluIw79o2bkhgfiL1HxCG",
        "社會": "1th-vb5HCBAhIv65OKXY646kHYbyggwQu",
        "自然": "1OiQVdqtDQauNW_qwlCFTWLmcfBHuCjdm",
        "_pass_rate":  "1Pzu_Pw8vZGV074zemF0BQp59nJgQgEsO",
        "_answer_key": "1IeMHI4BmTpC_2Oc1lQ1Qj6XWHDf9qwGd",
    },
    112: {
        "國文": "1dy9SuFFJro5R8SOIZRbA8ytq2Ol-UnZ9",
        "英語": "1SXbjT6B_F8eQh2GZEvB6KmgR0k2lDK8A",
        "數學": "1im3JF0E8d8RC__Z8MW9MQXCuonjPN3f_",
        "社會": "1vIVX90btDzk3XnNVfSQv0wRTw2A6omjL",
        "自然": "1Bo87vJFakmGzyUqqjHzTCF-fv75DFgx_",
        "_pass_rate":  "16ysF1jgYwJ_1gmt0veV1Z8398BmIQbjJ",
        "_answer_key": "1OT5r0que_0bXSy0kwLEOEJMssce2OnL0",
    },
    113: {
        "國文": "1Xr5AwMNQipYZblCEbZadyBvLVcT_8XSv",
        "英語": "1ZU8SG-4jdV1DGvPzpgzoi_hhRiD4NT3S",
        "數學": "1MXfrOI_4KyxF6A-2NNd_J_eIuo3Epa46",
        "社會": "1NJYibw-N2mHZP5lL8-rOhirWv_ZFQNiz",
        "自然": "1lO1_3Iq62BmTHR8m29or7I8VtS8qZdDR",
        "_pass_rate":  "1NpFiGL8A6KVR-Hyn_M7u1JhvXNOTqPOr",
        "_answer_key": "1cWlogP9FBRX1eD5kjgVDP2_6f8VCLSB4",
    },
}

# ─────────────────────────────────────────────
# 108課綱 章節關鍵字對應（數學）
# ─────────────────────────────────────────────

MATH_CHAPTER_MAP = [
    # 七上
    ("七上", 1, "整數與分數的計算", ["分數", "整數", "絕對值", "相反數", "加減乘除"]),
    ("七上", 2, "比與比例式", ["比例", "比值", "正比", "反比"]),
    ("七上", 3, "一元一次方程式", ["一元一次方程", "方程式", "解方程"]),
    ("七上", 4, "直角坐標", ["坐標", "座標", "x軸", "y軸", "原點"]),
    # 七下
    ("七下", 1, "多項式的四則運算", ["多項式", "單項式", "係數", "次數"]),
    ("七下", 2, "乘法公式與因式分解", ["因式分解", "乘法公式", "完全平方", "平方差"]),
    ("七下", 3, "一元一次不等式", ["不等式", "解不等式", "不等號"]),
    ("七下", 4, "線型函數", ["一次函數", "直線", "斜率", "截距", "線型函數"]),
    # 八上
    ("八上", 1, "二元一次方程組", ["二元一次", "聯立方程", "聯立"]),
    ("八上", 2, "幾何圖形", ["三角形", "多邊形", "平行", "垂直", "全等", "線對稱"]),
    ("八上", 3, "三角形的性質", ["三角形", "內角和", "外角", "全等三角形", "SSS", "SAS", "ASA"]),
    ("八上", 4, "平行四邊形", ["平行四邊形", "矩形", "菱形", "正方形", "梯形"]),
    # 八下
    ("八下", 1, "平方根與實數", ["平方根", "根號", "實數", "無理數", "有理數"]),
    ("八下", 2, "二次方程式", ["二次方程", "配方法", "公式解", "判別式"]),
    ("八下", 3, "一次函數與圖形", ["函數", "圖形", "拋物線"]),
    # 九上
    ("九上", 1, "二次函數", ["二次函數", "最大值", "最小值", "頂點", "拋物線"]),
    ("九上", 2, "相似形", ["相似", "比例", "對應邊", "放大縮小"]),
    ("九上", 3, "三角函數", ["三角函數", "sin", "cos", "tan", "正弦", "餘弦", "正切"]),
    ("九上", 4, "統計", ["統計", "平均數", "中位數", "眾數", "次數分配", "圖表"]),
    # 九下
    ("九下", 1, "圓的性質", ["圓", "弧", "弦", "圓心角", "圓周角", "切線", "半徑"]),
    ("九下", 2, "空間圖形", ["立體", "正多面體", "稜柱", "角柱", "角錐", "球", "展開圖"]),
    ("九下", 3, "數列與級數", ["等差數列", "等比數列", "級數", "數列"]),
    ("九下", 4, "機率", ["機率", "事件", "樣本空間", "隨機"]),
]

def classify_math_chapter(question_text: str):
    text = question_text
    best = None
    for vol, chnum, chname, keywords in MATH_CHAPTER_MAP:
        for kw in keywords:
            if kw in text:
                best = (vol, chnum, chname)
                break
        if best:
            break
    if best:
        return best
    return ("九下", 4, "機率與統計")  # 默認

SUBJECT_CLASSIFIERS = {
    "數學": classify_math_chapter,
}

def classify_chapter(subject: str, question_text: str):
    fn = SUBJECT_CLASSIFIERS.get(subject)
    if fn:
        return fn(question_text)
    return ("", 1, "")

def estimate_difficulty(pass_rate):
    if pass_rate is None:
        return "medium"
    if pass_rate >= 0.75:
        return "easy"
    elif pass_rate >= 0.45:
        return "medium"
    else:
        return "hard"

# ─────────────────────────────────────────────
# 下載工具（帶快取）
# ─────────────────────────────────────────────

def download_gdrive(file_id: str, desc: str = "") -> bytes | None:
    cache_file = CACHE_DIR / f"gdrive_{file_id}"
    if cache_file.exists():
        data = cache_file.read_bytes()
        if data[:4] == b'%PDF':
            return data

    for url in [
        f"https://drive.google.com/uc?export=download&id={file_id}",
        f"https://drive.usercontent.google.com/download?id={file_id}&export=download&authuser=0&confirm=t",
    ]:
        try:
            r = requests.get(url, timeout=60, headers={"User-Agent": "Mozilla/5.0"})
            if r.status_code == 200 and r.content[:4] == b'%PDF':
                cache_file.write_bytes(r.content)
                return r.content
        except Exception:
            pass
    print(f"  ⚠  下載失敗：{desc or file_id}")
    return None

# ─────────────────────────────────────────────
# 答案解析（官方 PDF 表格）
# ─────────────────────────────────────────────

SUBJECT_COL = {"國文": 1, "英語": 2, "數學": 4, "社會": 5, "自然": 6}
# 英語閱讀在欄3，聽力在欄2 — 我們把閱讀當英語主科
SUBJECT_COL_ALT = {"英語": 3}  # 閱讀

def parse_answer_key(pdf_bytes: bytes) -> dict[str, dict[int, str]]:
    """解析官方選擇題答案 PDF，回傳 {subject: {q_num: answer}}

    使用 pdfplumber 表格解析，欄位固定：
    [題號, -, 國文, 英語(閱讀), 英語(聽力), 數學, 社會, 自然]
    索引:  0  1    2     3          4         5    6    7
    """
    COL_MAP = {2: "國文", 3: "英語", 5: "數學", 6: "社會", 7: "自然"}
    result: dict[str, dict[int, str]] = {}

    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        for page in pdf.pages:
            tables = page.extract_tables()
            if not tables:
                continue
            for table in tables:
                for row in table:
                    if not row or not row[0]:
                        continue
                    try:
                        q_num = int(str(row[0]).strip())
                    except ValueError:
                        continue
                    if q_num < 1 or q_num > 60:
                        continue
                    for col_idx, subj in COL_MAP.items():
                        if col_idx < len(row):
                            val = str(row[col_idx]).strip() if row[col_idx] else ""
                            if val in {'A', 'B', 'C', 'D'}:
                                result.setdefault(subj, {})[q_num] = val

    return result

# ─────────────────────────────────────────────
# 通過率解析
# ─────────────────────────────────────────────

def parse_pass_rates(pdf_bytes: bytes) -> dict[str, dict[int, float]]:
    result: dict[str, dict[int, float]] = {}
    col_map = {
        "國文": "國文",
        "英語(聽力)": "英語", "英語（聽力）": "英語",
        "英語(閱讀)": "英語", "英語（閱讀）": "英語",
        "英語": "英語",
        "數學": "數學",
        "社會": "社會",
        "自然": "自然",
    }
    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        for page in pdf.pages:
            table = page.extract_table()
            if not table:
                continue
            header = None
            for row in table:
                cleaned = [str(c).strip() if c else "" for c in row]
                if any(k in cleaned for k in ["題序", "題號"]):
                    header = cleaned
                elif header and cleaned[0].isdigit():
                    q_num = int(cleaned[0])
                    for j, h in enumerate(header):
                        for col_name, subj in col_map.items():
                            if col_name in h:
                                try:
                                    v = float(cleaned[j]) if j < len(cleaned) and cleaned[j] else None
                                    if v is not None:
                                        result.setdefault(subj, {})[q_num] = (
                                            v if v <= 1.0 else v / 100.0
                                        )
                                except (ValueError, IndexError):
                                    pass
    return result

# ─────────────────────────────────────────────
# 題目解析（pdfplumber 文字抽取）
# ─────────────────────────────────────────────

def parse_questions_from_pdf(pdf_bytes: bytes, subject: str) -> list[dict]:
    """從試題 PDF 抽取選擇題文字，回傳 [{number, question_text, options}]

    策略：以「(A)」為錨點，向前找題號，向後找 B/C/D 選項。
    適用於中英文各科，不依賴特定標頭文字。
    """
    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        all_lines = []
        for page in pdf.pages:
            text = page.extract_text() or ""
            all_lines.extend(text.split("\n"))

    # 過濾：去除純空白或頁碼行
    PAGE_NUM  = re.compile(r'^\d{1,3}$')
    SKIP_KEYS = ["請翻頁", "請聽", "作答說明", "聽力測驗"]
    filtered: list[str] = []
    for line in all_lines:
        s = line.strip()
        if not s or PAGE_NUM.match(s):
            continue
        if any(k in s for k in SKIP_KEYS):
            continue
        filtered.append(s)

    # 用 (A) 出現位置切分
    # 找每個 (A) 前面最近的「題號行」: 獨立的 "N." 或 "N. 文字"
    Q_LINE  = re.compile(r'^(\d{1,2})[.．]\s*(.*)')  # 行首: N. [text]
    Q_ALONE = re.compile(r'^(\d{1,2})[.．]$')        # 行首: N. (孤行)

    # 先找所有 (A) 的索引
    opt_a_indices = [i for i, l in enumerate(filtered) if l.startswith('(A)')]

    seen: dict[int, dict] = {}

    for ai in opt_a_indices:
        # 往回找題號（最多找 20 行）
        q_num = None
        q_start_idx = ai
        for back in range(1, min(21, ai + 1)):
            candidate = filtered[ai - back]
            m = Q_LINE.match(candidate)
            if m:
                n = int(m.group(1))
                if 1 <= n <= 60:
                    q_num = n
                    q_start_idx = ai - back
                    break
            # 如果遇到 (D) 則停止（說明是上一題的選項）
            if candidate.startswith('(D)'):
                break

        if q_num is None:
            continue

        # 收集 B、C、D 選項
        opts: dict[str, str] = {'A': filtered[ai][4:].strip()}
        li = ai + 1
        for letter in 'BCD':
            while li < len(filtered):
                candidate = filtered[li]
                if candidate.startswith(f'({letter})'):
                    opts[letter] = candidate[4:].strip()
                    li += 1
                    break
                # 如果遇到下一個題號，停止
                if Q_LINE.match(candidate) and int(Q_LINE.match(candidate).group(1)) > q_num:
                    break
                # 若是繼續選項文字，append 到上一個選項
                if letter in opts and candidate and not candidate.startswith('('):
                    prev = opts[letter]
                    if prev:
                        opts[letter] = prev + ' ' + candidate
                li += 1

        # 題幹：從 q_start_idx 到 (A) 之前的內容
        stem_lines = filtered[q_start_idx:ai]
        # 去掉題號前綴
        first = stem_lines[0] if stem_lines else ''
        m = Q_LINE.match(first)
        if m:
            stem_lines[0] = m.group(2).strip()

        stem = ' '.join(l for l in stem_lines if l).strip()
        stem = re.sub(r'\s{2,}', ' ', stem)

        if len(stem) < 3:
            continue

        q = {
            "number": q_num,
            "question_text": stem,
            "options": opts if len(opts) >= 2 else None,
        }
        # 取最長的題幹
        if q_num not in seen or len(stem) > len(seen[q_num]["question_text"]):
            seen[q_num] = q

    return sorted(seen.values(), key=lambda x: x["number"])

# ─────────────────────────────────────────────
# 資料庫
# ─────────────────────────────────────────────

SCHEMA = """
CREATE TABLE IF NOT EXISTS exams (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    filename   TEXT NOT NULL,
    subject    TEXT,
    year       INTEGER,
    created_at TEXT DEFAULT (datetime('now','localtime')),
    raw_json   TEXT
);
CREATE TABLE IF NOT EXISTS question_bank (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    source_exam_id        INTEGER REFERENCES exams(id) ON DELETE SET NULL,
    year                  INTEGER,
    subject               TEXT    NOT NULL,
    volume                TEXT,
    chapter_num           INTEGER,
    chapter_name          TEXT,
    topic                 TEXT,
    question_num          INTEGER,
    question_text         TEXT    NOT NULL,
    question_type         TEXT    DEFAULT '選擇題',
    option_a              TEXT,
    option_b              TEXT,
    option_c              TEXT,
    option_d              TEXT,
    correct_answer        TEXT,
    pass_rate             REAL,
    difficulty            TEXT    DEFAULT 'medium',
    explanation           TEXT,
    first_attempt_correct INTEGER,
    created_at            TEXT    DEFAULT (datetime('now','localtime'))
);
CREATE TABLE IF NOT EXISTS practice_sessions (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    subject     TEXT,
    total       INTEGER DEFAULT 0,
    correct     INTEGER DEFAULT 0,
    created_at  TEXT DEFAULT (datetime('now','localtime')),
    finished_at TEXT
);
CREATE TABLE IF NOT EXISTS practice_attempts (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id   INTEGER NOT NULL REFERENCES practice_sessions(id) ON DELETE CASCADE,
    question_id  INTEGER NOT NULL REFERENCES question_bank(id)     ON DELETE CASCADE,
    is_correct   INTEGER,
    attempted_at TEXT DEFAULT (datetime('now','localtime'))
);
"""

def init_db(conn):
    conn.executescript(SCHEMA)
    conn.commit()

def already_processed(conn, year, subject):
    return conn.execute(
        "SELECT 1 FROM exams WHERE year=? AND subject=?", (year, subject)
    ).fetchone() is not None

# ─────────────────────────────────────────────
# 主流程
# ─────────────────────────────────────────────

def main():
    conn = sqlite3.connect(DB_PATH)
    init_db(conn)
    print(f"✅ 資料庫：{DB_PATH}\n")

    for year in sorted(EXAM_DRIVE_IDS.keys()):
        year_data  = EXAM_DRIVE_IDS[year]
        subjects   = {k: v for k, v in year_data.items() if not k.startswith("_")}
        pr_id      = year_data.get("_pass_rate")
        ans_id     = year_data.get("_answer_key")

        print(f"{'='*55}")
        print(f"📅 {year}年")

        # 通過率
        pass_rates: dict[str, dict[int, float]] = {}
        if pr_id:
            pr_bytes = download_gdrive(pr_id, f"{year}通過率")
            if pr_bytes:
                try:
                    pass_rates = parse_pass_rates(pr_bytes)
                    total_q = sum(len(v) for v in pass_rates.values())
                    print(f"  📊 通過率：{list(pass_rates.keys())}，共 {total_q} 筆")
                except Exception as e:
                    print(f"  ⚠  通過率解析失敗：{e}")

        # 答案
        answers: dict[str, dict[int, str]] = {}
        if ans_id and ans_id != pr_id:
            ans_bytes = download_gdrive(ans_id, f"{year}答案")
            if ans_bytes:
                try:
                    answers = parse_answer_key(ans_bytes)
                    total_a = sum(len(v) for v in answers.values())
                    print(f"  📝 答案：{list(answers.keys())}，共 {total_a} 筆")
                except Exception as e:
                    print(f"  ⚠  答案解析失敗：{e}")
        elif pr_id:
            # 嘗試從通過率 PDF 同時解析答案（部分年份合在一起）
            pr_bytes = download_gdrive(pr_id, f"{year}通過率/答案")
            if pr_bytes:
                try:
                    answers = parse_answer_key(pr_bytes)
                    if any(answers.values()):
                        total_a = sum(len(v) for v in answers.values())
                        print(f"  📝 答案（含於通過率PDF）：共 {total_a} 筆")
                except Exception:
                    pass

        for subject, file_id in subjects.items():
            if already_processed(conn, year, subject):
                print(f"  ⏭  {subject}：已處理")
                continue

            print(f"\n  📥 {year}年{subject}...", end="", flush=True)
            pdf_bytes = download_gdrive(file_id, f"{year}_{subject}")
            if not pdf_bytes:
                print(" ❌ 下載失敗")
                continue
            print(f" {len(pdf_bytes)//1024}KB", end="", flush=True)

            # 解析題目
            try:
                questions = parse_questions_from_pdf(pdf_bytes, subject)
            except Exception as e:
                print(f" ⚠  解析失敗：{e}")
                continue
            print(f" → {len(questions)} 題")

            # 存進 exams 表
            raw_json = json.dumps({"subject": subject, "questions": []}, ensure_ascii=False)
            cur = conn.execute(
                "INSERT INTO exams (filename, subject, year, raw_json) VALUES (?,?,?,?)",
                (f"{year}_{subject}.pdf", subject, year, raw_json)
            )
            exam_id = cur.lastrowid

            subj_answers   = answers.get(subject, {})
            subj_passrates = pass_rates.get(subject, {})

            inserted = 0
            for q in questions:
                num  = q["number"]
                ans  = subj_answers.get(num)
                pr   = subj_passrates.get(num)
                opts = q.get("options") or {}
                diff = estimate_difficulty(pr)

                vol, chnum, chname = classify_chapter(subject, q["question_text"])
                topic = chname  # 用章節名作知識點（後續可補充）

                conn.execute(
                    """INSERT INTO question_bank
                       (source_exam_id, year, subject, volume, chapter_num, chapter_name,
                        topic, question_num, question_text, question_type,
                        option_a, option_b, option_c, option_d,
                        correct_answer, pass_rate, difficulty, explanation, first_attempt_correct)
                       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (
                        exam_id, year, subject,
                        vol or None, chnum or None, chname or None,
                        topic or None, num,
                        q["question_text"], "選擇題",
                        opts.get("A"), opts.get("B"), opts.get("C"), opts.get("D"),
                        ans, pr, diff, "", None,
                    )
                )
                inserted += 1

            conn.commit()
            print(f"    ✅ {inserted} 題入庫")

    # 統計
    total  = conn.execute("SELECT COUNT(*) FROM question_bank").fetchone()[0]
    w_pr   = conn.execute("SELECT COUNT(*) FROM question_bank WHERE pass_rate IS NOT NULL").fetchone()[0]
    w_ans  = conn.execute("SELECT COUNT(*) FROM question_bank WHERE correct_answer IS NOT NULL").fetchone()[0]
    conn.close()

    print(f"\n{'='*55}")
    print(f"🎉 完成！")
    print(f"   總題數：{total}")
    print(f"   有通過率：{w_pr}")
    print(f"   有答案：{w_ans}")
    print(f"   輸出：{DB_PATH}")
    print(f"\n下一步：")
    print(f"   cp {DB_PATH} ../exam_data.db")

if __name__ == "__main__":
    main()
