--[[
    ================================================================
    Tower of Zombies Hub — Tower of Zombies
    Created by Rival960 with the help of Claude
    Version: v1.1.0 | Languages: 21 | Rayfield UI
    Status: tested in-game
    ================================================================
]]

-- Services
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- ================================================================
-- Language System (21 languages)
-- ================================================================
local CurrentLang = "EN"

local Translations = {
    EN = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "by Rival960",
        TabHome             = "Home",
        TabCombat           = "Combat",
        TabMovement         = "Movement",
        TabTools            = "Tools & Visuals",
        CreditsTitle        = "Credits",
        CreditsContent      = "Created by Rival960 with the help of AI\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Combat Update",
        ReleaseNotesTitle   = "v1.1.0 — Release Notes",
        ReleaseNotesContent = "New in v1.1.0: Infinite Ammo, Freeze Ammo, Aimbot wall-penetration fix, ammo hook system.\nFound a bug or want to request a feature? Open an issue on GitHub (Rival99900/Roblox-Scripts) or post on ScriptBlox.",
        Aimbot              = "Aimbot",
        AutoBring           = "Auto Bring",
        BringRadius         = "Bring Radius (studs)",
        BringInterval       = "Bring Interval (s)",
        MaxZombieDist       = "Max Zombie Distance",
        InfiniteAmmo        = "Infinite Ammo",
        FreezeAmmo          = "Freeze Ammo",
        FlyToggle           = "Fly",
        FlySpeed            = "Fly Speed",
        NoClip              = "NoClip",
        WalkSpeed           = "Walk Speed",
        InfJump             = "Infinite Jump",
        AntiAFK             = "Anti-AFK",
        Fullbright          = "Fullbright",
        LanguageSelect      = "Language",
        LangNote            = "Language change requires re-execution",
    },
    FR = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "par Rival960",
        TabHome             = "Accueil",
        TabCombat           = "Combat",
        TabMovement         = "Déplacement",
        TabTools            = "Outils & Visuels",
        CreditsTitle        = "Crédits",
        CreditsContent      = "Créé par Rival960 avec l'aide de l'IA\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Mise à Jour Combat",
        ReleaseNotesTitle   = "v1.1.0 — Notes de Version",
        ReleaseNotesContent = "Nouveau en v1.1.0 : Munitions Infinies, Geler les Munitions, correction de pénétration des murs de l'Aimbot, système de hooks de munitions.\nVous avez trouvé un bug ou souhaitez demander une fonctionnalité ? Ouvrez un ticket sur GitHub (Rival99900/Roblox-Scripts) ou postez sur ScriptBlox.",
        Aimbot              = "Aimbot",
        AutoBring           = "Auto Attirer",
        BringRadius         = "Rayon d'attrait (studs)",
        BringInterval       = "Intervalle d'attrait (s)",
        MaxZombieDist       = "Distance Max Zombie",
        InfiniteAmmo        = "Munitions Infinies",
        FreezeAmmo          = "Geler les Munitions",
        FlyToggle           = "Vol",
        FlySpeed            = "Vitesse de Vol",
        NoClip              = "NoClip",
        WalkSpeed           = "Vitesse de Marche",
        InfJump             = "Saut Infini",
        AntiAFK             = "Anti-AFK",
        Fullbright          = "Luminosité Max",
        LanguageSelect      = "Langue",
        LangNote            = "Le changement de langue nécessite une ré-exécution",
    },
    DE = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "von Rival960",
        TabHome             = "Start",
        TabCombat           = "Kampf",
        TabMovement         = "Bewegung",
        TabTools            = "Tools & Visuals",
        CreditsTitle        = "Credits",
        CreditsContent      = "Erstellt von Rival960 mit KI-Hilfe\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Kampf-Update",
        ReleaseNotesTitle   = "v1.1.0 — Versionshinweise",
        ReleaseNotesContent = "Neu in v1.1.0: Unendlich Munition, Munition Einfrieren, Aimbot Wanddurchdringungsfix, Munitions-Hook-System.\nBug gefunden oder Feature-Wunsch? Erstelle ein Issue auf GitHub (Rival99900/Roblox-Scripts) oder schreibe auf ScriptBlox.",
        Aimbot              = "Aimbot",
        AutoBring           = "Auto Anziehen",
        BringRadius         = "Anzugsradius (studs)",
        BringInterval       = "Anzugsintervall (s)",
        MaxZombieDist       = "Max Zombie-Distanz",
        InfiniteAmmo        = "Unendlich Munition",
        FreezeAmmo          = "Munition Einfrieren",
        FlyToggle           = "Fliegen",
        FlySpeed            = "Fluggeschwindigkeit",
        NoClip              = "NoClip",
        WalkSpeed           = "Laufgeschwindigkeit",
        InfJump             = "Unendlicher Sprung",
        AntiAFK             = "Anti-AFK",
        Fullbright          = "Vollhelligkeit",
        LanguageSelect      = "Sprache",
        LangNote            = "Sprachänderung erfordert Neuausführung",
    },
    ES = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "por Rival960",
        TabHome             = "Inicio",
        TabCombat           = "Combate",
        TabMovement         = "Movimiento",
        TabTools            = "Herramientas",
        CreditsTitle        = "Créditos",
        CreditsContent      = "Creado por Rival960 con ayuda de IA\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Actualización de Combate",
        ReleaseNotesTitle   = "v1.1.0 — Notas de Versión",
        ReleaseNotesContent = "Nuevo en v1.1.0: Munición Infinita, Congelar Munición, corrección de penetración de muros del Aimbot, sistema de ganchos de munición.\n¿Encontraste un error o quieres pedir una función? Abre un issue en GitHub (Rival99900/Roblox-Scripts) o publica en ScriptBlox.",
        Aimbot              = "Aimbot",
        AutoBring           = "Auto Atraer",
        BringRadius         = "Radio de Atracción (studs)",
        BringInterval       = "Intervalo de Atracción (s)",
        MaxZombieDist       = "Distancia Máx Zombie",
        InfiniteAmmo        = "Munición Infinita",
        FreezeAmmo          = "Congelar Munición",
        FlyToggle           = "Volar",
        FlySpeed            = "Velocidad de Vuelo",
        NoClip              = "NoClip",
        WalkSpeed           = "Velocidad de Caminar",
        InfJump             = "Salto Infinito",
        AntiAFK             = "Anti-AFK",
        Fullbright          = "Brillo Total",
        LanguageSelect      = "Idioma",
        LangNote            = "El cambio de idioma requiere re-ejecución",
    },
    PT = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "por Rival960",
        TabHome             = "Início",
        TabCombat           = "Combate",
        TabMovement         = "Movimento",
        TabTools            = "Ferramentas",
        CreditsTitle        = "Créditos",
        CreditsContent      = "Criado por Rival960 com ajuda de IA\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Atualização de Combate",
        ReleaseNotesTitle   = "v1.1.0 — Notas da Versão",
        ReleaseNotesContent = "Novo em v1.1.0: Munição Infinita, Congelar Munição, correção de penetração de paredes do Aimbot, sistema de hooks de munição.\nEncontrou um bug ou quer sugerir uma função? Abra uma issue no GitHub (Rival99900/Roblox-Scripts) ou publique no ScriptBlox.",
        Aimbot              = "Aimbot",
        AutoBring           = "Auto Atrair",
        BringRadius         = "Raio de Atração (studs)",
        BringInterval       = "Intervalo de Atração (s)",
        MaxZombieDist       = "Distância Máx Zumbi",
        InfiniteAmmo        = "Munição Infinita",
        FreezeAmmo          = "Congelar Munição",
        FlyToggle           = "Voar",
        FlySpeed            = "Velocidade de Voo",
        NoClip              = "NoClip",
        WalkSpeed           = "Velocidade de Caminhada",
        InfJump             = "Salto Infinito",
        AntiAFK             = "Anti-AFK",
        Fullbright          = "Brilho Total",
        LanguageSelect      = "Idioma",
        LangNote            = "Mudança de idioma requer re-execução",
    },
    RU = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "от Rival960",
        TabHome             = "Главная",
        TabCombat           = "Бой",
        TabMovement         = "Движение",
        TabTools            = "Инструменты",
        CreditsTitle        = "Авторы",
        CreditsContent      = "Создано Rival960 с помощью ИИ\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Боевое Обновление",
        ReleaseNotesTitle   = "v1.1.0 — Примечания к версии",
        ReleaseNotesContent = "Новое в v1.1.0: Бесконечные патроны, Заморозить патроны, исправление проникновения сквозь стены аимбота, система хуков патронов.\nНашли баг или хотите предложить функцию? Создайте issue на GitHub (Rival99900/Roblox-Scripts) или напишите на ScriptBlox.",
        Aimbot              = "Аимбот",
        AutoBring           = "Авто Притяжение",
        BringRadius         = "Радиус притяжения (ст.)",
        BringInterval       = "Интервал притяжения (с)",
        MaxZombieDist       = "Макс дистанция зомби",
        InfiniteAmmo        = "Бесконечные патроны",
        FreezeAmmo          = "Заморозить патроны",
        FlyToggle           = "Полёт",
        FlySpeed            = "Скорость полёта",
        NoClip              = "NoClip",
        WalkSpeed           = "Скорость ходьбы",
        InfJump             = "Бесконечный прыжок",
        AntiAFK             = "Анти-АФК",
        Fullbright          = "Полная яркость",
        LanguageSelect      = "Язык",
        LangNote            = "Смена языка требует повторного запуска",
    },
    IT = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "di Rival960",
        TabHome             = "Home",
        TabCombat           = "Combattimento",
        TabMovement         = "Movimento",
        TabTools            = "Strumenti",
        CreditsTitle        = "Crediti",
        CreditsContent      = "Creato da Rival960 con l'aiuto dell'IA\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Aggiornamento Combattimento",
        ReleaseNotesTitle   = "v1.1.0 — Note di Versione",
        ReleaseNotesContent = "Nuovo in v1.1.0: Munizioni Infinite, Blocca Munizioni, fix penetrazione pareti Aimbot, sistema di hook munizioni.\nHai trovato un bug o vuoi richiedere una funzione? Apri un'issue su GitHub (Rival99900/Roblox-Scripts) o scrivi su ScriptBlox.",
        Aimbot              = "Aimbot",
        AutoBring           = "Auto Attira",
        BringRadius         = "Raggio di Attrazione (studs)",
        BringInterval       = "Intervallo di Attrazione (s)",
        MaxZombieDist       = "Distanza Max Zombie",
        InfiniteAmmo        = "Munizioni Infinite",
        FreezeAmmo          = "Blocca Munizioni",
        FlyToggle           = "Volo",
        FlySpeed            = "Velocità di Volo",
        NoClip              = "NoClip",
        WalkSpeed           = "Velocità di Camminata",
        InfJump             = "Salto Infinito",
        AntiAFK             = "Anti-AFK",
        Fullbright          = "Piena Luminosità",
        LanguageSelect      = "Lingua",
        LangNote            = "Il cambio lingua richiede una ri-esecuzione",
    },
    NL = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "door Rival960",
        TabHome             = "Start",
        TabCombat           = "Gevecht",
        TabMovement         = "Beweging",
        TabTools            = "Tools & Visuals",
        CreditsTitle        = "Credits",
        CreditsContent      = "Gemaakt door Rival960 met AI-hulp\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Gevechtsupdate",
        ReleaseNotesTitle   = "v1.1.0 — Versienotities",
        ReleaseNotesContent = "Nieuw in v1.1.0: Oneindige Munitie, Bevriezing Munitie, Aimbot muurpenetratie fix, munitie hook systeem.\nBug gevonden of wil je een functie aanvragen? Open een issue op GitHub (Rival99900/Roblox-Scripts) of post op ScriptBlox.",
        Aimbot              = "Aimbot",
        AutoBring           = "Auto Aantrekken",
        BringRadius         = "Aantrekkingsradius (studs)",
        BringInterval       = "Aantrekkingsinterval (s)",
        MaxZombieDist       = "Max Zombie Afstand",
        InfiniteAmmo        = "Oneindige Munitie",
        FreezeAmmo          = "Bevriezing Munitie",
        FlyToggle           = "Vliegen",
        FlySpeed            = "Vliegsnelheid",
        NoClip              = "NoClip",
        WalkSpeed           = "Loopsnelheid",
        InfJump             = "Oneindig Springen",
        AntiAFK             = "Anti-AFK",
        Fullbright          = "Maximale Helderheid",
        LanguageSelect      = "Taal",
        LangNote            = "Taalwijziging vereist heruitvoering",
    },
    PL = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "przez Rival960",
        TabHome             = "Strona główna",
        TabCombat           = "Walka",
        TabMovement         = "Ruch",
        TabTools            = "Narzędzia",
        CreditsTitle        = "Kredyty",
        CreditsContent      = "Stworzone przez Rival960 z pomocą AI\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Aktualizacja Walki",
        ReleaseNotesTitle   = "v1.1.0 — Informacje o Wersji",
        ReleaseNotesContent = "Nowe w v1.1.0: Nieskończona Amunicja, Zamroź Amunicję, naprawa przenikania przez ściany Aimbot, system haków amunicji.\nZnalazłeś błąd lub chcesz zgłosić funkcję? Otwórz issue na GitHub (Rival99900/Roblox-Scripts) lub napisz na ScriptBlox.",
        Aimbot              = "Aimbot",
        AutoBring           = "Auto Przyciąganie",
        BringRadius         = "Promień przyciągania (studs)",
        BringInterval       = "Interwał przyciągania (s)",
        MaxZombieDist       = "Maks. dystans zombie",
        InfiniteAmmo        = "Nieskończona Amunicja",
        FreezeAmmo          = "Zamroź Amunicję",
        FlyToggle           = "Latanie",
        FlySpeed            = "Prędkość lotu",
        NoClip              = "NoClip",
        WalkSpeed           = "Prędkość chodu",
        InfJump             = "Nieskończony Skok",
        AntiAFK             = "Anti-AFK",
        Fullbright          = "Pełna jasność",
        LanguageSelect      = "Język",
        LangNote            = "Zmiana języka wymaga ponownego uruchomienia",
    },
    ZH = {
        WindowTitle         = "行尸走肉枢纽",
        WindowSubtitle      = "由 Rival960",
        TabHome             = "主页",
        TabCombat           = "战斗",
        TabMovement         = "移动",
        TabTools            = "工具与视觉",
        CreditsTitle        = "致谢",
        CreditsContent      = "由 Rival960 借助 AI 创建\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — 战斗更新",
        ReleaseNotesTitle   = "v1.1.0 — 版本说明",
        ReleaseNotesContent = "v1.1.0 新内容：无限弹药、冻结弹药、瞄准助手穿墙修复、弹药钩子系统。\n发现漏洞或想申请功能？请在 GitHub (Rival99900/Roblox-Scripts) 提交 issue 或在 ScriptBlox 发帖。",
        Aimbot              = "自动瞄准",
        AutoBring           = "自动吸引",
        BringRadius         = "吸引半径 (格)",
        BringInterval       = "吸引间隔 (秒)",
        MaxZombieDist       = "最大僵尸距离",
        InfiniteAmmo        = "无限弹药",
        FreezeAmmo          = "冻结弹药",
        FlyToggle           = "飞行",
        FlySpeed            = "飞行速度",
        NoClip              = "穿墙",
        WalkSpeed           = "行走速度",
        InfJump             = "无限跳跃",
        AntiAFK             = "防离线",
        Fullbright          = "全亮",
        LanguageSelect      = "语言",
        LangNote            = "语言更改需要重新执行",
    },
    JA = {
        WindowTitle         = "ゾンビタワーハブ",
        WindowSubtitle      = "Rival960 制作",
        TabHome             = "ホーム",
        TabCombat           = "戦闘",
        TabMovement         = "移動",
        TabTools            = "ツール",
        CreditsTitle        = "クレジット",
        CreditsContent      = "Rival960 と AI の協力で作成\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — 戦闘アップデート",
        ReleaseNotesTitle   = "v1.1.0 — リリースノート",
        ReleaseNotesContent = "v1.1.0の新機能：無限弾薬、弾薬固定、エイムボット壁貫通修正、弾薬フックシステム。\nバグ発見や機能リクエストはGitHub (Rival99900/Roblox-Scripts) のissueまたはScriptBloxに投稿してください。",
        Aimbot              = "エイムボット",
        AutoBring           = "自動引き寄せ",
        BringRadius         = "引き寄せ半径 (スタッド)",
        BringInterval       = "引き寄せ間隔 (秒)",
        MaxZombieDist       = "最大ゾンビ距離",
        InfiniteAmmo        = "無限弾薬",
        FreezeAmmo          = "弾薬固定",
        FlyToggle           = "フライ",
        FlySpeed            = "飛行速度",
        NoClip              = "ノークリップ",
        WalkSpeed           = "歩行速度",
        InfJump             = "無限ジャンプ",
        AntiAFK             = "アンチAFK",
        Fullbright          = "フルブライト",
        LanguageSelect      = "言語",
        LangNote            = "言語変更は再実行が必要です",
    },
    TR = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "Rival960 tarafından",
        TabHome             = "Ana Sayfa",
        TabCombat           = "Savaş",
        TabMovement         = "Hareket",
        TabTools            = "Araçlar",
        CreditsTitle        = "Krediler",
        CreditsContent      = "Rival960 tarafından AI yardımıyla yapılmıştır\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Savaş Güncellemesi",
        ReleaseNotesTitle   = "v1.1.0 — Sürüm Notları",
        ReleaseNotesContent = "v1.1.0'daki yenilikler: Sonsuz Mermi, Mermiyi Dondur, Aimbot duvar nüfuz düzeltmesi, mermi kanca sistemi.\nBir hata buldunuz veya özellik talep etmek mi istiyorsunuz? GitHub'da (Rival99900/Roblox-Scripts) issue açın veya ScriptBlox'ta paylaşın.",
        Aimbot              = "Aimbot",
        AutoBring           = "Otomatik Çekme",
        BringRadius         = "Çekme Yarıçapı (studs)",
        BringInterval       = "Çekme Aralığı (s)",
        MaxZombieDist       = "Maks Zombi Mesafesi",
        InfiniteAmmo        = "Sonsuz Mermi",
        FreezeAmmo          = "Mermiyi Dondur",
        FlyToggle           = "Uçuş",
        FlySpeed            = "Uçuş Hızı",
        NoClip              = "NoClip",
        WalkSpeed           = "Yürüyüş Hızı",
        InfJump             = "Sonsuz Zıplama",
        AntiAFK             = "Anti-AFK",
        Fullbright          = "Tam Parlaklık",
        LanguageSelect      = "Dil",
        LangNote            = "Dil değişikliği yeniden başlatma gerektirir",
    },
    KO = {
        WindowTitle         = "좀비 타워 허브",
        WindowSubtitle      = "Rival960 제작",
        TabHome             = "홈",
        TabCombat           = "전투",
        TabMovement         = "이동",
        TabTools            = "도구",
        CreditsTitle        = "크레딧",
        CreditsContent      = "Rival960이 AI의 도움으로 제작\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — 전투 업데이트",
        ReleaseNotesTitle   = "v1.1.0 — 릴리즈 노트",
        ReleaseNotesContent = "v1.1.0 새 기능: 무한 탄약, 탄약 고정, 에임봇 벽 관통 수정, 탄약 훅 시스템.\n버그를 찾거나 기능을 요청하고 싶다면? GitHub (Rival99900/Roblox-Scripts)에 이슈를 열거나 ScriptBlox에 게시하세요.",
        Aimbot              = "에임봇",
        AutoBring           = "자동 끌어오기",
        BringRadius         = "끌어오기 반경 (스터드)",
        BringInterval       = "끌어오기 간격 (초)",
        MaxZombieDist       = "최대 좀비 거리",
        InfiniteAmmo        = "무한 탄약",
        FreezeAmmo          = "탄약 고정",
        FlyToggle           = "비행",
        FlySpeed            = "비행 속도",
        NoClip              = "노클립",
        WalkSpeed           = "걷기 속도",
        InfJump             = "무한 점프",
        AntiAFK             = "Anti-AFK",
        Fullbright          = "전체 밝기",
        LanguageSelect      = "언어",
        LangNote            = "언어 변경은 재실행이 필요합니다",
    },
    AR = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "بواسطة Rival960",
        TabHome             = "الرئيسية",
        TabCombat           = "القتال",
        TabMovement         = "الحركة",
        TabTools            = "الأدوات",
        CreditsTitle        = "الاعتمادات",
        CreditsContent      = "تم إنشاؤه بواسطة Rival960 بمساعدة الذكاء الاصطناعي\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — تحديث القتال",
        ReleaseNotesTitle   = "v1.1.0 — ملاحظات الإصدار",
        ReleaseNotesContent = "جديد في v1.1.0: ذخيرة لا نهائية، تجميد الذخيرة، إصلاح اختراق الجدران للأيمبوت، نظام خطافات الذخيرة.\nوجدت خطأ أو تريد طلب ميزة؟ افتح issue على GitHub (Rival99900/Roblox-Scripts) أو انشر على ScriptBlox.",
        Aimbot              = "أيمبوت",
        AutoBring           = "جذب تلقائي",
        BringRadius         = "نطاق الجذب (وحدة)",
        BringInterval       = "فترة الجذب (ث)",
        MaxZombieDist       = "أقصى مسافة للزومبي",
        InfiniteAmmo        = "ذخيرة لا نهائية",
        FreezeAmmo          = "تجميد الذخيرة",
        FlyToggle           = "طيران",
        FlySpeed            = "سرعة الطيران",
        NoClip              = "اختراق الجدران",
        WalkSpeed           = "سرعة المشي",
        InfJump             = "قفز لانهائي",
        AntiAFK             = "مانع الخمول",
        Fullbright          = "سطوع كامل",
        LanguageSelect      = "اللغة",
        LangNote            = "تغيير اللغة يتطلب إعادة التشغيل",
    },
    VI = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "bởi Rival960",
        TabHome             = "Trang Chủ",
        TabCombat           = "Chiến Đấu",
        TabMovement         = "Di Chuyển",
        TabTools            = "Công Cụ",
        CreditsTitle        = "Tín Dụng",
        CreditsContent      = "Tạo bởi Rival960 với sự trợ giúp của AI\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Cập Nhật Chiến Đấu",
        ReleaseNotesTitle   = "v1.1.0 — Ghi Chú Phiên Bản",
        ReleaseNotesContent = "Mới trong v1.1.0: Đạn Vô Hạn, Đóng Băng Đạn, sửa lỗi xuyên tường Aimbot, hệ thống hook đạn.\nTìm thấy lỗi hoặc muốn yêu cầu tính năng? Mở issue trên GitHub (Rival99900/Roblox-Scripts) hoặc đăng trên ScriptBlox.",
        Aimbot              = "Aimbot",
        AutoBring           = "Tự Động Kéo",
        BringRadius         = "Bán Kính Kéo (studs)",
        BringInterval       = "Khoảng Thời Gian Kéo (s)",
        MaxZombieDist       = "Khoảng Cách Zombie Tối Đa",
        InfiniteAmmo        = "Đạn Vô Hạn",
        FreezeAmmo          = "Đóng Băng Đạn",
        FlyToggle           = "Bay",
        FlySpeed            = "Tốc Độ Bay",
        NoClip              = "NoClip",
        WalkSpeed           = "Tốc Độ Đi",
        InfJump             = "Nhảy Vô Hạn",
        AntiAFK             = "Chống AFK",
        Fullbright          = "Độ Sáng Tối Đa",
        LanguageSelect      = "Ngôn Ngữ",
        LangNote            = "Thay đổi ngôn ngữ cần khởi động lại",
    },
    SV = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "av Rival960",
        TabHome             = "Hem",
        TabCombat           = "Strid",
        TabMovement         = "Rörelse",
        TabTools            = "Verktyg",
        CreditsTitle        = "Erkännanden",
        CreditsContent      = "Skapad av Rival960 med hjälp av AI\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Stridsuppdatering",
        ReleaseNotesTitle   = "v1.1.0 — Versionsanteckningar",
        ReleaseNotesContent = "Nytt i v1.1.0: Oändlig Ammunition, Frys Ammunition, Aimbot väggenomträngningsfix, ammunition hook-system.\nHittade du en bugg eller vill begära en funktion? Öppna ett issue på GitHub (Rival99900/Roblox-Scripts) eller posta på ScriptBlox.",
        Aimbot              = "Aimbot",
        AutoBring           = "Auto Hämta",
        BringRadius         = "Hämtningsradie (studs)",
        BringInterval       = "Hämtningsintervall (s)",
        MaxZombieDist       = "Max Zombieavstånd",
        InfiniteAmmo        = "Oändlig Ammunition",
        FreezeAmmo          = "Frys Ammunition",
        FlyToggle           = "Flyg",
        FlySpeed            = "Flyghastighet",
        NoClip              = "NoClip",
        WalkSpeed           = "Gånghastighet",
        InfJump             = "Oändligt Hopp",
        AntiAFK             = "Anti-AFK",
        Fullbright          = "Full Ljusstyrka",
        LanguageSelect      = "Språk",
        LangNote            = "Språkändring kräver omstartning",
    },
    EL = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "από Rival960",
        TabHome             = "Αρχική",
        TabCombat           = "Μάχη",
        TabMovement         = "Κίνηση",
        TabTools            = "Εργαλεία",
        CreditsTitle        = "Εύσημα",
        CreditsContent      = "Δημιουργήθηκε από Rival960 με βοήθεια AI\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Ενημέρωση Μάχης",
        ReleaseNotesTitle   = "v1.1.0 — Σημειώσεις Έκδοσης",
        ReleaseNotesContent = "Νέο στο v1.1.0: Άπειρα Πυρομαχικά, Πάγωμα Πυρομαχικών, διόρθωση διαπέρασης τοίχων Aimbot, σύστημα hooks πυρομαχικών.\nΒρήκατε σφάλμα ή θέλετε να ζητήσετε λειτουργία; Ανοίξτε ένα issue στο GitHub (Rival99900/Roblox-Scripts) ή δημοσιεύστε στο ScriptBlox.",
        Aimbot              = "Aimbot",
        AutoBring           = "Αυτόματη Έλξη",
        BringRadius         = "Ακτίνα Έλξης (studs)",
        BringInterval       = "Διάστημα Έλξης (s)",
        MaxZombieDist       = "Μέγ. Απόσταση Ζόμπι",
        InfiniteAmmo        = "Άπειρα Πυρομαχικά",
        FreezeAmmo          = "Πάγωμα Πυρομαχικών",
        FlyToggle           = "Πτήση",
        FlySpeed            = "Ταχύτητα Πτήσης",
        NoClip              = "NoClip",
        WalkSpeed           = "Ταχύτητα Βαδίσματος",
        InfJump             = "Άπειρο Άλμα",
        AntiAFK             = "Anti-AFK",
        Fullbright          = "Πλήρης Φωτεινότητα",
        LanguageSelect      = "Γλώσσα",
        LangNote            = "Η αλλαγή γλώσσας απαιτεί επανεκτέλεση",
    },
    RO = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "de Rival960",
        TabHome             = "Acasă",
        TabCombat           = "Luptă",
        TabMovement         = "Mișcare",
        TabTools            = "Instrumente",
        CreditsTitle        = "Credite",
        CreditsContent      = "Creat de Rival960 cu ajutorul AI\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Actualizare Luptă",
        ReleaseNotesTitle   = "v1.1.0 — Note de Lansare",
        ReleaseNotesContent = "Nou în v1.1.0: Muniție Infinită, Îngheță Muniție, corectare penetrare pereți Aimbot, sistem de hooks muniție.\nAți găsit un bug sau doriți să solicitați o funcție? Deschideți un issue pe GitHub (Rival99900/Roblox-Scripts) sau postați pe ScriptBlox.",
        Aimbot              = "Aimbot",
        AutoBring           = "Auto Atragere",
        BringRadius         = "Raza de Atragere (studs)",
        BringInterval       = "Interval Atragere (s)",
        MaxZombieDist       = "Dist. Maximă Zombie",
        InfiniteAmmo        = "Muniție Infinită",
        FreezeAmmo          = "Îngheță Muniție",
        FlyToggle           = "Zbor",
        FlySpeed            = "Viteză Zbor",
        NoClip              = "NoClip",
        WalkSpeed           = "Viteză Mers",
        InfJump             = "Salt Infinit",
        AntiAFK             = "Anti-AFK",
        Fullbright          = "Luminozitate Maximă",
        LanguageSelect      = "Limbă",
        LangNote            = "Schimbarea limbii necesită re-executare",
    },
    UK = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "від Rival960",
        TabHome             = "Головна",
        TabCombat           = "Бій",
        TabMovement         = "Рух",
        TabTools            = "Інструменти",
        CreditsTitle        = "Автори",
        CreditsContent      = "Створено Rival960 за допомогою AI\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Бойове Оновлення",
        ReleaseNotesTitle   = "v1.1.0 — Примітки до версії",
        ReleaseNotesContent = "Нове у v1.1.0: Нескінченні патрони, Заморозити патрони, виправлення проникнення крізь стіни аімбота, система хуків патронів.\nЗнайшли баг або хочете запропонувати функцію? Створіть issue на GitHub (Rival99900/Roblox-Scripts) або напишіть на ScriptBlox.",
        Aimbot              = "Аімбот",
        AutoBring           = "Авто Притягання",
        BringRadius         = "Радіус притягання (ст.)",
        BringInterval       = "Інтервал притягання (с)",
        MaxZombieDist       = "Макс дистанція зомбі",
        InfiniteAmmo        = "Нескінченні патрони",
        FreezeAmmo          = "Заморозити патрони",
        FlyToggle           = "Політ",
        FlySpeed            = "Швидкість польоту",
        NoClip              = "NoClip",
        WalkSpeed           = "Швидкість ходьби",
        InfJump             = "Нескінченний Стрибок",
        AntiAFK             = "Анти-АФК",
        Fullbright          = "Повна яскравість",
        LanguageSelect      = "Мова",
        LangNote            = "Зміна мови потребує перезапуску",
    },
    CS = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "od Rival960",
        TabHome             = "Domů",
        TabCombat           = "Boj",
        TabMovement         = "Pohyb",
        TabTools            = "Nástroje",
        CreditsTitle        = "Poděkování",
        CreditsContent      = "Vytvořeno Rival960 s pomocí AI\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Bojová Aktualizace",
        ReleaseNotesTitle   = "v1.1.0 — Poznámky k Vydání",
        ReleaseNotesContent = "Nové ve v1.1.0: Nekonečná Munice, Zmrazit Munici, oprava průniku zdmi Aimbot, systém háčků munice.\nNašli jste chybu nebo chcete požádat o funkci? Otevřete issue na GitHub (Rival99900/Roblox-Scripts) nebo přidejte příspěvek na ScriptBlox.",
        Aimbot              = "Aimbot",
        AutoBring           = "Auto Přitáhnout",
        BringRadius         = "Poloměr přitáhnutí (studs)",
        BringInterval       = "Interval přitáhnutí (s)",
        MaxZombieDist       = "Max vzdálenost zombie",
        InfiniteAmmo        = "Nekonečná Munice",
        FreezeAmmo          = "Zmrazit Munici",
        FlyToggle           = "Létání",
        FlySpeed            = "Rychlost letu",
        NoClip              = "NoClip",
        WalkSpeed           = "Rychlost chůze",
        InfJump             = "Nekonečný Skok",
        AntiAFK             = "Anti-AFK",
        Fullbright          = "Plný jas",
        LanguageSelect      = "Jazyk",
        LangNote            = "Změna jazyka vyžaduje restartování",
    },
    DA = {
        WindowTitle         = "Tower of Zombies Hub",
        WindowSubtitle      = "af Rival960",
        TabHome             = "Hjem",
        TabCombat           = "Kamp",
        TabMovement         = "Bevægelse",
        TabTools            = "Værktøjer",
        CreditsTitle        = "Anerkendelser",
        CreditsContent      = "Oprettet af Rival960 med hjælp fra AI\nGitHub: Rival99900 | Discord: rival960 | YouTube: rival9607\nv1.1.0 — Kampsopdatering",
        ReleaseNotesTitle   = "v1.1.0 — Udgivelsesnoter",
        ReleaseNotesContent = "Nyt i v1.1.0: Uendelig Ammunition, Frys Ammunition, Aimbot væggennemtrængningsfix, ammunition hook-system.\nFandt du en fejl eller vil du anmode om en funktion? Åbn et issue på GitHub (Rival99900/Roblox-Scripts) eller post på ScriptBlox.",
        Aimbot              = "Aimbot",
        AutoBring           = "Auto Hent",
        BringRadius         = "Hentningsradius (studs)",
        BringInterval       = "Hentningsinterval (s)",
        MaxZombieDist       = "Maks Zombie Afstand",
        InfiniteAmmo        = "Uendelig Ammunition",
        FreezeAmmo          = "Frys Ammunition",
        FlyToggle           = "Fly",
        FlySpeed            = "Flyvehastighed",
        NoClip              = "NoClip",
        WalkSpeed           = "Gåhastighed",
        InfJump             = "Uendeligt Hop",
        AntiAFK             = "Anti-AFK",
        Fullbright          = "Fuld Lysstyrke",
        LanguageSelect      = "Sprog",
        LangNote            = "Sprogændring kræver genstart",
    },
}

