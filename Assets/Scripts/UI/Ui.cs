using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.TextCore.Text;
using UnityEngine.UIElements;

namespace CS
{
    /// 화면 UI 전부(UI Toolkit, 코드로만 구성): HUD · 레벨업 카드 · 메뉴 · 결과.
    public class Ui : MonoBehaviour
    {
        public static Ui I;
        VisualElement root, hud, modal;
        FontAsset font, bold;
        // HUD
        VisualElement hpFill, xpFill, ultFill, bossBox, bossFill, iconRowW, iconRowP, dashRow, giftBox;
        Label hpText, clock, sub, lvl, killsL, bossName, toastL, ultText, giftL;
        readonly List<Label> numPool = new List<Label>(); readonly int[] numVal = new int[128]; readonly DmgNum[] numRef = new DmgNum[128]; float hudT;
        string iconKey = "";
        // 메뉴 / 카드
        readonly List<VisualElement> rows = new List<VisualElement>(); readonly List<Action> acts = new List<Action>(); readonly List<Action<int>> adjs = new List<Action<int>>();
        int sel; Action onBack; public bool ModalOpen => modal.childCount > 0;
        int openedFrame; float lockUntil;
        List<LevelOption> lvOpts;

        static readonly Color Panel = new Color(0.03f, 0.05f, 0.09f, 0.93f), Line = new Color(0.36f, 0.72f, 1f, 0.55f), Dim = new Color(0.62f, 0.68f, 0.8f);

        public void Init()
        {
            I = this;
            var doc = gameObject.AddComponent<UIDocument>();
            var ps = ScriptableObject.CreateInstance<PanelSettings>();
            ps.themeStyleSheet = Resources.Load<ThemeStyleSheet>("UI/Theme");
            ps.scaleMode = PanelScaleMode.ScaleWithScreenSize; ps.referenceResolution = new Vector2Int(1600, 900);
            ps.screenMatchMode = PanelScreenMatchMode.MatchWidthOrHeight; ps.match = 1f; ps.sortingOrder = 10;
            doc.panelSettings = ps;
            root = doc.rootVisualElement;
            font = FontAsset.CreateFontAsset(Resources.Load<Font>("Fonts/Pretendard-Regular"));
            bold = FontAsset.CreateFontAsset(Resources.Load<Font>("Fonts/Pretendard-Bold"));
            root.style.unityFontDefinition = new StyleFontDefinition(font);
            root.style.flexGrow = 1; root.pickingMode = PickingMode.Ignore;
            hud = Fill(root); modal = Fill(root);
            BuildHud();
        }

        // ── 만들기 도우미 ──
        VisualElement Fill(VisualElement parent) { var e = new VisualElement(); e.style.position = Position.Absolute; e.style.left = 0; e.style.right = 0; e.style.top = 0; e.style.bottom = 0; e.pickingMode = PickingMode.Ignore; parent.Add(e); return e; }
        VisualElement Box(VisualElement parent, Color bg, Color border, float bw = 1.5f, float radius = 6f)
        {
            var e = new VisualElement(); e.style.backgroundColor = bg; e.pickingMode = PickingMode.Ignore;
            e.style.borderLeftColor = e.style.borderRightColor = e.style.borderTopColor = e.style.borderBottomColor = border;
            e.style.borderLeftWidth = e.style.borderRightWidth = e.style.borderTopWidth = e.style.borderBottomWidth = bw;
            e.style.borderTopLeftRadius = e.style.borderTopRightRadius = e.style.borderBottomLeftRadius = e.style.borderBottomRightRadius = radius;
            parent.Add(e); return e;
        }
        Label T(VisualElement parent, string s, float size, Color c, bool isBold = false, TextAnchor align = TextAnchor.MiddleLeft)
        {
            var l = new Label(Loc.Tr(s)); l.style.fontSize = size; l.style.color = c; l.style.unityTextAlign = align; l.pickingMode = PickingMode.Ignore;
            l.style.marginLeft = l.style.marginRight = l.style.marginTop = l.style.marginBottom = 0; l.style.paddingLeft = l.style.paddingRight = l.style.paddingTop = l.style.paddingBottom = 0;
            if (isBold) l.style.unityFontDefinition = new StyleFontDefinition(bold);
            l.style.textShadow = new TextShadow { offset = new Vector2(0, 1), blurRadius = 3, color = new Color(0, 0, 0, 0.8f) };
            parent.Add(l); return l;
        }
        static void Abs(VisualElement e, float? l, float? t, float? r, float? b, float? w = null, float? h = null)
        {
            e.style.position = Position.Absolute;
            if (l.HasValue) e.style.left = l.Value; if (t.HasValue) e.style.top = t.Value; if (r.HasValue) e.style.right = r.Value; if (b.HasValue) e.style.bottom = b.Value;
            if (w.HasValue) e.style.width = w.Value; if (h.HasValue) e.style.height = h.Value;
        }
        VisualElement Bar(VisualElement parent, Color c, out VisualElement fill)
        {
            var bg = Box(parent, new Color(0.03f, 0.04f, 0.07f, 0.85f), new Color(1, 1, 1, 0.22f), 1f, 3f);
            fill = new VisualElement(); fill.style.backgroundColor = c; fill.style.height = Length.Percent(100); fill.style.width = Length.Percent(100); bg.Add(fill);
            return bg;
        }

