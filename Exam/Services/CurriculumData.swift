import Foundation

// Sendable 讓此型別可安全跨 actor 邊界傳遞（Swift 6 要求）
struct CurriculumChapter: Sendable {
    let chapterNum: Int
    let name: String
    var label: String { "第\(chapterNum)章 \(name)" }
}

enum CurriculumData {
    static let subjects = [
        "數學", "國文", "英語",
        "社會-地理", "社會-歷史", "社會-公民",
        "自然-生物", "自然-理化", "自然-地科"
    ]
    static let volumes = ["七上", "七下", "八上", "八下", "九上", "九下"]

    static let curriculum: [String: [String: [CurriculumChapter]]] = [
        "數學": [
            "七上": [.init(chapterNum: 1, name: "整數的四則運算"), .init(chapterNum: 2, name: "因數與倍數"), .init(chapterNum: 3, name: "分數與小數的運算"), .init(chapterNum: 4, name: "比與比例式"), .init(chapterNum: 5, name: "一元一次方程式")],
            "七下": [.init(chapterNum: 1, name: "直角坐標"), .init(chapterNum: 2, name: "一元一次不等式"), .init(chapterNum: 3, name: "平面圖形"), .init(chapterNum: 4, name: "空間概念")],
            "八上": [.init(chapterNum: 1, name: "乘法公式與多項式"), .init(chapterNum: 2, name: "因式分解"), .init(chapterNum: 3, name: "平方根與畢氏定理"), .init(chapterNum: 4, name: "線型函數")],
            "八下": [.init(chapterNum: 1, name: "一元二次方程式"), .init(chapterNum: 2, name: "三角形"), .init(chapterNum: 3, name: "平行四邊形與梯形"), .init(chapterNum: 4, name: "統計")],
            "九上": [.init(chapterNum: 1, name: "二次函數"), .init(chapterNum: 2, name: "相似形"), .init(chapterNum: 3, name: "圓")],
            "九下": [.init(chapterNum: 1, name: "三角比"), .init(chapterNum: 2, name: "空間圖形"), .init(chapterNum: 3, name: "機率")]
        ],
        "國文": [
            "七上": [.init(chapterNum: 1, name: "字詞辨析與語文基礎"), .init(chapterNum: 2, name: "記敘文閱讀"), .init(chapterNum: 3, name: "抒情文閱讀"), .init(chapterNum: 4, name: "說明文閱讀"), .init(chapterNum: 5, name: "古典詩詞"), .init(chapterNum: 6, name: "文言文基礎")],
            "七下": [.init(chapterNum: 1, name: "成語與慣用語"), .init(chapterNum: 2, name: "議論文閱讀"), .init(chapterNum: 3, name: "現代散文"), .init(chapterNum: 4, name: "古典散文"), .init(chapterNum: 5, name: "古典詩詞（二）"), .init(chapterNum: 6, name: "修辭技巧")],
            "八上": [.init(chapterNum: 1, name: "文言文閱讀（史傳）"), .init(chapterNum: 2, name: "古典詩詞（三）"), .init(chapterNum: 3, name: "現代小說"), .init(chapterNum: 4, name: "語法句型"), .init(chapterNum: 5, name: "文學鑑賞"), .init(chapterNum: 6, name: "應用文體")],
            "八下": [.init(chapterNum: 1, name: "文言文閱讀（諸子）"), .init(chapterNum: 2, name: "古典詩詞（四）"), .init(chapterNum: 3, name: "現代詩"), .init(chapterNum: 4, name: "標點符號與句型變換"), .init(chapterNum: 5, name: "跨文本閱讀"), .init(chapterNum: 6, name: "圖表與非連續文本")],
            "九上": [.init(chapterNum: 1, name: "文言文閱讀（唐宋）"), .init(chapterNum: 2, name: "古典詩詞（五）"), .init(chapterNum: 3, name: "文學與文化"), .init(chapterNum: 4, name: "議題閱讀"), .init(chapterNum: 5, name: "綜合寫作技巧")],
            "九下": [.init(chapterNum: 1, name: "文言文閱讀（明清）"), .init(chapterNum: 2, name: "古典詩詞（六）"), .init(chapterNum: 3, name: "現代文學精選"), .init(chapterNum: 4, name: "閱讀素養綜合演練")]
        ],
        "英語": [
            "七上": [.init(chapterNum: 1, name: "自我介紹與基本問候（be動詞）"), .init(chapterNum: 2, name: "日常生活描述（一般現在式）"), .init(chapterNum: 3, name: "家庭與學校（指示代名詞）"), .init(chapterNum: 4, name: "時間與數字（疑問詞）"), .init(chapterNum: 5, name: "購物與價格（there is/are）"), .init(chapterNum: 6, name: "活動與嗜好（現在進行式）")],
            "七下": [.init(chapterNum: 1, name: "過去式（規則動詞）"), .init(chapterNum: 2, name: "過去式（不規則動詞）"), .init(chapterNum: 3, name: "未來式（will/be going to）"), .init(chapterNum: 4, name: "比較級與最高級"), .init(chapterNum: 5, name: "連接詞與複合句"), .init(chapterNum: 6, name: "情態助動詞（can/should/must）")],
            "八上": [.init(chapterNum: 1, name: "現在完成式"), .init(chapterNum: 2, name: "被動語態"), .init(chapterNum: 3, name: "不定詞與動名詞"), .init(chapterNum: 4, name: "形容詞子句（關係代名詞）"), .init(chapterNum: 5, name: "副詞子句（時間/原因）"), .init(chapterNum: 6, name: "間接問句")],
            "八下": [.init(chapterNum: 1, name: "過去完成式"), .init(chapterNum: 2, name: "假設語氣（if子句）"), .init(chapterNum: 3, name: "分詞構句"), .init(chapterNum: 4, name: "名詞子句（that/whether）"), .init(chapterNum: 5, name: "倒裝句與強調句"), .init(chapterNum: 6, name: "閱讀策略（推論/摘要）")],
            "九上": [.init(chapterNum: 1, name: "綜合文法複習（時態）"), .init(chapterNum: 2, name: "綜合文法複習（句型）"), .init(chapterNum: 3, name: "閱讀理解（記敘/說明）"), .init(chapterNum: 4, name: "詞彙與片語（高頻字）")],
            "九下": [.init(chapterNum: 1, name: "閱讀理解（議論/圖表）"), .init(chapterNum: 2, name: "聽力與口語應用"), .init(chapterNum: 3, name: "寫作技巧（段落寫作）"), .init(chapterNum: 4, name: "綜合素養演練")]
        ],
        "社會-地理": [
            "七上": [.init(chapterNum: 1, name: "認識地球與地圖"), .init(chapterNum: 2, name: "台灣的位置與地形"), .init(chapterNum: 3, name: "台灣的氣候"), .init(chapterNum: 4, name: "台灣的水文與土壤")],
            "七下": [.init(chapterNum: 1, name: "台灣的人口"), .init(chapterNum: 2, name: "台灣的產業"), .init(chapterNum: 3, name: "台灣的都市與交通"), .init(chapterNum: 4, name: "台灣的環境議題")],
            "八上": [.init(chapterNum: 1, name: "東亞的自然環境"), .init(chapterNum: 2, name: "東亞的人文環境"), .init(chapterNum: 3, name: "東南亞"), .init(chapterNum: 4, name: "南亞與西亞")],
            "八下": [.init(chapterNum: 1, name: "歐洲"), .init(chapterNum: 2, name: "非洲"), .init(chapterNum: 3, name: "美洲"), .init(chapterNum: 4, name: "大洋洲與極地")],
            "九上": [.init(chapterNum: 1, name: "全球化與在地化"), .init(chapterNum: 2, name: "人口問題與都市化"), .init(chapterNum: 3, name: "糧食問題與農業"), .init(chapterNum: 4, name: "能源與工業")],
            "九下": [.init(chapterNum: 1, name: "全球環境變遷"), .init(chapterNum: 2, name: "地理資訊與永續發展")]
        ],
        "社會-歷史": [
            "七上": [.init(chapterNum: 1, name: "台灣史前文化與原住民"), .init(chapterNum: 2, name: "荷西與明鄭時期"), .init(chapterNum: 3, name: "清朝統治前期"), .init(chapterNum: 4, name: "清朝統治後期")],
            "七下": [.init(chapterNum: 1, name: "日本統治時期（政治）"), .init(chapterNum: 2, name: "日本統治時期（社會經濟）"), .init(chapterNum: 3, name: "戰後台灣政治發展"), .init(chapterNum: 4, name: "戰後台灣經濟與社會")],
            "八上": [.init(chapterNum: 1, name: "中國史前文化與夏商周"), .init(chapterNum: 2, name: "春秋戰國"), .init(chapterNum: 3, name: "秦漢帝國"), .init(chapterNum: 4, name: "魏晉南北朝")],
            "八下": [.init(chapterNum: 1, name: "隋唐時期"), .init(chapterNum: 2, name: "宋代"), .init(chapterNum: 3, name: "元明清"), .init(chapterNum: 4, name: "中國近代史（鴉片戰爭至五四）")],
            "九上": [.init(chapterNum: 1, name: "古代文明（兩河/埃及/印度）"), .init(chapterNum: 2, name: "希臘羅馬"), .init(chapterNum: 3, name: "中世紀歐洲"), .init(chapterNum: 4, name: "文藝復興與宗教改革")],
            "九下": [.init(chapterNum: 1, name: "大航海與殖民"), .init(chapterNum: 2, name: "工業革命與民主發展"), .init(chapterNum: 3, name: "兩次世界大戰"), .init(chapterNum: 4, name: "冷戰與當代世界")]
        ],
        "社會-公民": [
            "七上": [.init(chapterNum: 1, name: "個人與社會"), .init(chapterNum: 2, name: "文化與社會"), .init(chapterNum: 3, name: "社會變遷")],
            "七下": [.init(chapterNum: 1, name: "法律的基本概念"), .init(chapterNum: 2, name: "民法與日常生活"), .init(chapterNum: 3, name: "刑法與犯罪防治")],
            "八上": [.init(chapterNum: 1, name: "經濟基本概念"), .init(chapterNum: 2, name: "市場與價格"), .init(chapterNum: 3, name: "政府的經濟角色")],
            "八下": [.init(chapterNum: 1, name: "政治的基本概念"), .init(chapterNum: 2, name: "民主政治的運作"), .init(chapterNum: 3, name: "政府組織")],
            "九上": [.init(chapterNum: 1, name: "人權與公民權"), .init(chapterNum: 2, name: "中華民國憲法"), .init(chapterNum: 3, name: "選舉與公民參與")],
            "九下": [.init(chapterNum: 1, name: "國際關係"), .init(chapterNum: 2, name: "全球議題（人權/環境/永續）"), .init(chapterNum: 3, name: "台灣的國際參與")]
        ],
        "自然-生物": [
            "七上": [.init(chapterNum: 1, name: "生物的特徵與分類"), .init(chapterNum: 2, name: "細胞的構造與功能"), .init(chapterNum: 3, name: "細胞的分裂"), .init(chapterNum: 4, name: "生物多樣性")],
            "七下": [.init(chapterNum: 1, name: "植物的構造與功能"), .init(chapterNum: 2, name: "植物的生殖"), .init(chapterNum: 3, name: "動物的構造（消化/循環）"), .init(chapterNum: 4, name: "動物的構造（呼吸/排泄/神經）")],
            "八上": [.init(chapterNum: 1, name: "生態系的結構"), .init(chapterNum: 2, name: "生態系的能量流動"), .init(chapterNum: 3, name: "物質循環"), .init(chapterNum: 4, name: "生態保育")],
            "九上": [.init(chapterNum: 1, name: "生殖方式"), .init(chapterNum: 2, name: "遺傳與基因"), .init(chapterNum: 3, name: "DNA與遺傳密碼"), .init(chapterNum: 4, name: "演化與天擇")]
        ],
        "自然-理化": [
            "八上": [.init(chapterNum: 1, name: "物質的組成（元素/化合物）"), .init(chapterNum: 2, name: "原子與週期表"), .init(chapterNum: 3, name: "化學反應與方程式"), .init(chapterNum: 4, name: "水溶液（酸鹼鹽）")],
            "八下": [.init(chapterNum: 1, name: "運動的描述（速度/加速度）"), .init(chapterNum: 2, name: "力與牛頓運動定律"), .init(chapterNum: 3, name: "功與能"), .init(chapterNum: 4, name: "熱與溫度")],
            "九上": [.init(chapterNum: 1, name: "波動與聲音"), .init(chapterNum: 2, name: "光的反射與折射"), .init(chapterNum: 3, name: "靜電與電流"), .init(chapterNum: 4, name: "電路與電功率")],
            "九下": [.init(chapterNum: 1, name: "磁場與電磁感應"), .init(chapterNum: 2, name: "原子結構與放射性"), .init(chapterNum: 3, name: "有機化合物"), .init(chapterNum: 4, name: "化學反應速率與平衡")]
        ],
        "自然-地科": [
            "七上": [.init(chapterNum: 1, name: "地球的構造"), .init(chapterNum: 2, name: "地殼的變動（板塊構造）"), .init(chapterNum: 3, name: "岩石與礦物"), .init(chapterNum: 4, name: "地質作用（侵蝕/堆積）")],
            "七下": [.init(chapterNum: 1, name: "大氣的組成與結構"), .init(chapterNum: 2, name: "天氣與氣象"), .init(chapterNum: 3, name: "海洋與洋流"), .init(chapterNum: 4, name: "水循環與地下水")],
            "九下": [.init(chapterNum: 1, name: "太陽系與行星運動"), .init(chapterNum: 2, name: "月球與潮汐"), .init(chapterNum: 3, name: "宇宙的結構與演化")]
        ]
    ]

    // static let（非 lazy var）確保不受 @MainActor 推斷影響，可從任意並發上下文存取
    static let jsonString: String = {
        var ref: [String: [String: [String]]] = [:]
        for (subject, vols) in curriculum {
            ref[subject] = [:]
            for (vol, chapters) in vols {
                ref[subject]![vol] = chapters.map { $0.label }
            }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: ref, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }()

    static func chapters(for subject: String, volume: String) -> [CurriculumChapter] {
        curriculum[subject]?[volume] ?? []
    }

    static func chapterName(subject: String, volume: String, chapterNum: Int) -> String {
        curriculum[subject]?[volume]?.first { $0.chapterNum == chapterNum }?.name ?? "未知章節"
    }

    static func allChapters(for subject: String) -> [(volume: String, chapter: CurriculumChapter)] {
        volumes.flatMap { vol in
            (curriculum[subject]?[vol] ?? []).map { (volume: vol, chapter: $0) }
        }
    }
}