local function T(key)
    local t = Translations[CurrentLang]
    if t and t[key] then return t[key] end
    return Translations["EN"][key] or key
end

-- ================================================================
-- Settings
-- ================================================================
local Settings = {
    Aimbot        = false,
    AutoBring     = false,
    BringRadius   = 3,
    BringInterval = 0.3,
    MaxZombieDist = 300,
    InfiniteAmmo  = false,
    FreezeAmmo    = false,
    Fly           = false,
    FlySpeed      = 60,
    NoClip        = false,
    WalkSpeed     = 16,
    InfJump       = false,
    AntiAFK       = false,
    Fullbright    = false,
}

-- Ammo state
local _frozenClip    = nil   -- cached clip value at FreezeAmmo toggle-ON time
local _frozenReserve = nil   -- cached reserve value at FreezeAmmo toggle-ON time
local CLIP_THRESHOLD = 99    -- write when value drops below this (weapon ClipSize)

-- Fire rate limiting
local lastFireTime  = 0
local FIRE_COOLDOWN = 0.08   -- 0.08s safe below the 0.18s minimum FinalFireRate

-- Aimbot lockout detection
local lastDamageTime = tick()  -- updated on every successful fireAtTarget call

-- ================================================================
-- Character helpers
-- ================================================================
local function getChar() return LocalPlayer.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ================================================================
-- Ammo helpers
-- ================================================================