        // ── HUD ──
        void BuildHud()
        {
            var xp = Bar(hud, DB.Green, out xpFill); Abs(xp, 0, 0, 0, null, null, 10); xp.style.borderLeftWidth = xp.style.borderRightWidth = xp.style.borderTopWidth = 0;
            var hpb = Bar(hud, DB.Cyan, out hpFill); Abs(hpb, 24, 30, null, null, 280, 16);
            hpText = T(hud, "", 17, DB.White, true); Abs(hpText, 24, 50, null, null);
            iconRowW = new VisualElement(); iconRowW.style.flexDirection = FlexDirection.Row; Abs(iconRowW, 24, 80, null, null); hud.Add(iconRowW);
            iconRowP = new VisualElement(); iconRowP.style.flexDirection = FlexDirection.Row; Abs(iconRowP, 24, 142, null, null); hud.Add(iconRowP);
            clock = T(hud, "", 34, DB.White, true, TextAnchor.MiddleCenter); Abs(clock, 0, 20, 0, null);
            sub = T(hud, "", 16, Dim, false, TextAnchor.MiddleCenter); Abs(sub, 0, 62, 0, null);
            lvl = T(hud, "", 22, DB.Green, true, TextAnchor.MiddleRight); Abs(lvl, null, 22, 24, null, 300);
            killsL = T(hud, "", 19, DB.White, true, TextAnchor.MiddleRight); Abs(killsL, null, 52, 24, null, 300);
            bossBox = new VisualElement(); Abs(bossBox, 0, 96, 0, null); bossBox.style.alignItems = Align.Center; hud.Add(bossBox);
            var bb = Bar(bossBox, DB.Red, out bossFill); bb.style.width = 700; bb.style.height = 13;
            bossName = T(bossBox, "", 17, DB.Red, true, TextAnchor.MiddleCenter);
            toastL = T(hud, "", 24, DB.White, true, TextAnchor.MiddleCenter); Abs(toastL, 0, 250, 0, null);
            // 아래 가운데: 대시 충전 + 궁극기
            var bottom = new VisualElement(); Abs(bottom, 0, null, 0, 26); bottom.style.alignItems = Align.Center; hud.Add(bottom);
            dashRow = new VisualElement(); dashRow.style.flexDirection = FlexDirection.Row; dashRow.style.marginBottom = 6; bottom.Add(dashRow);
            for (int i = 0; i < World.MaxDash; i++) { var d = Box(dashRow, DB.Cyan, new Color(1, 1, 1, 0.4f), 1f, 3f); d.style.width = 46; d.style.height = 8; d.style.marginLeft = d.style.marginRight = 3; }
            var ub = Bar(bottom, DB.Yellow, out ultFill); ub.style.width = 300; ub.style.height = 12;
            ultText = T(bottom, "", 15, Dim, false, TextAnchor.MiddleCenter); ultText.style.marginTop = 4;
            giftBox = Box(hud, new Color(0.02f, 0.06f, 0.04f, 0.9f), DB.Green); Abs(giftBox, null, null, null, 170, 560); giftBox.style.alignSelf = Align.Center; giftBox.style.left = Length.Percent(50); giftBox.style.translate = new Translate(Length.Percent(-50), 0);
            giftBox.style.paddingLeft = giftBox.style.paddingRight = 18; giftBox.style.paddingTop = giftBox.style.paddingBottom = 12;
            giftL = T(giftBox, "", 17, DB.Green); giftL.style.whiteSpace = WhiteSpace.Normal;
            for (int i = 0; i < 70; i++) { var n = T(hud, "", 17, DB.White, true, TextAnchor.MiddleCenter); Abs(n, 0, 0, null, null, 60, 20); n.style.display = DisplayStyle.None; n.usageHints = UsageHints.DynamicTransform; numPool.Add(n); }
        }

        VisualElement Tile(VisualElement parent, string id, Color c, int lv, int max, float size, bool evolved)
        {
            var t = Box(parent, new Color(0.04f, 0.06f, 0.1f, 0.85f), evolved ? DB.Yellow : new Color(c.r, c.g, c.b, 0.85f), evolved ? 2.5f : 1.5f, 5f);
            t.style.width = size; t.style.height = size; t.style.marginRight = 7; t.style.alignItems = Align.Center; t.style.justifyContent = Justify.Center;
            var ic = new Icon(id, c, size * 0.62f); ic.style.marginBottom = max > 0 ? 6 : 0; t.Add(ic);
            if (max > 0)
            {
                var pips = new VisualElement(); pips.style.flexDirection = FlexDirection.Row; Abs(pips, 3, null, 3, 3, null, 3); t.Add(pips);
                for (int i = 0; i < max; i++) { var p = new VisualElement(); p.style.flexGrow = 1; p.style.marginLeft = p.style.marginRight = 0.6f; p.style.backgroundColor = i < lv ? c : new Color(0.25f, 0.28f, 0.35f); pips.Add(p); }
            }
            return t;
        }

        public void Tick(World w, bool showHud)
        {
            hud.style.display = showHud ? DisplayStyle.Flex : DisplayStyle.None;
            if (showHud) UpdateHud(w);
            if (ModalOpen) MenuInput();
        }

