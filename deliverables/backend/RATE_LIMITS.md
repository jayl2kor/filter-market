# Rate Limits

> 단일 소스: `functions/src/lib/ratelimit.ts`
>
> 구현: Firestore `_ratelimit/{bucket:key}` 도큐먼트 기반 sliding-window. 트랜잭션으로 atomic.
> 키 포맷: `${bucket.name}:${uid}` (인증 없는 경로는 IP 사용 — 현재 callable은 모두 인증 필요).
> 시그니처: `allow(redis: undefined, bucket, key, deps) → AllowResult`. (Memorystore Redis 옵션 자리 잡혀 있으나 MVP는 Firestore.)

---

## 1. 버킷 카탈로그

| Bucket name | limit | window | 적용 함수 |
|---|---|---|---|
| `default` | 60 | 60s | (예약 — 현재 미사용) |
| `filters.upload` | 10 | 3600s | (예약 — `uploadInit`/`uploadFinalize`에 적용 가능) |
| `filters.use` | 600 | 3600s | (예약 — `recordUse`에 적용 가능) |
| `filters.report` | 30 | 3600s | `reportFilter`, `reportReview`, `reportUser` |
| `identity.handle` | 5 | 86400s (24h) | (예약 — `setHandle`에 적용 가능) |
| `wallet.purchase` | 30 | 60s | `purchaseFilter` |
| `wallet.iap` | 10 | 60s | `creditCoinsFromIAP` |
| `wallet.refund` | 5 | 3600s | `refundRequest` |

> "예약"은 코드에 정의돼 있으나 현재 호출부에 wired-in 되지 않은 버킷.
> 활성 버킷은 호출부(`enforceRateLimit(...)`) 4개: report, walletPurchase, walletIAP, walletRefund.

---

## 2. 응답 동작

- 한도 미달 시: 핸들러 정상 진행. (응답에 remaining 미노출 — 클라이언트가 알 필요 없음.)
- 한도 초과 시:
  ```ts
  throw new HttpsError("resource-exhausted", "rate_limited", {
    limit: bucket.limit,
    resetAt: <epoch ms>
  });
  ```
- HTTP 매핑: 429.

클라이언트는 `error.details.resetAt`까지 재시도 disable + 사용자에게 잠시 후 재시도 안내.

---

## 3. 윈도우 알고리즘 (sliding window)

```
- doc = _ratelimit/{bucket:key}
- now - windowStart >= windowMs  → 윈도우 리셋: count=1, windowStart=now, allowed=true
- count < limit                  → count++, allowed=true
- count >= limit                 → allowed=false, resetAt=windowStart+windowMs
```

트랜잭션 내부 `tx.get` → `tx.set` 으로 동시성 안전. 윈도우 리셋 시점에는 정확히 1회 카운트되도록 처음부터 `count: 1` 로 set.

---

## 4. 운영 노트

- Firestore 기반 단점: 매 호출마다 트랜잭션 → 1 read + 1 write. 호출량이 크면 비용 부담.
- 향후 Memorystore Redis 이전 시 `allow(redis, bucket, key)` 의 첫 인자에 redis 클라이언트 주입.
- 서비스 외부 차단(IP 기반)은 Cloud Armor / App Check 한도에 위임. App Check는 모든 callable에 강제(`enforceAppCheck: true`)되어 있음.
- 사용량 대량 폭증 → CloudWatch/Stackdriver 알림 후 임시로 한도 하향 가능 (코드 변경 필요 — 향후 `config/{doc}` 동적화 검토).