-- Immediately write ammo values to the equipped tool's Info children
local function applyAmmoNow(clipVal, reserveVal)
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then return end
        local info = tool:FindFirstChild("Info")
        if not info then return end
        local clip    = info:FindFirstChild("Clip")
        local reserve = info:FindFirstChild("Reserve")
        if clip    then clip.Value    = clipVal    end
        if reserve then reserve.Value = reserveVal end
    end)
end

-- ================================================================
-- forceHandlerAmmo — directly patch the Handler's internal upvalue
-- The Handler stores clip count internally (upvalue ~[40] in FireGun closure).
-- When this internal counter hits 0 it calls BeginReload, blocking all shots.
-- Writing Info.Clip.Value alone does NOT update that counter.
-- ================================================================
local function forceHandlerAmmo(tool, targetValue)
    if not tool then return end
    local handler = tool:FindFirstChildOfClass("LocalScript")
               or  tool:FindFirstChild("Handler")
    if not handler then return end
    pcall(function()
        local info    = tool:FindFirstChild("Info")
        local clipObj = info and info:FindFirstChild("Clip")
        if not clipObj then return end
        local currentClip = clipObj.Value
        if debug and debug.getupvalue and debug.setupvalue then
            for i = 1, 80 do
                pcall(function()
                    local _, val = debug.getupvalue(handler, i)
                    if type(val) == "number"
                    and val >= 0
                    and val <= 10000
                    and math.floor(val) == math.floor(currentClip) then
                        debug.setupvalue(handler, i, targetValue)
                    end
                end)
            end
        end
    end)