        void UpdateHud(World w)
        {
            xpFill.style.width = Length.Percent(Mathf.Clamp01((float)w.xp / w.xpNext) * 100f);
            float hf = Mathf.Clamp01(w.hp / w.maxHp);
            hpFill.style.width = Length.Percent(hf * 100f); hpFill.style.backgroundColor = hf > 0.35f ? w.ch.color : DB.Red;
            hudT -= Time.unscaledDeltaTime; bool slow = hudT <= 0f; if (slow) hudT = 0.1f;      // 글자는 초당 10번만 새로 만든다
            if (slow && Dev.Has("nohudtext")) slow = false;
            if (slow) HudTextFrame = Time.frameCount;
            if (slow) { hpText.text = w.ch.name + "   HP " + Mathf.CeilToInt(Mathf.Max(0, w.hp)) + " / " + (int)w.maxHp;
            clock.text = DB.Clock(w.t); }
            float left = Mathf.Max(0f, w.zone.length - w.t);
            if (slow) sub.text = Loc.Tr(w.boss != null ? "구역 보스를 쓰러뜨려라" : w.zone.name + (w.diffIdx == 1 ? "" : (w.diffIdx == 0 ? " (쉬움)" : " (어려움)")) + "  ·  보스까지 " + (int)left / 60 + ":" + ((int)left % 60).ToString("00"));
            sub.style.color = w.boss != null ? DB.Yellow : Dim;
            if (slow) { lvl.text = "Lv " + w.level; killsL.text = Loc.Tr("처치 " + w.kills); }
            // 무기·시약 아이콘(바뀔 때만 다시 만든다)
            var sb = slow ? new System.Text.StringBuilder() : null;
            if (slow) { foreach (var x in w.weapons) sb.Append(x.def.id).Append(x.level).Append(x.evolved ? "*" : "").Append(',');
            foreach (var kv in w.passives) sb.Append(kv.Key).Append(kv.Value).Append(','); }
            if (slow && sb.ToString() != iconKey)
            {
                iconKey = sb.ToString(); iconRowW.Clear(); iconRowP.Clear();
                foreach (var x in w.weapons) Tile(iconRowW, x.def.id, x.def.color, x.level, DB.WeaponMaxLevel, 54, x.evolved);
                foreach (var kv in w.passives) Tile(iconRowP, kv.Key, DB.Green, kv.Value, DB.PassiveMaxLevel, 44, false);
            }
            bool hasBoss = w.boss != null;
            bossBox.style.display = hasBoss ? DisplayStyle.Flex : DisplayStyle.None;
            if (hasBoss) { bossFill.style.width = Length.Percent(Mathf.Clamp01(w.boss.hp / w.boss.maxHp) * 100f); if (slow) bossName.text = Loc.Tr(w.boss.bdef.name + "  ·  " + (w.boss.stage2 && w.boss.bdef.title2 != "" ? w.boss.bdef.title2 : w.boss.bdef.title)); }
            if (slow) toastL.text = Loc.Tr(w.toastT > 0f && w.toasts.Count > 0 ? string.Join("\n", w.toasts) : "");
            toastL.style.opacity = Mathf.Clamp01(w.toastT);
            for (int i = 0; i < dashRow.childCount; i++) dashRow[i].style.opacity = i < w.dashCharges ? 1f : 0.2f;
            ultFill.style.width = Length.Percent(w.ult); ultFill.style.backgroundColor = w.ult >= 100f ? DB.Yellow : new Color(0.7f, 0.6f, 0.25f);
            if (slow) ultText.text = Loc.Tr(w.ult >= 100f ? "Q  ·  " + w.ch.ult + " 준비 완료!" : "Space 대시   ·   Q " + w.ch.ult);
            ultText.style.color = w.ult >= 100f ? DB.Yellow : Dim;
            bool gift = w.giftT > 0f && w.lastGift.Count > 0;
            giftBox.style.display = gift ? DisplayStyle.Flex : DisplayStyle.None;
            if (gift) { if (slow) giftL.text = Loc.Tr("선물상자 개봉!\n" + string.Join("\n", w.lastGift)); giftBox.style.opacity = Mathf.Clamp01(w.giftT); }
            // 피해 숫자
            var cam = Game.I.cam; int k = 0;
            for (; k < w.nums.Count && k < numPool.Count; k++)
            {
                var n = w.nums[k]; var l = numPool[k];
                Vector3 sp = cam.WorldToScreenPoint(n.pos);
                Vector2 pp = RuntimePanelUtils.ScreenToPanel(root.panel, new Vector2(sp.x, Screen.height - sp.y));
                if (l.style.display != DisplayStyle.Flex) l.style.display = DisplayStyle.Flex;
                l.style.translate = new Translate(pp.x - 30, pp.y - 10);                      // 레이아웃을 다시 잡지 않도록 위치는 변환으로만
                if (numVal[k] != n.value || numRef[k] != n) { numVal[k] = n.value; numRef[k] = n; l.text = n.value.ToString(); l.style.color = Color.Lerp(Color.white, n.color, 0.35f); }
                l.style.opacity = 1f - (n.t / 0.6f) * (n.t / 0.6f);
            }
            for (; k < numPool.Count; k++) if (numPool[k].style.display != DisplayStyle.None) numPool[k].style.display = DisplayStyle.None;
        }

        // ── 공통 메뉴(세로 목록) ──
        bool titleMode;
        public void Close()
        {
            modal.Clear(); rows.Clear(); acts.Clear(); adjs.Clear(); lvOpts = null; onBack = null; titleMode = false;
            modal.style.backgroundColor = Color.clear;      // 창 뒤의 어두운 막도 같이 걷는다(안 걷으면 레벨업·일시정지 뒤에 화면이 계속 어둡다)
        }

