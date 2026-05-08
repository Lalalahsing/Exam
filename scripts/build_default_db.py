#!/usr/bin/env python3
"""
build_default_db.py
===================
不需 AI API，直接從官方 PDF 解析題文、答案、通過率，
同時偵測題組（group）、提取表格（table）、標記圖形（figure），
產生 exam_data.db 作為 iOS app 預設題庫。

用法：
    pip install -r requirements.txt
    python build_default_db.py
"""

import io
import re
import json
import uuid
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

    動態從標頭列偵測欄位位置，相容各年欄位偏移差異。
    標頭關鍵字 → 科目：
      '國文' → 國文
      '英語'（優先取「閱讀」欄，若無則取首個英語欄）
      '數學' → 數學
      '社會' → 社會
      '自然' → 自然
    """
    SUBJ_KEYWORDS = {
        "國文": ["國文"],
        "英語": ["英語", "閱讀"],   # 取閱讀欄（若分開）或英語欄
        "數學": ["數學"],
        "社會": ["社會"],
        "自然": ["自然"],
    }
    result: dict[str, dict[int, str]] = {}

    def _detect_col_map(header_rows: list[list]) -> dict[str, int]:
        """從最多兩列標頭（跨列合併）推算各科欄位索引。"""
        # 合並兩列標頭文字（None 替換為空字串）
        merged: list[str] = []
        for ci in range(max(len(r) for r in header_rows)):
            cell = ""
            for hr in header_rows:
                if ci < len(hr) and hr[ci]:
                    cell += str(hr[ci]).replace("\n", "")
            merged.append(cell.strip())

        col_map: dict[str, int] = {}
        # 英語：先找「閱讀」，再找「英語」
        for ci, text in enumerate(merged):
            if "國文" in text and "國文" not in col_map:
                col_map["國文"] = ci
            if "數學" in text and "數學" not in col_map:
                col_map["數學"] = ci
            if "社會" in text and "社會" not in col_map:
                col_map["社會"] = ci
            if "自然" in text and "自然" not in col_map:
                col_map["自然"] = ci
            if "閱讀" in text and "英語" not in col_map:
                col_map["英語"] = ci
        # 若無「閱讀」，退而求其次取「英語」欄
        if "英語" not in col_map:
            for ci, text in enumerate(merged):
                if "英語" in text:
                    col_map["英語"] = ci
                    break
        return col_map

    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        for page in pdf.pages:
            tables = page.extract_tables()
            if not tables:
                continue
            for table in tables:
                if not table:
                    continue

                # 找標頭列（含科目名稱的行，通常是前 1-2 行）
                header_rows = []
                data_start = 0
                for ri, row in enumerate(table[:4]):
                    cleaned = [str(c).strip() if c else "" for c in row]
                    if any(k in " ".join(cleaned) for k in ["國文", "數學", "社會", "自然"]):
                        header_rows.append(row)
                        data_start = ri + 1
                    elif header_rows:
                        # 若上一行是標頭且這行含「閱讀」「聽力」等子標頭，也納入
                        if any(k in " ".join(cleaned) for k in ["閱讀", "聽力"]):
                            header_rows.append(row)
                            data_start = ri + 1
                        else:
                            break

                if not header_rows:
                    continue

                col_map = _detect_col_map(header_rows)
                if not col_map:
                    continue

                for row in table[data_start:]:
                    if not row or not row[0]:
                        continue
                    try:
                        q_num = int(str(row[0]).strip())
                    except ValueError:
                        continue
                    if q_num < 1 or q_num > 60:
                        continue
                    for subj, ci in col_map.items():
                        if ci < len(row):
                            val = str(row[ci]).strip() if row[ci] else ""
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
# 題組偵測（文字模式比對）
# ─────────────────────────────────────────────

# 會考題組前綴常見模式，例如：
#   ◎第46至48題為題組題，請依下文回答第46至48題。
#   ◎請依下列文章，回答第46～48題。
#   ◎閱讀下文，回答第46-48題。
#   ◎以下為某某資料，依此回答第46至48題。
GROUP_RANGE_RE = re.compile(
    r'第\s*(\d{1,2})\s*[至到~～\-－–—]\s*(\d{1,2})\s*題'
)

def detect_groups(lines: list[str]) -> dict[int, dict]:
    """
    掃描 lines 中的題組標記，回傳：
    { q_num: {"group_id": str, "group_premise": str, "group_order": int} }
    """
    group_map: dict[int, dict] = {}

    Q_LINE = re.compile(r'^(\d{1,2})[.．]\s*')

    i = 0
    while i < len(lines):
        line = lines[i]

        # 尋找題組起始行：包含「第N至N題」或「第N～N題」且通常以「◎」或空白起始
        m_range = GROUP_RANGE_RE.search(line)
        if m_range:
            start_q = int(m_range.group(1))
            end_q   = int(m_range.group(2))

            # 合理範圍檢查
            if 1 <= start_q < end_q <= 60 and (end_q - start_q) <= 10:
                # 收集前提文字：從此行開始，直到遇到第一個題目行
                premise_lines = [line]
                j = i + 1
                while j < len(lines):
                    candidate = lines[j]
                    # 如果遇到題目行（N. ...），停止
                    if Q_LINE.match(candidate):
                        try:
                            n = int(Q_LINE.match(candidate).group(1))
                            if n == start_q:
                                break
                        except Exception:
                            pass
                    # 如果又遇到另一個題組標記，停止
                    if GROUP_RANGE_RE.search(candidate) and candidate != line:
                        break
                    premise_lines.append(candidate)
                    j += 1

                premise_text = " ".join(pl.strip() for pl in premise_lines if pl.strip())
                # 去除開頭的「◎」和末尾的指示語
                premise_text = re.sub(r'^[◎○●▶►\s]+', '', premise_text)
                premise_text = re.sub(r'[，,。]*請依.*回答.*題[。,]?\s*$', '', premise_text).strip()
                premise_text = re.sub(r'[，,。]*依此回答.*題[。,]?\s*$', '', premise_text).strip()

                if len(premise_text) > 5:  # 至少有意義的前提
                    group_id = str(uuid.uuid4())
                    for order, q_num in enumerate(range(start_q, end_q + 1)):
                        group_map[q_num] = {
                            "group_id":      group_id,
                            "group_premise": premise_text,
                            "group_order":   order,
                        }
        i += 1

    return group_map

# ─────────────────────────────────────────────
# 表格提取（pdfplumber）
# ─────────────────────────────────────────────

def extract_page_tables(pdf_bytes: bytes) -> list[dict]:
    """
    提取每頁所有表格，回傳：
    [ { "page": int, "bbox": (x0,y0,x1,y1), "data": {"headers":[...], "rows":[[...],...]} } ]
    只保留有實質內容的表格（至少 2 列 × 2 欄）。
    """
    results = []
    try:
        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            for page_idx, page in enumerate(pdf.pages):
                try:
                    found_tables = page.find_tables()
                except Exception:
                    found_tables = []

                for tbl in found_tables:
                    try:
                        raw = tbl.extract()
                    except Exception:
                        continue
                    if not raw or len(raw) < 2:
                        continue
                    # 過濾只有一欄的偽表格
                    max_cols = max(len(row) for row in raw if row)
                    if max_cols < 2:
                        continue

                    # 判斷第一列是否為標題列
                    first_row = [str(c).strip() if c else "" for c in raw[0]]
                    rest_rows = raw[1:]

                    # 若第一列全是數字（可能是題號列），當作資料列而非標題
                    all_digits = all(re.match(r'^\d+$', c) or c == "" for c in first_row)
                    if all_digits or not any(first_row):
                        headers = []
                        data_rows = raw
                    else:
                        headers = first_row
                        data_rows = rest_rows

                    rows = []
                    for row in data_rows:
                        cleaned = [str(c).strip() if c else "" for c in row]
                        # 跳過全空白列
                        if any(cleaned):
                            rows.append(cleaned)

                    if not rows:
                        continue

                    # 標準化列寬：所有列補齊到最大欄數
                    max_c = max(len(r) for r in rows)
                    if headers:
                        while len(headers) < max_c:
                            headers.append("")
                    rows = [r + [""] * (max_c - len(r)) for r in rows]

                    results.append({
                        "page": page_idx,
                        "bbox": tbl.bbox,
                        "data": {"headers": headers, "rows": rows},
                    })
    except Exception as e:
        print(f"    ⚠  表格提取例外：{e}")

    return results

def _table_is_meaningful(table_data: dict) -> bool:
    """
    簡單品質過濾：排除 PDF 排版雜訊（例如「Fee C」這類欄位）。
    要求：
    - 非空白格 >= 6，或有效列數 >= 2（非空白格 >= 4）
    - 若只含 ASCII 字元（很可能是 PDF 頁尾雜訊），也排除
    """
    all_cells = []
    if table_data.get("headers"):
        all_cells.extend(table_data["headers"])
    for row in table_data.get("rows", []):
        all_cells.extend(row)

    non_empty = [c for c in all_cells if c and c.strip()]
    if len(non_empty) < 4:
        return False

    # 若所有有效格都是純 ASCII（無中文/日文/韓文），很可能是排版雜訊
    all_text = "".join(non_empty)
    has_cjk = bool(re.search(r'[一-鿿　-〿゠-ヿぁ-ゟ]', all_text))
    if not has_cjk and len(all_text) < 30:
        return False

    return True

def find_question_table(
    q_num: int,
    q_text: str,
    all_tables: list[dict],
    question_page_hint: int | None = None,
) -> dict | None:
    """
    在 all_tables 中找與 q_num 最相關的表格：
    - 有明確「如表」「下表」提示且只有一個有效表格時，直接採用
    - 否則依關鍵字比對分數決定
    傳回 table data dict 或 None。
    """
    if not all_tables:
        return None

    TABLE_HINT_RE = re.compile(r'如[右左上下]?表|下表|右表|以下.*表格|根據.*表|表\([一二三四五六七八九十\d]+\)')

    has_hint = bool(TABLE_HINT_RE.search(q_text))

    # 過濾品質不佳的表格
    quality_tables = [t for t in all_tables if _table_is_meaningful(t["data"])]

    if not quality_tables:
        return None

    if has_hint and len(quality_tables) == 1:
        return quality_tables[0]["data"]

    # 依關鍵字比對分數決定
    key_words = [w for w in re.findall(r'[一-鿿]{2,}', q_text) if len(w) >= 2][:8]
    best = None
    best_score = 0
    for t in quality_tables:
        flat = " ".join(
            cell
            for row in ([t["data"]["headers"]] + t["data"]["rows"])
            for cell in row
        )
        score = sum(1 for w in key_words if w in flat)
        if score > best_score:
            best_score = score
            best = t["data"]

    if best_score >= 2:
        return best

    return None

# ─────────────────────────────────────────────
# 圖形標記
# ─────────────────────────────────────────────

FIGURE_HINT_RE = re.compile(r'如[右左上下]?圖|下圖|右圖|附圖|見圖|參考圖|根據圖')

def has_figure_hint(text: str) -> bool:
    return bool(FIGURE_HINT_RE.search(text))

# ─────────────────────────────────────────────
# 題目解析（pdfplumber 文字抽取 + 題組 + 表格 + 圖形）
# ─────────────────────────────────────────────

def parse_questions_from_pdf(pdf_bytes: bytes, subject: str) -> list[dict]:
    """
    從試題 PDF 抽取選擇題，回傳：
    [{number, question_text, options,
      group_id, group_premise, group_order,
      table_json, has_figure}]
    """
    # ── 1. 逐頁取出文字與表格 ──────────────────────
    all_lines: list[str] = []
    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        for page in pdf.pages:
            text = page.extract_text() or ""
            all_lines.extend(text.split("\n"))

    # ── 2. 過濾無用行 ───────────────────────────────
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

    # ── 3. 題組偵測 ─────────────────────────────────
    group_map = detect_groups(filtered)

    # ── 4. 表格提取 ─────────────────────────────────
    all_tables = extract_page_tables(pdf_bytes)

    # ── 5. 選擇題解析（原有邏輯）──────────────────────
    Q_LINE  = re.compile(r'^(\d{1,2})[.．]\s*(.*)')

    opt_a_indices = [i for i, l in enumerate(filtered) if l.startswith('(A)')]

    seen: dict[int, dict] = {}

    for ai in opt_a_indices:
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
            if candidate.startswith('(D)'):
                break

        if q_num is None:
            continue

        opts: dict[str, str] = {'A': filtered[ai][4:].strip()}
        li = ai + 1
        for letter in 'BCD':
            while li < len(filtered):
                candidate = filtered[li]
                if candidate.startswith(f'({letter})'):
                    opts[letter] = candidate[4:].strip()
                    li += 1
                    break
                if Q_LINE.match(candidate):
                    try:
                        if int(Q_LINE.match(candidate).group(1)) > q_num:
                            break
                    except Exception:
                        pass
                if letter in opts and candidate and not candidate.startswith('('):
                    prev = opts[letter]
                    if prev:
                        opts[letter] = prev + ' ' + candidate
                li += 1

        stem_lines = filtered[q_start_idx:ai]
        first = stem_lines[0] if stem_lines else ''
        m = Q_LINE.match(first)
        if m:
            stem_lines[0] = m.group(2).strip()

        stem = ' '.join(l for l in stem_lines if l).strip()
        stem = re.sub(r'\s{2,}', ' ', stem)

        if len(stem) < 3:
            continue

        # 取最長題幹
        if q_num not in seen or len(stem) > len(seen[q_num]["question_text"]):
            seen[q_num] = {
                "number":       q_num,
                "question_text": stem,
                "options":      opts if len(opts) >= 2 else None,
            }

    questions = sorted(seen.values(), key=lambda x: x["number"])

    # ── 6. 附加題組、表格、圖形資訊 ──────────────────
    for q in questions:
        num  = q["number"]
        text = q["question_text"]

        # 題組
        if num in group_map:
            ginfo = group_map[num]
            q["group_id"]      = ginfo["group_id"]
            q["group_premise"] = ginfo["group_premise"]
            q["group_order"]   = ginfo["group_order"]
        else:
            q["group_id"]      = None
            q["group_premise"] = None
            q["group_order"]   = 0

        # 表格
        table_data = find_question_table(num, text, all_tables)
        if table_data:
            q["table_json"] = json.dumps(table_data, ensure_ascii=False)
        else:
            q["table_json"] = None

        # 圖形標記
        q["has_figure"] = has_figure_hint(text)

    return questions

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
    group_id              TEXT,
    group_premise         TEXT,
    group_order           INTEGER DEFAULT 0,
    table_json            TEXT,
    figure_image_name     TEXT,
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
    # 若 DB 已存在但缺少新欄位，自動補齊（向前相容）
    _ensure_columns(conn)
    conn.commit()

def _ensure_columns(conn):
    """為舊版 DB 補充新欄位（idempotent）。"""
    new_cols = [
        ("group_id",          "TEXT"),
        ("group_premise",     "TEXT"),
        ("group_order",       "INTEGER DEFAULT 0"),
        ("table_json",        "TEXT"),
        ("figure_image_name", "TEXT"),
    ]
    cur = conn.execute("PRAGMA table_info(question_bank)")
    existing = {row[1] for row in cur.fetchall()}
    for col_name, col_def in new_cols:
        if col_name not in existing:
            conn.execute(f"ALTER TABLE question_bank ADD COLUMN {col_name} {col_def}")
            print(f"    ℹ  已補充欄位：{col_name}")

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

            # 統計題組/表格/圖形
            n_groups  = len({q.get("group_id") for q in questions if q.get("group_id")})
            n_tables  = sum(1 for q in questions if q.get("table_json"))
            n_figures = sum(1 for q in questions if q.get("has_figure"))
            print(f" → {len(questions)} 題  題組:{n_groups}  表格:{n_tables}  有圖:{n_figures}")

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
                topic = chname

                conn.execute(
                    """INSERT INTO question_bank
                       (source_exam_id, year, subject, volume, chapter_num, chapter_name,
                        topic, question_num, question_text, question_type,
                        option_a, option_b, option_c, option_d,
                        correct_answer, pass_rate, difficulty, explanation, first_attempt_correct,
                        group_id, group_premise, group_order, table_json, figure_image_name)
                       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (
                        exam_id, year, subject,
                        vol or None, chnum or None, chname or None,
                        topic or None, num,
                        q["question_text"], "選擇題",
                        opts.get("A"), opts.get("B"), opts.get("C"), opts.get("D"),
                        ans, pr, diff, "", None,
                        q.get("group_id"),
                        q.get("group_premise"),
                        q.get("group_order", 0),
                        q.get("table_json"),
                        None,  # figure_image_name: 文字解析無法取得圖片，留 NULL
                    )
                )
                inserted += 1

            conn.commit()
            print(f"    ✅ {inserted} 題入庫")

    # 統計
    total   = conn.execute("SELECT COUNT(*) FROM question_bank").fetchone()[0]
    w_pr    = conn.execute("SELECT COUNT(*) FROM question_bank WHERE pass_rate IS NOT NULL").fetchone()[0]
    w_ans   = conn.execute("SELECT COUNT(*) FROM question_bank WHERE correct_answer IS NOT NULL").fetchone()[0]
    w_group = conn.execute("SELECT COUNT(*) FROM question_bank WHERE group_id IS NOT NULL").fetchone()[0]
    w_table = conn.execute("SELECT COUNT(*) FROM question_bank WHERE table_json IS NOT NULL").fetchone()[0]
    conn.close()

    print(f"\n{'='*55}")
    print(f"🎉 完成！")
    print(f"   總題數：{total}")
    print(f"   有通過率：{w_pr}")
    print(f"   有答案：{w_ans}")
    print(f"   題組題：{w_group}")
    print(f"   含表格：{w_table}")
    print(f"   輸出：{DB_PATH}")
    print(f"\n下一步：")
    print(f"   cp {DB_PATH} ../exam_data.db")

if __name__ == "__main__":
    main()