end

-- ================================================================
-- softReequip — reset Handler state by moving tool through backpack
-- Called automatically when aimbot lockout (>3s without a successful shot) is detected.
-- After re-equip, immediately re-applies the active ammo mode.
-- ================================================================
local function softReequip()
    pcall(function()
        local char    = LocalPlayer.Character
        if not char then return end
        local tool    = char:FindFirstChildOfClass("Tool")
        if not tool then return end
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if not backpack then return end
        tool.Parent = backpack
        task.wait(0.1)
        tool.Parent = char
        -- Re-apply ammo immediately after re-equip
        task.wait(0.05)
        if Settings.InfiniteAmmo then
            applyAmmoNow(99999, 99999)
        elseif Settings.FreezeAmmo and _frozenClip then
            applyAmmoNow(_frozenClip, _frozenReserve or 99999)
        end
    end)
end

-- ================================================================
-- Rayfield load (keyless)
-- ================================================================
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not success or not Rayfield then return end

local Window = Rayfield:CreateWindow({
    Name             = T("WindowTitle"),
    LoadingTitle     = T("WindowTitle"),
    LoadingSubtitle  = T("WindowSubtitle"),
    ConfigurationSaving = { Enabled = false },
    Discord          = { Enabled = false },
    KeySystem        = false,
})