        VisualElement Open(string title, string subtitle, float width, bool dim = true)
        {
            Close(); sel = 0; openedFrame = Time.frameCount;
            modal.style.backgroundColor = dim ? new Color(0, 0, 0.02f, 0.72f) : Color.clear;
            modal.style.alignItems = Align.Center; modal.style.justifyContent = Justify.Center;
            var p = Box(modal, Panel, Line, 2f, 8f);
            p.style.width = width; p.style.paddingLeft = p.style.paddingRight = 28; p.style.paddingTop = 22; p.style.paddingBottom = 22;
            if (title != "") { var t = T(p, title, 34, DB.White, true, TextAnchor.MiddleCenter); t.style.marginBottom = subtitle == "" ? 16 : 4; }
            if (subtitle != "") { var s = T(p, subtitle, 17, Dim, false, TextAnchor.MiddleCenter); s.style.marginBottom = 16; s.style.whiteSpace = WhiteSpace.Normal; }
            return p;
        }

        VisualElement Row(VisualElement parent, string label, string value, Action act, Action<int> adj = null, Color? c = null)
        {
            var r = Box(parent, new Color(0.08f, 0.1f, 0.16f, 0.85f), new Color(DB.Cyan.r, DB.Cyan.g, DB.Cyan.b, 0.25f), 1.5f, 5f);
            r.style.flexDirection = FlexDirection.Row; r.style.height = 48; r.style.marginBottom = 8; r.style.alignItems = Align.Center; r.style.paddingLeft = r.style.paddingRight = 18;
            r.style.justifyContent = value == null ? Justify.Center : Justify.SpaceBetween;
            T(r, label, 21, c ?? DB.White, false, value == null ? TextAnchor.MiddleCenter : TextAnchor.MiddleLeft);
            if (value != null) T(r, (adj != null ? "◀   " : "") + value + (adj != null ? "   ▶" : ""), 20, DB.Cyan, true, TextAnchor.MiddleRight);
            rows.Add(r); acts.Add(act); adjs.Add(adj);
            return r;
        }

        void Highlight()
        {
            for (int i = 0; i < rows.Count; i++)
            {
                bool on = i == sel; var r = rows[i];
                if (titleMode)
                {
                    Color tb = on ? DB.Cyan : new Color(1f, 1f, 1f, 0.12f);
                    r.style.borderLeftColor = r.style.borderRightColor = r.style.borderTopColor = r.style.borderBottomColor = tb;
                    r.style.backgroundColor = on ? new Color(0.08f, 0.3f, 0.5f, 0.62f) : new Color(0.01f, 0.02f, 0.05f, 0.55f);
                    r.style.scale = new Scale(on ? new Vector3(1.04f, 1.04f, 1f) : Vector3.one);
                    continue;
                }
                Color b = on ? DB.Cyan : new Color(DB.Cyan.r, DB.Cyan.g, DB.Cyan.b, 0.25f);
                r.style.borderLeftColor = r.style.borderRightColor = r.style.borderTopColor = r.style.borderBottomColor = b;
                r.style.backgroundColor = lvOpts != null ? (on ? new Color(0.1f, 0.2f, 0.36f, 0.95f) : new Color(0.04f, 0.06f, 0.1f, 0.95f)) : (on ? new Color(0.2f, 0.4f, 0.7f, 0.5f) : new Color(0.08f, 0.1f, 0.16f, 0.85f));
            }
        }

        void MenuInput()
        {
            if (rows.Count == 0 || Time.frameCount == openedFrame) return;
            int old = sel; bool horiz = lvOpts != null;
            if (horiz ? Inp.Left : Inp.Up) sel = (sel - 1 + rows.Count) % rows.Count;
            if (horiz ? Inp.Right : Inp.Down) sel = (sel + 1) % rows.Count;
            Vector2 m = Inp.MousePos;
            Vector2 mp = RuntimePanelUtils.ScreenToPanel(root.panel, new Vector2(m.x, Screen.height - m.y));
            int hover = -1;
            for (int i = 0; i < rows.Count; i++) if (rows[i].worldBound.Contains(mp)) hover = i;
            if (hover >= 0 && Mouse(m)) sel = hover;
            if (sel != old) Audio.Play("ui_move", 0.7f);
            Highlight();
            int go = -1;
            if (Inp.Confirm) go = sel;
            if (Inp.Click && hover >= 0) go = hover;
            if (lvOpts != null) { int c = Inp.Choice; if (c >= 0 && c < rows.Count) go = c; if (Inp.Reroll && Game.I.world.rerolls > 0) { Game.I.world.rerolls--; Audio.Play("ui_select"); ShowLevelUp(Game.I.world); return; } }
            else
            {
                if (adjs[sel] != null && Inp.Left) { Audio.Play("ui_move"); adjs[sel](-1); return; }
                if (adjs[sel] != null && Inp.Right) { Audio.Play("ui_move"); adjs[sel](1); return; }
                if (Inp.Back && onBack != null) { Audio.Play("ui_move"); var b = onBack; b(); return; }
            }
            if (go >= 0 && Time.unscaledTime >= lockUntil)
            {
                Audio.Play("ui_select");
                if (acts[go] != null) acts[go]();
                else if (adjs[go] != null)
                {
                    // 값(◀ … ▶)의 왼쪽 절반을 누르면 내리고, 그 밖은 올린다
                    int dir = 1;
                    if (Inp.Click && hover == go && rows[go].childCount > 1) { var vb = rows[go][rows[go].childCount - 1].worldBound; if (mp.x >= vb.xMin && mp.x < vb.center.x) dir = -1; }
                    adjs[go](dir);
                }
            }
        }
        Vector2 lastMouse; bool Mouse(Vector2 m) { bool moved = (m - lastMouse).sqrMagnitude > 4f; lastMouse = m; return moved; }

