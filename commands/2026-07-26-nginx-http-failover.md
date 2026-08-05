# 2026-07-26 — Nginx 및 HTTP 장애 전환·복구 검증

## 목적

집에서 두 VM의 SSH 관리 경로를 확인하고, `vm-web02`의 Nginx 설치·실행 상태와 Load Balancer의 두 백엔드 트래픽 처리를 검증합니다. 이어서 `vm-web01`에 HTTP 403 장애를 발생시켜 장애 백엔드 제외와 파일 권한 복구 후 재포함을 확인합니다.

이 문서에는 실제 Load Balancer 공용 IP, 집 공용 IP, SSH 공개키·개인키, 지문 및 구독 ID를 기록하지 않습니다. 원본 전체 출력이 제공되지 않은 상태 확인은 실제로 관찰한 결과만 요약하며 명령 옵션을 임의로 재구성하지 않습니다.

## 실행 환경 또는 대상

| 구분 | 대상 |
| --- | --- |
| 관리 클라이언트 | 집 WSL |
| SSH 대상 | `vm-web01`, `vm-web02` |
| Nginx 설치 대상 | `vm-web02` |
| HTTP 장애 발생·복구 대상 | `vm-web01` |
| 외부 HTTP 경로 | Load Balancer 공용 TCP 80 |

## SSH 관리 경로 검증

- 집 WSL용 별도 ED25519 SSH 키를 생성했습니다.
- 기존 랩실 SSH 키를 제거하지 않고 두 VM에 집 공개키를 추가했습니다.
- 집 네트워크에서 다음 Inbound NAT Rule 경로의 SSH 접속을 확인했습니다.

| Frontend | Backend | 실제 결과 |
| --- | --- | --- |
| TCP 50001 | `vm-web01` TCP 22 | 접속 성공 |
| TCP 50002 | `vm-web02` TCP 22 | 접속 성공 |

SSH 명령의 실제 Load Balancer 공용 IP와 키 자료는 기록하지 않습니다.

## vm-web02 Nginx 설치 및 검증

`vm-web02`에서 실제로 실행한 설치·실행 명령입니다.

```bash
sudo dnf install -y nginx
sudo systemctl enable --now nginx
```

설정 검사는 `vm-web02`에서 다음 명령으로 수행했습니다.

```bash
sudo nginx -t
```

| 확인 항목 | 실제 결과 |
| --- | --- |
| Nginx 실행 상태 | `active` |
| Nginx 자동 시작 상태 | `enabled` |
| 수신 포트 | TCP 80 `LISTEN` |
| localhost HTTP 상태 | 200 |
| 응답 페이지 | `WEB02 - Zone 2` |
| Nginx 설정 검사 | `sudo nginx -t` 성공 |
| `firewalld` | `inactive` |

`sudo nginx -t` 성공은 `vm-web02`에서만 확인했습니다.

## 정상 상태의 Load Balancer 응답

Load Balancer 공용 TCP 80으로 반복 요청했을 때 WEB01과 WEB02 응답이 모두 나타나 두 백엔드가 트래픽을 처리하는 것을 확인했습니다.

응답 비율은 정확한 50:50이 아니었으며 이를 장애로 판단하지 않았습니다. 정확한 균등 분산을 검증한 결과로 기록하지 않습니다.

두 VM에서 `firewalld`가 모두 `inactive`인 것도 확인했습니다.

## vm-web01 HTTP 403 장애 발생

`vm-web01`에서 실제로 실행한 명령입니다.

```bash
sudo chmod 000 /usr/share/nginx/html/index.html
```

| 확인 항목 | 장애 상태의 실제 결과 |
| --- | --- |
| Nginx 실행 상태 | `active` |
| 수신 포트 | TCP 80 `LISTEN` |
| localhost HTTP 상태 | 403 |
| `firewalld` | `inactive` |

Nginx 프로세스와 TCP 80 수신은 유지됐지만 localhost HTTP가 403을 반환해 HTTP 계층 장애임을 확인했습니다.

## 외부 응답 기준 백엔드 제외

HTTP 403 발생 후 Load Balancer 공용 TCP 80 요청에서 WEB01 응답이 사라지고 WEB02만 계속 응답해, 외부 응답 기준으로 백엔드 제외 동작과 일치하는 결과를 확인했습니다.

감시 중간에 공백이 있어 장애 발생부터 WEB01 응답이 사라지기까지의 정확한 시간은 측정하지 못했습니다. Health Probe의 Portal 상태와 정확한 전환 시각은 확인하지 않았습니다.

## vm-web01 권한 복구 및 재포함

`vm-web01`에서 실제로 실행한 명령입니다.

```bash
sudo chmod 644 /usr/share/nginx/html/index.html
```

| 확인 항목 | 복구 후 실제 결과 |
| --- | --- |
| localhost HTTP 상태 | 200 |
| Load Balancer 외부 응답 | WEB01 재등장 |

파일 권한 복구 후 `vm-web01`의 localhost HTTP가 200으로 돌아왔고 Load Balancer 요청에 WEB01이 다시 나타나, 외부 응답 기준으로 백엔드 재포함 동작과 일치하는 결과를 확인했습니다.

## 검증 결과와 한계

- 집에서 두 Inbound NAT Rule을 통한 VM별 SSH 접속을 확인했습니다.
- `vm-web02`의 Nginx 설치, 실행·자동 시작, TCP 80 수신, 로컬 HTTP 응답 및 설정 검사를 확인했습니다.
- 정상 외부 요청에서 두 백엔드 응답을 모두 확인했습니다.
- `vm-web01`의 HTTP 403 발생과 복구 전후 외부 응답에서 백엔드 제외·재포함 동작과 일치하는 결과를 확인했습니다.
- 정확한 50:50 응답 비율, 장애 제외 소요 시간 및 실제 Availability Zone 장애 내성은 검증하지 않았습니다.

## 기록에서 제외한 값

- 실제 Load Balancer 공용 IP
- 실제 집 공용 IP
- SSH 공개키와 개인키
- SSH 키 및 Host Key 지문
- Subscription ID

## 관련 문서

- [2026-07-26 프로젝트 로그](../PROJECT_LOG.md#2026-07-26--집-ssh-재검증-nginx-구성-및-http-장애-전환복구-검증)
- [vm-web01 HTTP 403 장애 트러블슈팅 기록](../TROUBLESHOOTING.md#2026-07-26--vm-web01-http-403-장애-제외와-복구)
