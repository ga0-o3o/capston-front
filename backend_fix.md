# 백엔드 수정 가이드

## handleWordHighlight 메서드에서 제거할 부분

### ❌ 제거 1: 턴 주인 체크 (8-12번 라인)
```java
String currentTurn = room.getCurrentTurn();
if (loginId.equals(currentTurn)) {
    System.out.println("🟡 [" + roomId + "] 현재 턴 유저의 하이라이트는 무시됨: " + loginId);
    return;
}
```

### ❌ 제거 2: 응답 저장 (14번 라인)
```java
room.getHighlightResponses().put(loginId, wasHighlighted);
```

### ❌ 제거 3: n-1명 응답 모으고 next_turn 보내는 로직 (38-60번 라인)
```java
int totalPlayers = room.getTurnOrder().size();

if (room.getHighlightResponses().size() >= totalPlayers - 1) {
    System.out.println("✅ [" + roomId + "] 모든 유저 응답 완료 → 다음 턴으로 전환");

    String nextTurn = room.getNextUser(currentTurn);
    room.setCurrentTurn(nextTurn);

    Map<String, Object> nextData = new HashMap<>();
    nextData.put("prev_user", currentTurn);
    nextData.put("next_user", nextTurn);

    String nextTurnMessage = mapper.writeValueAsString(
            new MessageResponse("next_turn", nextData)
    );
    room.broadcast(nextTurnMessage);

    System.out.println("🔄 [" + roomId + "] 턴 전환 완료 → " + nextTurn);

    room.getHighlightResponses().clear();
}
```

---

## ✅ handleWordClick은 수정 안 함 (이미 완벽)

- 채점: `checkWordCorrect(word, wordKr)` ✅
- 결과 브로드캐스트: `next_turn` with `word_corr` ✅
- 턴 넘김: `nextUser` 계산 ✅

---

## 수정 후 동작

### word_hilight (파란 링)
1. 누구든 (턴 주인 포함) 제출 가능
2. 즉시 `highlight_result` 브로드캐스트
3. **턴 안 넘김**

### word_click (일반 단어)
1. 턴 주인만 제출
2. 채점 → `next_turn` 브로드캐스트 (word_corr 포함)
3. **턴 넘김**