        // ── 화면들 ──
        /// 타이틀: 로고와 배경은 월드(TitleScene)가 그리고, 여기서는 부제·메뉴·바닥글만 얹는다.
        public void ShowTitle()
        {
            Close(); sel = 0; openedFrame = Time.frameCount; titleMode = true;
            modal.style.backgroundColor = Color.clear; modal.style.alignItems = Align.Center; modal.style.justifyContent = Justify.FlexStart;
            var story = T(modal, "12월 24일 밤, 모두 퇴근한 연구소  —  세포들의 야근이 시작된다", 19, new Color(0.82f, 0.88f, 0.97f), false, TextAnchor.MiddleCenter);
            Abs(story, 0, null, 0, null); story.style.top = Length.Percent(57.2f); story.style.letterSpacing = 1.5f;
            var col = new VisualElement(); col.pickingMode = PickingMode.Ignore; modal.Add(col);
            Abs(col, null, null, null, null, 360); col.style.top = Length.Percent(62f); col.style.left = Length.Percent(50f); col.style.marginLeft = -180;
            void Item(string label, Action act, Color? c = null)
            {
                var r = Row(col, label, null, act, null, c);
                r.style.height = 40; r.style.marginBottom = 6;
                r.style.borderTopLeftRadius = r.style.borderTopRightRadius = r.style.borderBottomLeftRadius = r.style.borderBottomRightRadius = 26;
                var l = r.Q<Label>(); l.style.fontSize = 19; l.style.unityFontDefinition = new StyleFontDefinition(bold); l.style.letterSpacing = 2f;
            }
            Item("실험 시작", () => ShowPrep());
            Item("연구실", () => ShowLab());
            Item("도감", () => ShowCodex(0));
            Item("설정", () => ShowSettings());
            Item("크레딧", () => ShowCredits());
            Item("종료", () => Application.Quit());
            var keys = T(modal, "WASD 이동   ·   Space 대시   ·   Q 궁극기   ·   공격은 자동   ·   F11 전체화면", 15, Dim, false, TextAnchor.MiddleCenter);
            var lg = T(modal, Loc.English ? "ENG" : "KOR", 14, Dim, true, TextAnchor.MiddleLeft); Abs(lg, 34, 80, null, null); lg.style.letterSpacing = 2f;
            Abs(keys, 0, null, 0, 34);
            var credit = T(modal, "v" + Application.version + "   ·   Game by Seung-Won Chae (SNUH Laboratory Medicine)", 13, new Color(0.5f, 0.56f, 0.68f), false, TextAnchor.MiddleCenter);
            Abs(credit, 0, null, 0, 12);
            if (Save.D.runs > 0)
            {
                var st = T(modal, "연구비 " + Save.D.grant + "     클리어 " + Save.D.clears + "     실험 " + Save.D.runs + "회", 16, DB.Yellow, true, TextAnchor.MiddleRight);
                Abs(st, null, 78, 34, null);
            }
        }

        int setSel;
        static readonly string[] GfxNames = { "자동", "낮음", "보통", "높음", "최고" };
        public void ShowSettings()
        {
            var p = Open("설정", "바로 적용되고 저장됩니다. 그래픽 '자동'은 느려지면 내부 해상도를 알아서 낮춥니다.", 780);
            void Vol(string label, Func<float> get, Action<float> set, int idx)
            {
                Row(p, label, Mathf.RoundToInt(get() * 100f) + "%", null, d =>
                {
                    set(Mathf.Clamp(Mathf.RoundToInt(get() * 20f) + d, 0, 20) / 20f);
                    Audio.Master = Save.D.master; Audio.Music = Save.D.music; Audio.Sfx = Save.D.sfx; Save.Write();
                    if (idx == 3) Audio.Play("pickup", 1f); else if (idx == 1) Audio.Play("ui_select", 1f);
                    setSel = idx; ShowSettings();
                });
            }
            Row(p, "언어  Language", Save.D.lang == 1 ? "English" : "한국어", null, d => { Save.D.lang = 1 - Save.D.lang; Save.Write(); setSel = 0; ShowSettings(); });
            Vol("전체 음량", () => Save.D.master, v => Save.D.master = v, 1);
            Vol("음악 음량", () => Save.D.music, v => Save.D.music = v, 2);
            Vol("효과음 음량", () => Save.D.sfx, v => Save.D.sfx = v, 3);
            int g = Mathf.Clamp(Save.D.gfx, 0, 4), cap = Game.QualityCap[g];
            Row(p, "그래픽", GfxNames[g] + "  ·  " + Mathf.Min(cap, Screen.height) + "p", null, d => { Save.D.gfx = (Save.D.gfx + d + 5) % 5; Save.Write(); setSel = 4; ShowSettings(); });
            Row(p, "전체화면", Game.I.IsFullscreen ? "켜짐" : "꺼짐", null, d => { Game.I.ToggleFullscreen(); setSel = 5; ShowSettings(); });
            Row(p, "돌아가기", null, () => { setSel = 0; ShowTitle(); });
            var note = T(p, "화면 " + Screen.width + "×" + Screen.height + "  ·  지금 창이 내부 해상도 상한보다 작으면 그래픽 단계를 바꿔도 화질은 같습니다.", 14, Dim, false, TextAnchor.MiddleCenter); note.style.whiteSpace = WhiteSpace.Normal; note.style.marginTop = 6;
            onBack = () => { setSel = 0; ShowTitle(); };
            sel = setSel;
        }

        /// 개발용: 메뉴 줄을 코드로 누른다(설정 화면 자동 점검)
        public string DevPress(int row, int dir)
        {
            if (row < 0 || row >= rows.Count) return "no row " + row;
            sel = row;
            if (adjs[row] != null) adjs[row](dir); else if (acts[row] != null) acts[row]();
            return "pressed " + row + (dir < 0 ? " ◀" : " ▶");
        }