-- ================================================================
-- Shared combat helpers
-- ================================================================

local function getClosestZombieTarget(maxDist)
    local hrp = getHRP()
    if not hrp then return nil end
    local bestPart, bestDist = nil, maxDist
    local zombieFolder = workspace:FindFirstChild("ActiveZombies")
    if not zombieFolder then return nil end
    for _, zombie in ipairs(zombieFolder:GetChildren()) do
        local hum = zombie:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            local zhrp = zombie:FindFirstChild("HumanoidRootPart")
            if zhrp then
                local dist = (zhrp.Position - hrp.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestPart = zombie:FindFirstChild("HeadHitbox")
                           or zombie:FindFirstChild("Head")
                           or zhrp
                end
            end
        end
    end
    return bestPart
end

-- Fire both remotes with epsilon rayOrigin + 0.08s rate limiter.
-- Returns true when at least one fire call succeeded (used for lockout tracking).
local function fireAtTarget(targetPart)
    local now = tick()
    if (now - lastFireTime) < FIRE_COOLDOWN then return false end
    lastFireTime = now

    local char = LocalPlayer.Character
    if not char then return false end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return false end
    local weaponName = tool.Name
    local exitPart   = tool:FindFirstChild("Exit")
    if not exitPart then return false end

    -- Ensure ammo is non-zero before firing
    pcall(function()
        local info = tool:FindFirstChild("Info")
        if info then
            local clip    = info:FindFirstChild("Clip")
            local reserve = info:FindFirstChild("Reserve")
            if clip    and clip.Value    < 1 then clip.Value    = 99999 end
            if reserve and reserve.Value < 1 then reserve.Value = 99999 end
        end
    end)

    local hitPos    = targetPart.Position
    local rayOrigin = hitPos + Vector3.new(0, 0.01, 0)
    local normalVec = Vector3.new(0, 1, 0)

    -- Clear weapon debounce state before firing
    pcall(function()
        tool:SetAttribute("Firing", false)
        tool:SetAttribute("ContinuousFireActive", false)
    end)

    local fired = false
    pcall(function()
        ReplicatedStorage.Events.Actions.Fire:FireServer(
            weaponName,
            {{ targetPart, hitPos, normalVec }},
            {{ weaponName, rayOrigin, hitPos, hitPos, true, targetPart, false, false, "Default", exitPart }}
        )
        fired = true
    end)
    pcall(function()
        ReplicatedStorage.Events.Actions.Fire_2:FireServer(
            weaponName,
            {{ targetPart, hitPos, normalVec }},
            {{ weaponName, rayOrigin, hitPos, hitPos, true, targetPart, false, false, "Default", exitPart }}
        )
        fired = true
    end)

    if fired then
        lastDamageTime = tick()
    end
    return fired
end

-- ================================================================
-- TABS
-- ================================================================

local HomeTab = Window:CreateTab(T("TabHome"), 4483362458)
HomeTab:CreateParagraph({
    Title   = T("CreditsTitle"),
    Content = T("CreditsContent"),
})
HomeTab:CreateParagraph({
    Title   = T("ReleaseNotesTitle"),
    Content = T("ReleaseNotesContent"),
})

local CombatTab = Window:CreateTab(T("TabCombat"), 4483362458)

CombatTab:CreateToggle({
    Name         = T("Aimbot"),
    CurrentValue = false,
    Callback     = function(val)
        Settings.Aimbot = val
        if val then
            lastDamageTime = tick()  -- reset lockout timer on enable
        end
    end,
})

CombatTab:CreateSlider({
    Name         = T("MaxZombieDist"),
    Range        = {50, 500},
    Increment    = 10,
    CurrentValue = 300,
    Callback     = function(val) Settings.MaxZombieDist = val end,
})

CombatTab:CreateToggle({
    Name         = T("AutoBring"),
    CurrentValue = false,
    Callback     = function(val)
        Settings.AutoBring = val
        if not val then
            pcall(function()
                local zombieFolder = workspace:FindFirstChild("ActiveZombies")
                if not zombieFolder then return end
                for _, zombie in ipairs(zombieFolder:GetChildren()) do
                    local hum = zombie:FindFirstChildOfClass("Humanoid")
                    if hum then hum.WalkSpeed = 16 end
                end
            end)
        end
    end,
})

CombatTab:CreateSlider({
    Name         = T("BringRadius"),
    Range        = {1, 10},
    Increment    = 1,
    CurrentValue = 3,
    Callback     = function(val) Settings.BringRadius = val end,
})

CombatTab:CreateSlider({
    Name         = T("BringInterval"),
    Range        = {0.1, 2.0},
    Increment    = 0.1,
    CurrentValue = 0.3,
    Callback     = function(val) Settings.BringInterval = val end,
})

CombatTab:CreateToggle({
    Name         = T("InfiniteAmmo"),
    CurrentValue = false,
    Callback     = function(val)
        Settings.InfiniteAmmo = val
        if val then
            Settings.FreezeAmmo = false
            _frozenClip    = nil
            _frozenReserve = nil
            -- Apply immediately, before the next loop tick
            applyAmmoNow(99999, 99999)
        end
    end,
})

CombatTab:CreateToggle({
    Name         = T("FreezeAmmo"),
    CurrentValue = false,
    Callback     = function(val)
        Settings.FreezeAmmo = val
        if val then
            Settings.InfiniteAmmo = false
            -- Cache current values immediately at toggle-ON time
            pcall(function()
                local char = LocalPlayer.Character
                local tool = char and char:FindFirstChildOfClass("Tool")
                if tool then
                    local info = tool:FindFirstChild("Info")
                    if info then
                        local clip    = info:FindFirstChild("Clip")
                        local reserve = info:FindFirstChild("Reserve")
                        -- If clip is already 0, freeze at ClipSize (12) instead
                        local cv = clip    and clip.Value    or 12
                        local rv = reserve and reserve.Value or 99999
                        _frozenClip    = (cv > 0) and cv or 12
                        _frozenReserve = (rv > 0) and rv or 99999
                    end
                end
            end)
            -- Apply immediately
            if _frozenClip then
                applyAmmoNow(_frozenClip, _frozenReserve or 99999)
            end
        else
            _frozenClip    = nil
            _frozenReserve = nil
        end
    end,
})

-- ───── Tab 3: Movement ─────
local MovementTab = Window:CreateTab(T("TabMovement"), 4483362458)

-- ================================================================
-- Fly system (confirmed working — do not touch)
-- ================================================================
local FLYING       = false
local FLY_BTN_UP   = 0
local FLY_BTN_DOWN = 0
local flyKeyDown, flyKeyUp
local _flyUpBtn, _flyDownBtn

local function enableFly()
    local char = getChar()
    local hrp  = getHRP()
    local hum  = getHum()
    if not char or not hrp or not hum then return end

    if flyKeyDown then flyKeyDown:Disconnect() end
    if flyKeyUp   then flyKeyUp:Disconnect()   end

    FLYING = true

    local CTRL = {F=0, B=0, L=0, R=0, UP=0, DOWN=0}

    local bv = Instance.new("BodyVelocity")
    bv.Name      = "_SWAT_FLY_BV"
    bv.MaxForce  = Vector3.new(9e9, 9e9, 9e9)
    bv.Velocity  = Vector3.zero
    bv.Parent    = hrp

    local bg = Instance.new("BodyGyro")
    bg.Name      = "_SWAT_FLY_BG"
    bg.P         = 9e4
    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.CFrame    = hrp.CFrame
    bg.Parent    = hrp

    hum.PlatformStand = true

    flyKeyDown = UserInputService.InputBegan:Connect(function(inp, proc)
        if proc then return end
        local k = inp.KeyCode
        if     k == Enum.KeyCode.W          then CTRL.F    =  1
        elseif k == Enum.KeyCode.S          then CTRL.B    = -1
        elseif k == Enum.KeyCode.A          then CTRL.L    = -1
        elseif k == Enum.KeyCode.D          then CTRL.R    =  1
        elseif k == Enum.KeyCode.Space      then CTRL.UP   =  1
        elseif k == Enum.KeyCode.LeftShift
            or k == Enum.KeyCode.RightShift then CTRL.DOWN = -1
        end
    end)

    flyKeyUp = UserInputService.InputEnded:Connect(function(inp, proc)
        if proc then return end
        local k = inp.KeyCode
        if     k == Enum.KeyCode.W          then CTRL.F    = 0
        elseif k == Enum.KeyCode.S          then CTRL.B    = 0
        elseif k == Enum.KeyCode.A          then CTRL.L    = 0
        elseif k == Enum.KeyCode.D          then CTRL.R    = 0
        elseif k == Enum.KeyCode.Space      then CTRL.UP   = 0
        elseif k == Enum.KeyCode.LeftShift
            or k == Enum.KeyCode.RightShift then CTRL.DOWN = 0
        end
    end)

    if _flyUpBtn   then _flyUpBtn.Visible   = true end
    if _flyDownBtn then _flyDownBtn.Visible = true end

    task.spawn(function()
        while FLYING do
            task.wait()
            local camCF    = workspace.CurrentCamera.CFrame
            local rawLook  = camCF.LookVector
            local rawRight = camCF.RightVector
            local spd      = Settings.FlySpeed

            local flatLook  = Vector3.new(rawLook.X,  0, rawLook.Z)
            local flatRight = Vector3.new(rawRight.X, 0, rawRight.Z)
            if flatLook.Magnitude  > 0 then flatLook  = flatLook.Unit  end
            if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end

            local pcVel = flatLook  * CTRL.F
                        + flatLook  * CTRL.B
                        + flatRight * CTRL.R
                        + flatRight * CTRL.L

            local md        = hum.MoveDirection
            local mobileVel = Vector3.new(md.X, 0, md.Z)

            local horizVel
            if md.Magnitude > 0.1 then
                horizVel = mobileVel * spd
            else
                horizVel = pcVel * spd
            end

            local vertVel = Vector3.new(0, (CTRL.UP + CTRL.DOWN + FLY_BTN_UP + FLY_BTN_DOWN) * spd, 0)
            bv.Velocity = horizVel + vertVel
            bg.CFrame   = camCF
        end
    end)
end

local function disableFly()
    FLYING = false
    FLY_BTN_UP   = 0
    FLY_BTN_DOWN = 0
    if flyKeyDown then flyKeyDown:Disconnect(); flyKeyDown = nil end
    if flyKeyUp   then flyKeyUp:Disconnect();   flyKeyUp   = nil end
    local hrp = getHRP()
    if hrp then
        local b = hrp:FindFirstChild("_SWAT_FLY_BV"); if b then b:Destroy() end
        local g = hrp:FindFirstChild("_SWAT_FLY_BG"); if g then g:Destroy() end
    end
    local h = getHum()
    if h then h.PlatformStand = false end
    if _flyUpBtn   then _flyUpBtn.Visible   = false end
    if _flyDownBtn then _flyDownBtn.Visible = false end
end

-- Mobile ▲▼ buttons
if UserInputService.TouchEnabled then
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local flyGui = Instance.new("ScreenGui")
        flyGui.Name           = "TozFlyOverlay"
        flyGui.ResetOnSpawn   = false
        flyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        flyGui.Parent         = playerGui

        local BTN = 60
        local GAP = 8

        local function makeBtn(text, xOffset)
            local btn = Instance.new("TextButton")
            btn.Size                   = UDim2.new(0, BTN, 0, BTN)
            btn.Position               = UDim2.new(0.5, xOffset, 1, -(BTN + 20))
            btn.AnchorPoint            = Vector2.new(0, 0)
            btn.BackgroundColor3       = Color3.fromRGB(40, 40, 40)
            btn.BackgroundTransparency = 0.3
            btn.TextColor3             = Color3.new(1, 1, 1)
            btn.Text                   = text
            btn.TextScaled             = true
            btn.Font                   = Enum.Font.GothamBold
            btn.Visible                = false
            btn.Parent                 = flyGui
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 10)
            corner.Parent       = btn
            return btn
        end

        _flyUpBtn   = makeBtn("▲", -(BTN + GAP / 2))
        _flyDownBtn = makeBtn("▼",   GAP / 2)

        _flyUpBtn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch then FLY_BTN_UP = 1 end
        end)
        _flyUpBtn.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch then FLY_BTN_UP = 0 end
        end)
        _flyDownBtn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch then FLY_BTN_DOWN = -1 end
        end)
        _flyDownBtn.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch then FLY_BTN_DOWN = 0 end
        end)
    end
