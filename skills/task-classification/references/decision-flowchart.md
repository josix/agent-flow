# Decision Flowchart

Visual guides for rapid task classification decisions in the multi-agent orchestration system.

---

## 1. Primary Classification Flowchart

```
                    +---------------------+
                    |   New User Request  |
                    +----------+----------+
                               |
                    +----------v----------+
                    |  Is it a question   |
                    |  (no code changes)? |
                    +----------+----------+
                               |
              +----------------+----------------+
              | YES                             | NO
              v                                 v
    +-----------------+              +-----------------+
    | Does it need    |              | Requires        |
    | external info?  |              | external info?  |
    +--------+--------+              +--------+--------+
             |                                 |
    +--------+--------+              +--------+--------+
    | YES     | NO    |              | YES     | NO    |
    v         v       |              v         |       |
 Research   Trivial   |           Research     |       |
  (Riko)   (Direct)   |            (Riko)      |       |
                      |                        v       |
                      |              +-----------------+
                      |              | How many files  |
                      |              | affected?       |
                      |              +--------+--------+
                      |                       |
                      |         +-------------+-------------+
                      |         | 0-1         | 2-5         | 5+
                      |         v             v             v
                      |    +---------+   +---------+   +---------+
                      |    | Trivial |   | Impl    |   | Check   |
                      |    | (Loid)  |   | (Loid)  |   | Risk    |
                      |    +---------+   +----+----+   +----+----+
                      |                       |             |
                      |                       v             |
                      |              +-------------+        |
                      |              | Alphonse    |        |
                      |              | (Verify)    |        |
                      |              +-------------+        |
                      |                                     |
                      |              +----------------------+
                      |              |
                      |              v
                      |    +---------------------+
                      |    | Security/DB/API     |
                      |    | changes involved?   |
                      |    +----------+----------+
                      |               |
                      |    +----------+----------+
                      |    | YES                 | NO
                      |    v                     v
                      |  Complex            Implementation
                      |  (Full Orch)        + Lawliet review
                      |
                      +--- For read-only ---> Exploratory (Riko)
```

---

## 2. Quick Decision Path

For rapid classification, answer three questions:

```
Question 1: Is this read-only?
    |
    +-- YES --> Exploratory (Riko)
    |
    +-- NO --> Continue to Question 2

Question 2: How many files?
    |
    +-- 0-1 --> Trivial (consider: is it really that simple?)
    |
    +-- 2-5 --> Implementation (Loid -> Alphonse)
    |
    +-- 5+ --> Likely Complex, check Question 3

Question 3: High-risk domain involved?
    |
    +-- YES --> Complex (Full Orchestration)
    |
    +-- NO --> Implementation with review consideration
```

---

## 3. Risk-Based Classification

```
                    +------------------+
                    |  Identify Risk   |
                    |    Factors       |
                    +--------+---------+
                             |
            +----------------+----------------+
            |                |                |
            v                v                v
    +-------+------+ +-------+------+ +-------+------+
    | Security     | | Data         | | API          |
    | Related?     | | Related?     | | Related?     |
    +-------+------+ +-------+------+ +-------+------+
            |                |                |
            v                v                v
    +-------+------+ +-------+------+ +-------+------+
    | Auth change  | | Schema mod   | | Breaking     |
    | Crypto mod   | | Migration    | | change       |
    | Permission   | | Data delete  | | New endpoint |
    +-------+------+ +-------+------+ +-------+------+
            |                |                |
            +--------+-------+--------+-------+
                     |                |
            +--------v--------+  +----v----+
            |    COMPLEX      |  | IMPL +  |
            | (Full Orch +    |  | Review  |
            |  Lawliet)       |  +---------+
            +-----------------+
```

---

## 4. Agent Selection Flowchart

```
                    +------------------+
                    | Classification   |
                    | Determined       |
                    +--------+---------+
                             |
        +--------------------+--------------------+
        |          |         |         |         |
        v          v         v         v         v
    +-------+  +-------+ +-------+ +-------+ +-------+
    |Trivial|  |Explor |  |Impl  | |Complex| |Research|
    +---+---+  +---+---+ +---+---+ +---+---+ +---+---+
        |          |         |         |         |
        v          v         v         v         v
    +-------+  +-------+ +-------+ +-------+ +-------+
    |Direct |  | Riko  | | Loid  | | Riko  | | Riko  |
    |Response| |       | |   |   | |   |   | |   +   |
    +-------+  +-------+ |   v   | |   v   | |WebSrch|
                         |Alphonse| | Senku | +-------+
                         +-------+ |   |   |
                                   |   v   |
                                   | Loid  |
                                   |   |   |
                                   +---+---+
                                       |
                               +-------+-------+
                               |               |
                               v               v
                           +-------+       +-------+
                           |Alphonse|      |Lawliet|
                           +-------+       +-------+
```

---

## 5. Verification Decision

```
                    +------------------+
                    | Task Completed   |
                    +--------+---------+
                             |
                    +--------v---------+
                    | What was the     |
                    | classification?  |
                    +--------+---------+
                             |
        +--------------------+--------------------+
        |                    |                    |
        v                    v                    v
    +-------+           +--------+           +--------+
    |Trivial|           | Impl   |           |Complex |
    |Explor |           +----+---+           +----+---+
    |Research|               |                    |
    +---+---+               |                    |
        |                    |                    |
        v                    v                    v
    +-------+           +--------+           +--------+
    | NO    |           |ALPHONSE|           |ALPHONSE|
    |VERIFY |           | Tests  |           | Tests  |
    +-------+           | Types  |           +----+---+
                        | Lint   |                |
                        | Build  |                v
                        +--------+           +--------+
                                             |LAWLIET |
                                             | Review |
                                             +--------+
```

---

## 6. Escalation Triggers

```
During any phase, escalate if:

    +------------------+
    | Trigger Event    |
    +--------+---------+
             |
    +--------+--------+--------+--------+
    |        |        |        |        |
    v        v        v        v        v
+------+ +------+ +------+ +------+ +------+
|More  | |New   | |Secur | |Break | |Scope |
|files | |deps  | |issue | |change| |creep |
|found | |found | |found | |needed| |      |
+--+---+ +--+---+ +--+---+ +--+---+ +--+---+
   |        |        |        |        |
   +--------+--------+--------+--------+
                     |
                     v
            +--------+--------+
            | Re-classify UP  |
            | Document reason |
            | Notify user     |
            +-----------------+
```

---

## 7. Quick Reference Summary

| Question | Answer | Classification |
|----------|--------|----------------|
| Is this read-only? | Yes | Exploratory (Riko) |
| Files: 0-1? | Yes | Trivial (Direct/Loid) |
| Files: 2-5? | Yes | Implementation (Loid -> Alphonse) |
| Files: 5+? | Yes | Complex (Full Orchestration) |
| Security/DB/API? | Yes | Complex (regardless of file count) |
| Needs research? | Yes | Research (Riko + WebSearch) |

---

## See Also

- [SKILL.md](../SKILL.md) - Main task classification documentation
- [classification-process.md](classification-process.md) - Detailed classification steps
- [agent-selection-matrix.md](agent-selection-matrix.md) - Agent routing details