        // ── 연구실: 연구비로 영구 강화를 산다 ──
        int labSel;
        public void ShowLab()
        {
            var p = Open("연구실", "연구비로 다음 실험을 준비한다.   보유 연구비 " + Save.D.grant, 880);
            for (int i = 0; i < DB.Upgrades.Length; i++)
            {
                var u = DB.Upgrades[i]; int lv = Save.Upgrade(u.id), cost = DB.UpgradeCost(u, lv), idx = i; bool max = lv >= u.max, can = !max && Save.D.grant >= cost;
                Row(p, u.name + "  ·  Lv " + lv + "/" + u.max + "  ·  " + u.text, max ? "MAX" : "연구비 " + cost, () =>
                {
                    if (!can) return;
                    Save.D.grant -= cost; Save.SetUpgrade(u.id, lv + 1); Save.Write(); Audio.Play("levelup", 0.8f);
                    labSel = idx; ShowLab();
                }, null, max ? DB.Green : (can ? DB.White : Dim));
            }
            Row(p, "돌아가기", null, () => { labSel = 0; ShowTitle(); });
            onBack = () => { labSel = 0; ShowTitle(); };
            sel = Mathf.Clamp(labSel, 0, rows.Count - 1);
        }

        // ── 도감: 만난 것만 기록된다 ──
        static readonly string[] CodexCats = { "오염균", "PCR 산물", "숏리드 아티팩트", "롱리드 아티팩트", "서버 오류", "보스", "무기", "시약" };
        public void ShowCodex(int cat)
        {
            cat = (cat + CodexCats.Length) % CodexCats.Length;
            int total = 0, found = 0;
            void Count(string id) { total++; if (Save.D.codex.Contains(id)) found++; }
            foreach (var e in DB.Enemies) if (!e.child) Count(e.id);
            foreach (var b in DB.Bosses) Count(b.id);
            foreach (var w in DB.Weapons) { Count(w.id); if (w.evolveWith != "") Count(w.id + "_evo"); }
            foreach (var d in DB.Passives) Count(d.id);
            var p = Open("도감", "기록 " + found + " / " + total, 900);
            Row(p, "분류", CodexCats[cat], null, d => ShowCodex(cat + d));
            void Entry(string id, string name, string text, Color col, bool icon)
            {
                bool known = Save.D.codex.Contains(id);
                var r = new VisualElement(); r.style.flexDirection = FlexDirection.Row; r.style.alignItems = Align.Center; r.style.marginBottom = 5; r.style.marginLeft = 8; r.pickingMode = PickingMode.Ignore; p.Add(r);
                if (icon) { var ic = new Icon(known ? id : "?", known ? col : Dim, 26); ic.style.marginRight = 10; r.Add(ic); }
                else { var dot = Box(r, known ? col : new Color(0.3f, 0.32f, 0.4f), Color.clear, 0f, 6f); dot.style.width = 12; dot.style.height = 12; dot.style.marginRight = 12; dot.style.marginLeft = 6; }
                var n = T(r, known ? name : "???", 18, known ? col : Dim, true); n.style.minWidth = 230; n.style.marginRight = 16; n.style.flexShrink = 0;
                var t = T(r, known ? text : "아직 만나지 못했다", 15, known ? new Color(0.85f, 0.88f, 0.95f) : new Color(0.45f, 0.48f, 0.58f)); t.style.whiteSpace = WhiteSpace.Normal; t.style.flexShrink = 1;
            }
            if (cat <= 4) foreach (var e in DB.Enemies) { if (!e.child && e.group == cat) Entry(e.id, e.name, DB.Lore[e.id], e.color, false); }
            else if (cat == 5)
            {
                foreach (var b in DB.Bosses) Entry(b.id, b.name + "  ·  " + b.title, DB.Lore[b.id], b.color, false);
                foreach (var e in DB.Enemies) if (e.group == 5) Entry(e.id, "  ↳ " + e.name, DB.Lore[e.id], e.color, false);      // Reviewer가 불러내는 것들
            }
            else if (cat == 6)
                foreach (var w in DB.Weapons)
                {
                    Entry(w.id, w.name, w.desc + (w.block > 0f ? "  ·  탄환 차단 " + Mathf.RoundToInt(w.block * 100f) + "%" : ""), w.color, true);
                    if (w.evolveWith != "") Entry(w.id + "_evo", "  ↳ " + w.evolvedName, w.evolvedDesc + "  (Lv" + DB.WeaponMaxLevel + " + " + DB.Passive(w.evolveWith).name + ")", DB.Yellow, false);
                }
            else foreach (var d in DB.Passives) Entry(d.id, d.name, d.text, DB.Green, true);
            var sp = new VisualElement(); sp.style.height = 10; p.Add(sp);
            Row(p, "돌아가기", null, () => ShowTitle());
            onBack = () => ShowTitle();
        }

        // ── 엔딩: 최종 구역을 깼을 때 결과 화면 앞에 나온다 ──
        public void ShowEnding(RunResult r)
        {
            var p = Open("Decision on Manuscript CS-2026-1224", "From: Editorial Office", 820);
            void Line(string h, float size, Color c, bool b = false) { var l = T(p, h, size, c, b, TextAnchor.MiddleCenter); l.style.whiteSpace = WhiteSpace.Normal; l.style.marginTop = 8; }
            Line("Dear Dr. " + DB.Char(r.charId).name + ",", 20, DB.White);
            Line("심사위원 전원이 게재에 동의했습니다. 귀하의 논문은 수정 없이 게재가 확정되었습니다.", 19, DB.White);
            Line("ACCEPTED", 46, DB.Green, true);
            Line("Reviewer #1: \"좋은 연구였습니다.\"", 17, DB.Yellow);
            Line("Reviewer #2: \"더 지적할 것이 없습니다. …메리 크리스마스.\"", 17, DB.Red);
            Line("12월 25일 아침. 연구원들이 출근했을 때, 배양접시는 깨끗했다.", 18, Dim);
            var sp = new VisualElement(); sp.style.height = 16; p.Add(sp);
            Row(p, "계속", null, () => ShowResult(r));
            lockUntil = Time.unscaledTime + 1.2f;
        }