end

MovementTab:CreateToggle({
    Name         = T("FlyToggle"),
    CurrentValue = false,
    Callback     = function(val)
        Settings.Fly = val
        if val then enableFly() else disableFly() end
    end,
})

MovementTab:CreateSlider({
    Name         = T("FlySpeed"),
    Range        = {10, 300},
    Increment    = 5,
    CurrentValue = 60,
    Callback     = function(val) Settings.FlySpeed = val end,
})

local noClipConn
MovementTab:CreateToggle({
    Name         = T("NoClip"),
    CurrentValue = false,
    Callback     = function(val)
        Settings.NoClip = val
        if val then
            if not noClipConn then
                noClipConn = RunService.Stepped:Connect(function()
                    if not Settings.NoClip then
                        noClipConn:Disconnect()
                        noClipConn = nil
                        return
                    end
                    pcall(function()
                        local char = getChar()
                        if not char then return end
                        for _, p in ipairs(char:GetDescendants()) do
                            if p:IsA("BasePart") then p.CanCollide = false end
                        end
                    end)
                end)
            end
        else
            if noClipConn then noClipConn:Disconnect() noClipConn = nil end
        end
    end,
})

MovementTab:CreateSlider({
    Name         = T("WalkSpeed"),
    Range        = {16, 250},
    Increment    = 1,
    CurrentValue = 16,
    Callback     = function(val)
        Settings.WalkSpeed = val
        pcall(function()
            local hum = getHum()
            if hum then hum.WalkSpeed = val end
        end)
    end,
})

