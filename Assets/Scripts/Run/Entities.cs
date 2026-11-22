using System;
using System.Collections.Generic;
using UnityEngine;

namespace CS
{
    public class Enemy
    {
        public EnemyDef def; public BossDef bdef;
        public Vector2 pos, knock, aim, vel;
        public float hp, maxHp, speed, dmg, radius, flash, seed, facing, charge, stateT, knockRes = 1f, poreCd, fieldCd, laserCd;
        public float infected, infectDps, infectAcc; public int infectSpread; public bool pandemic;
        public float bossA, bossB, bossC, bossC2, capAcc;
        public int state, xp, pattern; public bool elite, boss, dead, phase2, phase3;
        // 구역 전용 적의 행동용: 보조 타이머·각도·목표 지점, 쓰러져 있는 시간(좀비), 한 번 되살아났는지
        public float auxT, auxA, auxB, downT; public Vector2 auxP; public bool revived;
        // 2단계가 있는 보스(Reviewer #2): 변신 중 무적 시간, 2단계인지, 막판 폭주인지
        public float invulnT; public bool stage2, enraged;
        public bool IsBoss => bdef != null;
        public string Id => bdef != null ? bdef.id : def.id;
    }

    public class Proj
    {
        public int kind;                 // 0 유도탄(렌티바이러스) 1 창(CRISPR)
        public Vector2 pos, vel; public float radius, dmg, life, turn, speed; public int pierce;
        public Enemy target; public Color color; public Weapon src; public bool dead;
        public readonly HashSet<Enemy> hit = new HashSet<Enemy>();
    }

    public class EBullet { public Vector2 pos, vel; public float radius, dmg, life; public Color color; public bool dead; public int tried; /*이미 차단 판정을 굴린 무기(비트)*/
        public int kind; /*0 구슬 1 방울 2 막대 3 네모 조각*/ public float turn; /*초당 방향이 꺾이는 각도(rad) — 원을 그리며 도는 탄*/ }
    /// 바닥에 잠시 남는 웅덩이(밟으면 피해)
    public class EPool { public Vector2 pos; public float r, life, maxLife, dmg; public Color color; }

    public class Pickup { public int kind; /*0 ATP 1 코코아 2 볼텍스 3 선물상자*/ public int value; public Vector2 pos, vel; public bool attracted, dead; public float t, seed; }

    public class Area { public Vector2 pos; public float radius, dmg, life, maxLife, acc, block; public int bit; public Color color; }

    public class Particle { public Vector2 pos, vel; public float life, max, size, drag; public Color color; public int shape; }

    public class FxItem { public int type; /*0 링 1 빔 2 베기 3 섬광 기둥*/ public Vector2 a, b; public float r0, r1, t, dur, w, ang; public Color color; }

    public class Telegraph { public int type; /*0 원 1 선*/ public Vector2 a, b; public float r, t, dur; public Action cb; public bool cross; public Color color; /*알파 0이면 기본 노랑*/ }

    public class DmgNum { public Vector2 pos; public int value; public float t; public Color color; }

    public class LevelOption { public string type, id, title, text; public bool isNew, evolve; public Color color; public int level; }

    public class RunResult
    {
        public bool victory; public float time; public int level, kills, bossKills, grant; public string charId, zoneId; public int diff = 1;
        public List<string> build = new List<string>(); public List<string> unlocked = new List<string>();
    }
}