        public void ShowCredits()
        {
            var p = Open("CREDIT", "Colony Survival  ·  v" + Application.version + "  ·  Lab Xmas Edition", 780);
            void Head(string h) { var l = T(p, h, 14, DB.Cyan, true, TextAnchor.MiddleCenter); l.style.marginTop = 12; l.style.letterSpacing = 3f; }
            void Line(string h, float size = 19) { var l = T(p, h, size, DB.White, false, TextAnchor.MiddleCenter); l.style.whiteSpace = WhiteSpace.Normal; l.style.marginTop = 2; }
            Head("GAME DESIGN  ·  DEVELOPMENT");
            Line("채승원  Seung Won Chae", 24);
            Head("AFFILIATION");
            Line("Seoul National University Hospital, Department of Laboratory Medicine");
            Line("Seoul National University, Cancer Research Institute");
            Head("ENGINE");
            Line("Unity 6", 17);
            Head("MUSIC  ·  ART");
            Line("made by Seung Won Chae", 17);
            Head("FONT");
            Line("Pretendard — SIL Open Font License 1.1", 17);
            var th = T(p, "크리스마스이브에도 실험실을 지키는 모든 연구자에게.", 17, DB.Yellow, false, TextAnchor.MiddleCenter); th.style.marginTop = 16; th.style.marginBottom = 14;
            Row(p, "돌아가기", null, () => ShowTitle());
            onBack = () => ShowTitle();
        }

        int zi, ci; bool useVariant;
        public void ShowPrep()
        {
            var lastZ = DB.Zone(Save.D.lastZone); useVariant = lastZ.variantOf != null;
            zi = Mathf.Max(0, Array.FindIndex(DB.Zones, z => z.id == (lastZ.variantOf ?? lastZ.id))); ci = Mathf.Max(0, Array.FindIndex(DB.Chars, c => c.id == Save.D.lastChar));
            if (!Save.ZoneOpen(zi)) zi = 0;
            if (!Save.CharOpen(DB.Chars[ci])) ci = 0;
            BuildPrep(0);
        }
        void BuildPrep(int keepSel)
        {
            var zb = DB.Zones[zi]; var zv = DB.VariantOf(zb.id); var c = DB.Chars[ci];
            var z = zv != null && useVariant ? zv : zb;
            Audio.Preload(z.music ?? "dish", 4);
            bool zOpen = Save.ZoneOpen(zi), cOpen = Save.CharOpen(c);
            var p = Open("실험 준비", "", 760);
            Row(p, "구역  " + (zi + 1) + " / " + DB.Zones.Length, zb.name + (Save.Cleared(zb.id) ? "  ✓" : (zOpen ? "" : "  (잠김)")), null, d => { zi = (zi + d + DB.Zones.Length) % DB.Zones.Length; BuildPrep(0); });
            if (zv != null) Row(p, "플랫폼", z.variantName + (Save.Cleared(z.id) ? "  ✓" : ""), null, d => { useVariant = !useVariant; BuildPrep(1); });
            int o = zv != null ? 1 : 0;
            var zd = T(p, z.desc + (zOpen ? "" : "\n앞 구역을 클리어하면 열립니다."), 16, Dim); zd.style.whiteSpace = WhiteSpace.Normal; zd.style.marginBottom = 12; zd.style.marginLeft = 6;
            Row(p, "셀라인", c.name + (cOpen ? "" : "  (잠김)"), null, d => { ci = (ci + d + DB.Chars.Length) % DB.Chars.Length; BuildPrep(1 + o); });
            var cd = T(p, "시작 무기: " + DB.Weapon(c.startWeapon).name + "\n고유 능력 — " + c.perk + ": " + c.perkText + "\n궁극기(Q) — " + c.ult + ": " + c.ultText + (cOpen ? "" : "\n배양접시를 클리어하면 해금됩니다."), 16, Dim);
            cd.style.whiteSpace = WhiteSpace.Normal; cd.style.marginBottom = 12; cd.style.marginLeft = 6;
            var df = DB.Diffs[Save.D.lastDiff];
            Row(p, "난이도", df.name, null, d => { Save.D.lastDiff = (Save.D.lastDiff + d + 3) % 3; BuildPrep(2 + o); });
            var dd = T(p, df.desc, 16, Save.D.lastDiff == 0 ? DB.Green : (Save.D.lastDiff == 2 ? DB.Red : Dim)); dd.style.marginBottom = 12; dd.style.marginLeft = 6;
            Row(p, zOpen && cOpen ? "실험 시작" : "잠겨 있습니다", null, () => { if (zOpen && cOpen) { Save.D.lastZone = z.id; Save.D.lastChar = c.id; Save.Write(); Game.I.StartRun(c.id, z.id, Save.D.lastDiff); } }, null, zOpen && cOpen ? DB.Green : Dim);
            Row(p, "돌아가기", null, () => ShowTitle());
            onBack = () => ShowTitle(); sel = keepSel;
        }

