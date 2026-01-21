# x86_64-windows-gnu 링크 오류 상세 분석

## 오류 메시지 분석

```
error: lld-link: duplicate symbol: IN6_ADDR_EQUAL
    note: defined at ws2ipdef.h:244
    note:            picoquic-core.lib(tls_api.obj)
    note: defined at picoquic-core.lib(picoquic_ptls_minicrypto.obj)
```

`IN6_ADDR_EQUAL`, `IN6_IS_ADDR_UNSPECIFIED` 등의 함수들이 **여러 object 파일에 중복 정의**되어 링커가 실패했습니다.

---

## 근본 원인

### 1. Zig의 MinGW libc 헤더 문제

Zig는 크로스 컴파일을 위해 자체 번들된 MinGW libc 헤더를 사용합니다. 해당 헤더 파일을 보면:

```c
// C:\Users\gegogi\.zvm\0.15.2\lib\libc\include\any-windows-any\WS2tcpip.h

// 이 함수들이 inline이 아닌 일반 함수로 정의되어 있음
int IN6_ADDR_EQUAL(const struct in6_addr *a, const struct in6_addr *b) { ... }
int IN6_IS_ADDR_UNSPECIFIED(const struct in6_addr *a) { ... }
// ... 등등
```

### 2. C 언어의 함수 정의 규칙

| 선언 방식 | 동작 |
|-----------|------|
| `static inline` | 각 translation unit에 **private 복사본** 생성 → 중복 없음 |
| `inline` | 외부 링크 가능, 컴파일러 의존적 |
| 일반 함수 | **각 .c 파일마다 심볼 생성** → 중복 발생 |

Zig의 MinGW 헤더에서는 이 IPv6 헬퍼 함수들이 `static inline`이 아닌 **일반 함수로 정의**되어 있습니다.

### 3. 컴파일 과정에서 발생하는 문제

```
tls_api.c
    └─ #include <WS2tcpip.h>
        └─ IN6_ADDR_EQUAL() 함수 정의 포함
        └─ 컴파일 → tls_api.obj (IN6_ADDR_EQUAL 심볼 포함)

picoquic_ptls_minicrypto.c
    └─ #include <WS2tcpip.h>
        └─ IN6_ADDR_EQUAL() 함수 정의 포함
        └─ 컴파일 → picoquic_ptls_minicrypto.obj (IN6_ADDR_EQUAL 심볼 포함)

링커 단계:
    tls_api.obj + picoquic_ptls_minicrypto.obj
        └─ IN6_ADDR_EQUAL이 두 번 정의됨!
        └─ "duplicate symbol" 에러
```

---

## 왜 네이티브 MinGW에서는 작동하는가?

네이티브 MinGW-w64의 헤더에서는 이 함수들이 다르게 정의되어 있습니다:

```c
// 네이티브 MinGW-w64 헤더 (예시)
#define IN6_ADDR_EQUAL(a, b) \
    (memcmp((a), (b), sizeof(struct in6_addr)) == 0)

// 또는
static __inline__ int IN6_ADDR_EQUAL(...) { ... }
```

- **매크로**: 전처리 단계에서 치환되어 심볼이 생성되지 않음
- **static inline**: 각 파일에 private 복사본만 생성되어 외부 링크 충돌 없음

---

## 해결 방법들

### 1. 링커 옵션으로 중복 허용 (위험)
```zig
// build.zig에서
exe.addLinkerOption("/FORCE:MULTIPLE");  // 중복 심볼 무시
```
⚠️ 예측 불가능한 동작 가능성. 또한 Zig 0.15.x 빌드 시스템에서 직접 링커 옵션을 전달하는 API가 제한적임.

### 2. Zig 헤더 패치
`~/.zvm/0.15.2/lib/libc/include/any-windows-any/WS2tcpip.h` 수정:
```c
// 변경 전
int IN6_ADDR_EQUAL(...) { ... }

// 변경 후
static inline int IN6_ADDR_EQUAL(...) { ... }
```
⚠️ Zig 업데이트 시 수정 내용이 사라짐

### 3. 프로젝트 내 수정된 헤더 사용 ✅ (채택)
Zig의 헤더 파일을 프로젝트에 복사하고 수정한 후, include 경로 우선순위를 조정하여 시스템 헤더보다 먼저 검색되도록 함.