MovementTab:CreateToggle({
    Name         = T("InfJump"),
    CurrentValue = false,
    Callback     = function(val) Settings.InfJump = val end,
})

local ToolsTab = Window:CreateTab(T("TabTools"), 4483362458)

ToolsTab:CreateToggle({
    Name         = T("Fullbright"),
    CurrentValue = false,
    Callback     = function(val)
        Settings.Fullbright = val
        pcall(function()
            local lighting = game:GetService("Lighting")
            if val then
                lighting.Brightness    = 10
                lighting.GlobalShadows = false
                lighting.ClockTime     = 14
            else
                lighting.Brightness    = 1
                lighting.GlobalShadows = true
                lighting.ClockTime     = 14
            end
        end)
    end,
})

local afkThread
ToolsTab:CreateToggle({
    Name         = T("AntiAFK"),
    CurrentValue = false,
    Callback     = function(val)
        Settings.AntiAFK = val
        if val then
            if not afkThread then
                afkThread = task.spawn(function()
                    while Settings.AntiAFK do
                        pcall(function()
                            local hrp = getHRP()
                            if hrp then
                                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(0.01), 0)
                            end
                        end)
                        task.wait(60)
                    end
                    afkThread = nil
                end)
            end
        end
    end,
})

ToolsTab:CreateDropdown({
    Name          = T("LanguageSelect"),
    Options       = {"EN","FR","DE","ES","PT","RU","IT","NL","PL","ZH","JA","TR","KO","AR","VI","SV","EL","RO","UK","CS","DA"},
    CurrentOption = {"EN"},
    Callback      = function(opt)
        CurrentLang = type(opt) == "table" and opt[1] or opt
    end,
})