        public static int HudTextFrame;
        /// 개발용: 떠 있는 레벨업 카드 중 봇이 고를 것을 실제 UI 경로로 누른다
        public bool DevPickLevel(World w)
        {
            if (lvOpts == null || acts.Count == 0) return false;
            int i = Mathf.Max(0, lvOpts.IndexOf(w.BotPick(lvOpts))); if (i >= acts.Count) i = 0;
            acts[i](); return true;
        }

        public void ShowLevelUp(World w)
        {
            var opts = w.BuildOptions(3);
            var p = Open("레벨 업!  Lv " + w.level, "하나를 고르세요  ·  1 2 3 / ←→ + Enter / 클릭" + (w.rerolls > 0 ? "  ·  R 다시 뽑기 (" + w.rerolls + ")" : ""), 1080);
            lvOpts = opts; lockUntil = Time.unscaledTime + 0.4f;
            var row = new VisualElement(); row.style.flexDirection = FlexDirection.Row; row.style.justifyContent = Justify.SpaceBetween; p.Add(row);
            for (int i = 0; i < opts.Count; i++)
            {
                var o = opts[i]; int idx = i;
                var card = Box(row, new Color(0.04f, 0.06f, 0.1f, 0.95f), Line, 2f, 8f);
                card.style.width = 325; card.style.height = 300; card.style.alignItems = Align.Center; card.style.paddingTop = 18; card.style.paddingLeft = card.style.paddingRight = 16;
                T(card, (i + 1).ToString(), 15, Dim, true, TextAnchor.MiddleCenter);
                card.Add(new Icon(o.id, o.color, 96));
                T(card, o.title, 23, o.color, true, TextAnchor.MiddleCenter).style.marginTop = 8;
                T(card, o.type == "heal" ? "" : (o.isNew ? "새로 획득" : "Lv " + (o.level - 1) + " → " + o.level), 16, o.isNew ? DB.Yellow : Dim, true, TextAnchor.MiddleCenter);
                var d = T(card, o.text, 17, DB.White, false, TextAnchor.UpperCenter); d.style.whiteSpace = WhiteSpace.Normal; d.style.marginTop = 8;
                if (o.type == "weapon") { var wd = DB.Weapon(o.id); if (wd.evolveWith != "") { var ev = T(card, "진화: " + DB.Passive(wd.evolveWith).name + " + Lv8", 13, new Color(0.8f, 0.7f, 0.35f), false, TextAnchor.MiddleCenter); ev.style.marginTop = 6; } }
                rows.Add(card); adjs.Add(null);
                acts.Add(() => { w.Apply(opts[idx]); Audio.Play("levelup", 0.8f); Close(); Game.I.AfterLevelUp(); });
            }
        }

        public void ShowPause(World w)
        {
            var p = Open("일시정지", w.zone.name + "  ·  " + w.ch.name + "  ·  " + w.diff.name, 520);
            Row(p, "계속하기", null, () => Game.I.Resume());
            Row(p, "전체화면 켜기 / 끄기", null, () => Game.I.ToggleFullscreen());
            Row(p, "피해 숫자  " + (Save.D.damageNumbers ? "켜짐" : "꺼짐"), null, () => { Save.D.damageNumbers = !Save.D.damageNumbers; Save.Write(); ShowPause(w); });
            Row(p, "화면 흔들림  " + (Save.D.shake ? "켜짐" : "꺼짐"), null, () => { Save.D.shake = !Save.D.shake; Save.Write(); ShowPause(w); });
            Row(p, "타이틀로 (이번 실험 포기)", null, () => Game.I.ToTitle());
            onBack = () => Game.I.Resume();
        }

        public void ShowResult(RunResult r)
        {
            var z = DB.Zone(r.zoneId);
            bool last = r.zoneId == DB.Zones[DB.Zones.Length - 1].id;
            var p = Open(r.victory ? (last ? "Accepted!  게재 승인" : z.name + " 클리어!") : "컨탐되었습니다…",
                r.victory ? (last ? "Reviewer #2를 통과했다. 콜로니도, 논문도 무사하다. 메리 크리스마스!" : (z.clearText ?? "콜로니는 무사하다. 다음 구역이 열렸다.")) : DB.Clock(r.time) + " 에 배양이 끝났다.", 700);
            T(p, DB.Char(r.charId).name + "   ·   " + DB.Diffs[r.diff].name + "   ·   생존 " + (int)r.time / 60 + ":" + ((int)r.time % 60).ToString("00") + "   ·   Lv " + r.level + "   ·   처치 " + r.kills, 19, DB.White, true, TextAnchor.MiddleCenter);
            var b = T(p, string.Join("   ", r.build), 15, DB.Cyan, false, TextAnchor.MiddleCenter); b.style.whiteSpace = WhiteSpace.Normal; b.style.marginTop = 8;
            T(p, "연구비 +" + r.grant + "   (보유 " + Save.D.grant + ")", 22, DB.Yellow, true, TextAnchor.MiddleCenter).style.marginTop = 12;
            if (r.unlocked.Count > 0) T(p, "새로 열림: " + string.Join(", ", r.unlocked), 18, DB.Green, true, TextAnchor.MiddleCenter);
            var sp = new VisualElement(); sp.style.height = 14; p.Add(sp);
            Row(p, "다시 하기", null, () => Game.I.StartRun(r.charId, r.zoneId, r.diff));
            Row(p, "실험 준비로", null, () => { Game.I.ToTitle(); ShowPrep(); });
            Row(p, "타이틀로", null, () => Game.I.ToTitle());
        }
    }
}