### 4. 네이티브 빌드 환경 사용
Windows 타겟은 기존 CMake + MSVC 또는 네이티브 MinGW-w64 사용

---

## 적용된 해결책: 프로젝트 내 수정된 헤더 (방법 3)

### 구현 내용

1. **디렉토리 생성**: `picoquic/zig_compat/`

2. **수정된 헤더 파일 배치**:
   - `picoquic/zig_compat/ws2ipdef.h` - Zig의 헤더 복사 후 수정
   - `picoquic/zig_compat/WS2tcpip.h` - Zig의 헤더 복사 후 수정

3. **ws2ipdef.h 수정 내용**:
```c
// 변경 전 (Zig 원본)
#define WS2TCPIP_INLINE __CRT_INLINE

int IN6_ADDR_EQUAL(const struct in6_addr *,const struct in6_addr *);
WS2TCPIP_INLINE int IN6_ADDR_EQUAL(const struct in6_addr *a, const struct in6_addr *b) {
    return !memcmp(a, b, sizeof(struct in6_addr));
}

// 변경 후
#define WS2TCPIP_INLINE static inline

static inline int IN6_ADDR_EQUAL(const struct in6_addr *a, const struct in6_addr *b) {
    return !memcmp(a, b, sizeof(struct in6_addr));
}
```

4. **WS2tcpip.h 수정 내용**:
   - Forward declaration 제거 (static inline 함수는 forward declaration 불필요)
   - 모든 `WS2TCPIP_INLINE`을 `static inline`으로 변경

```c
// 변경 전 (Zig 원본)
int IN6_IS_ADDR_UNSPECIFIED(const struct in6_addr *);
int IN6_IS_ADDR_LOOPBACK(const struct in6_addr *);
// ... 18개의 forward declaration ...

WS2TCPIP_INLINE int IN6_IS_ADDR_UNSPECIFIED(const struct in6_addr *a) { ... }

// 변경 후
/* Forward declarations removed for Zig cross-compilation compatibility */

static inline int IN6_IS_ADDR_UNSPECIFIED(const struct in6_addr *a) { ... }
```

5. **build.zig 수정**:
   Windows 타겟에서 `zig_compat` 디렉토리를 **첫 번째 include 경로**로 추가:

```zig
// 각 모듈에 대해:
if (is_windows) {
    module.addIncludePath(b.path("picoquic/zig_compat"));
}
module.addIncludePath(b.path("picoquic"));
// ... 나머지 include 경로들
```

### 작동 원리

```
컴파일 시 헤더 검색 순서:
1. picoquic/zig_compat/WS2tcpip.h  ← 우리의 수정된 헤더 (static inline)
2. picoquic/
3. ... (기타 경로)
4. Zig 시스템 헤더  ← 원본 헤더 (사용되지 않음)

결과:
- 모든 IPv6 헬퍼 함수가 static inline으로 컴파일됨
- 각 translation unit에 private 복사본만 생성
- 외부 링크 심볼이 생성되지 않음
- duplicate symbol 에러 없음!
```

### 빌드 결과

```bash
# Windows 크로스 컴파일 성공
$ zig build -Dtarget=x86_64-windows-gnu

# 생성된 파일
zig-out/bin/picoquicdemo.exe
zig-out/bin/picolog_t.exe
zig-out/bin/picoquic_sample.exe
zig-out/lib/picoquic-core.lib
zig-out/lib/picoquic-log.lib
zig-out/lib/picohttp-core.lib
```

---

## 결론

| 항목 | 설명 |
|------|------|
| **원인** | Zig 번들 MinGW 헤더의 IPv6 함수들이 `static inline`이 아님 |
| **영향** | 여러 소스 파일에서 같은 심볼이 중복 생성 |
| **범위** | Zig의 Windows 크로스 컴파일 환경 특유의 문제 |
| **Linux 빌드** | 영향 없음 (POSIX 헤더는 다른 방식으로 정의) |
| **해결 상태** | ✅ 프로젝트 내 수정된 헤더로 해결됨 |

이 문제는 picoquic 코드의 문제가 아니라 **Zig 빌드 시스템의 Windows libc 구현 제한사항**이었으나, 프로젝트 내에 수정된 헤더 파일을 배치하고 include 경로 우선순위를 조정하여 해결하였습니다.