ToolsTab:CreateLabel(T("LangNote"))

-- ================================================================
-- Ammo maintenance loop — 0.05s interval
-- Threshold-based: only writes when value < CLIP_THRESHOLD (99).
-- InfiniteAmmo takes priority over FreezeAmmo when both are ON.
-- After writing Info values, also patches Handler's internal upvalue.
-- ================================================================
task.spawn(function()
    while true do
        task.wait(0.05)
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local tool = char:FindFirstChildOfClass("Tool")
            if not tool then return end
            local info = tool:FindFirstChild("Info")
            if not info then return end
            local clip    = info:FindFirstChild("Clip")
            local reserve = info:FindFirstChild("Reserve")

            if Settings.InfiniteAmmo then
                local wrote = false
                if clip    and clip.Value    < CLIP_THRESHOLD then clip.Value    = 99999; wrote = true end
                if reserve and reserve.Value < CLIP_THRESHOLD then reserve.Value = 99999; wrote = true end
                if wrote then forceHandlerAmmo(tool, 99999) end

            elseif Settings.FreezeAmmo and _frozenClip then
                local cv = _frozenClip
                local rv = _frozenReserve or 99999
                local wrote = false
                if clip    and clip.Value    ~= cv then clip.Value    = cv; wrote = true end
                if reserve and reserve.Value ~= rv then reserve.Value = rv; wrote = true end
                if wrote and cv > 0 then forceHandlerAmmo(tool, cv) end
            end
        end)
    end
end)

-- ================================================================
-- Lockout watchdog — checks every 0.5s whether aimbot has gone
-- 3s without a successful shot, and triggers a soft re-equip if so.
-- ================================================================
task.spawn(function()
    while true do
        task.wait(0.5)
        if Settings.Aimbot and (tick() - lastDamageTime) > 3 then
            -- Only attempt re-equip if we actually have a target (not just idle)
            local target = getClosestZombieTarget(Settings.MaxZombieDist)
            if target then
                softReequip()
                lastDamageTime = tick()  -- reset after re-equip attempt
            end
        end
    end
end)

-- ================================================================
-- Main Loops
-- ================================================================

local aimbotConn
local function connectAimbot()
    if aimbotConn then aimbotConn:Disconnect() end
    aimbotConn = RunService.RenderStepped:Connect(function()
        if not Settings.Aimbot then return end
        pcall(function()
            local cam        = workspace.CurrentCamera
            local targetPart = getClosestZombieTarget(Settings.MaxZombieDist)
            if targetPart then
                cam.CFrame = CFrame.lookAt(cam.CFrame.Position, targetPart.Position)
            end
        end)
    end)
end
connectAimbot()
LocalPlayer.CharacterAdded:Connect(function()
    connectAimbot()
    lastDamageTime = tick()
end)

UserInputService.JumpRequest:Connect(function()
    if not Settings.InfJump then return end
    pcall(function()
        local hum = getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end)

-- Auto Bring: teleport zombies into a circle, fire at each if Aimbot also ON.
-- Never calls tool:Activate() — only CFrame manipulation + fireAtTarget.
local bringTimer = 0
RunService.Heartbeat:Connect(function(dt)
    if not Settings.AutoBring then
        bringTimer = 0
        return
    end
    bringTimer = bringTimer + dt
    if bringTimer < Settings.BringInterval then return end
    bringTimer = 0
    task.spawn(function()
        pcall(function()
            local hrp = getHRP()
            if not hrp then return end
            local zombieFolder = workspace:FindFirstChild("ActiveZombies")
            if not zombieFolder then return end

            local zombies = zombieFolder:GetChildren()
            local total   = #zombies
            if total == 0 then return end

            for i, zombie in ipairs(zombies) do
                local hum = zombie:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local zhrp = zombie:FindFirstChild("HumanoidRootPart")
                    if zhrp then
                        local angle  = ((i - 1) / total) * (2 * math.pi)
                        local offset = Vector3.new(
                            math.cos(angle), 0, math.sin(angle)
                        ) * Settings.BringRadius
                        pcall(function()
                            zhrp.CFrame   = CFrame.new(hrp.Position + offset)
                            hum.WalkSpeed = 0
                        end)
                        if Settings.Aimbot then
                            local target = zombie:FindFirstChild("HeadHitbox")
                                        or zombie:FindFirstChild("Head")
                                        or zhrp
                            task.spawn(function() fireAtTarget(target) end)
                        end
                        task.wait(0.01)
                    end
                end
            end
        end)
    end)
end)

pcall(function()
    ReplicatedStorage.Events.Communication.LavaRising.OnClientEvent:Connect(function()
        Rayfield:Notify({
            Title    = "⚠️ Lava Rising!",
            Content  = "Lava is rising — climb fast!",
            Duration = 4,
            Image    = 4483362458,
        })
    end)
end)
