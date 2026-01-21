# CLAUDE.md

이 파일은 Claude Code (claude.ai/code)가 이 저장소의 코드를 다룰 때 참고할 수 있는 가이드를 제공합니다.

## 프로젝트 개요

Picoquic은 QUIC 프로토콜(RFC 9000)의 미니멀리스트 C 구현체입니다. 다음을 포함합니다:
- QUIC v1, v2, 멀티패스, 데이터그램 및 기타 확장을 지원하는 핵심 QUIC 라이브러리
- WebTransport를 지원하는 HTTP/3 구현체 (picohttp)
- 데모 애플리케이션 및 테스트 스위트

## 빌드 명령어

### Linux/macOS (CMake)
```bash
# picotls 자동 다운로드로 빌드 (권장)
cmake -S . -B build -DPICOQUIC_FETCH_PTLS=Y
cmake --build build

# 또는 picotls가 이미 같은 디렉토리 레벨에 설치되어 있는 경우 별도로 빌드
cmake -S . -B build
cmake --build build
```

### Windows (Visual Studio)
Visual Studio 2017 이상에서 `picoquic.sln`을 엽니다. 요구 사항:
- `OPENSSLDIR`/`OPENSSL64DIR` 환경 변수가 설정된 상태로 OpenSSL 설치
- picoquic과 같은 디렉토리 레벨에 Picotls 클론

### CMake 옵션
- `-DPICOQUIC_FETCH_PTLS=Y` - picotls 자동 다운로드 및 빌드
- `-DWITH_OPENSSL=OFF` - OpenSSL 없이 빌드 (minicrypto만 사용)
- `-DWITH_MBEDTLS=ON` - MbedTLS 지원 활성화
- `-DENABLE_ASAN=ON` - AddressSanitizer 활성화
- `-DENABLE_UBSAN=ON` - UndefinedBehaviorSanitizer 활성화

## 테스트 실행

```bash
# 모든 QUIC 테스트 실행 (build 디렉토리에서)
./picoquic_ct -S <source_dir> -n -r

# 모든 HTTP 테스트 실행
./picohttp_ct -S <source_dir> -n -r

# 이름으로 특정 테스트 실행
./picoquic_ct <test_name>
./picoquic_ct tls_api
./picoquic_ct multipath_basic

# 테스트 제외
./picoquic_ct -x <test_name>

# 디버그 출력과 함께 테스트 실행
./picoquic_ct <test_name>    # -n 플래그 없이
```

테스트 러너 옵션:
- `-n` - 디버그 출력 비활성화
- `-r` - 실패한 테스트를 디버그 출력 활성화 상태로 재시도
- `-x <test>` - 지정된 테스트 제외
- `-S <dir>` - 테스트 참조 파일을 찾기 위한 소스 파일 경로 설정

## 코드 아키텍처

### 디렉토리 구조
- `picoquic/` - 핵심 QUIC 라이브러리 (단일 스레드, 가상 시간 사용)
- `picohttp/` - HTTP/3, WebTransport 및 데모 클라이언트/서버 구현
- `loglib/` - 로깅 유틸리티 (qlog, 바이너리 로그, CSV 변환)
- `picoquictest/` - 모든 테스트 구현이 포함된 테스트 라이브러리
- `picoquic_t/` - picoquic 테스트용 CLI 테스트 러너
- `picohttp_t/` - HTTP 테스트용 CLI 테스트 러너
- `picoquicfirst/` - picoquicdemo 애플리케이션
- `sample/` - 간단한 클라이언트/서버 예제 코드

### 주요 소스 파일
- `picoquic/picoquic.h` - 공개 API (안정적)
- `picoquic/picoquic_internal.h` - 내부 구조체 (릴리스 간 변경될 수 있음)
- `picoquic/quicctx.c` - QUIC 컨텍스트 및 연결 관리
- `picoquic/sender.c` - 패킷 전송 로직
- `picoquic/frames.c` - 프레임 인코딩/디코딩
- `picoquic/tls_api.c` - picotls를 통한 TLS 1.3 통합
- `picoquic/sockloop.c` - 기본 소켓 루프 구현

### 혼잡 제어 알고리즘
`picoquic/`에 위치:
- `newreno.c` - NewReno (기본값)
- `cubic.c` - Cubic
- `bbr.c` - BBRv3
- `bbr1.c` - BBRv1
- `fastcc.c` - FastCC
- `prague.c` - Prague (L4S)
- `c4.c` - C4 알고리즘

### 설계 원칙
- **단일 스레드**: 라이브러리는 스레드 안전하지 않음; 병렬 처리를 위해 별도의 QUIC 컨텍스트 사용
- **가상 시간**: 모든 API 호출은 현재 시간을 매개변수로 받음; 네트워크 시뮬레이터를 통한 결정론적 테스트 가능
- **콜백 기반**: 애플리케이션은 연결 상태, 스트림, 데이터그램에 대한 이벤트를 콜백으로 수신
- **picotls를 통한 TLS**: OpenSSL(또는 선택적으로 mbedtls/minicrypto)이 필요한 picotls 라이브러리 사용

## 데모 애플리케이션

```bash
# 서버
./picoquicdemo -p 4433 -c cert.pem -k key.pem -w /path/to/www

# 클라이언트
./picoquicdemo -o /output/dir server.example.com 4433 /path/to/file

# QLOG 출력 활성화
./picoquicdemo -q /log/folder ...
```

## 코드 스타일

WebKit 스타일 사용 (CMakeLists.txt에 설정됨). 다음으로 포맷팅:
```bash
cmake --build build --target clangformat
```
