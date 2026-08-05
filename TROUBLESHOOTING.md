# 트러블슈팅 기록

실습 중 발생한 문제를 가설과 확인된 원인으로 구분하여 기록합니다. 가설은 검증 전까지 원인으로 단정하지 않으며, 실제로 실행한 명령과 그 출력만 남깁니다.

현재 다섯 건을 기록했습니다. 집 SSH 연결 문제는 후속 접속 경로를 확인했지만 최초 대기의 단일 원인은 확정하지 않았습니다. HTTP 403은 애플리케이션 계층 장애로 검증했고, 2026-07-27에는 랩실 NSG Source `/32` 불일치와 `firewalld` HTTP 차단을 각각 확인하고 복구했습니다. 2026-08-03에는 Check Mode가 선행 패키지를 실제로 설치하지 않아 후속 firewalld Task가 실패한 사례를 확인했습니다.

## 2026-07-23 — 집에서 vm-web01 SSH 연결 대기

### 증상

- 집에서 Load Balancer Frontend Port `50001`을 통해 `vm-web01`에 SSH로 접속했을 때 응답 없이 대기했다.

### 환경 차이

- 기존 `allow-ssh-myip` Rule은 DCT 랩실의 특정 단일 관리 Public IP만 TCP 22에 허용하고 있었다.
- SSH 접속 위치는 DCT 랩실에서 집으로 변경된 상태였다.
- 당시 NSG에는 Home Public IP를 허용하는 사용자 정의 Rule이 없었다.

### 가설

- [ ] 집의 원본 IP가 DCT 랩실 Public IP만 허용하는 `allow-ssh-myip`과 일치하지 않아 NSG Rule에 매칭되지 않았을 가능성이 가장 높다.

이 가설은 당시에는 집에서 재검증하지 않았고, 이후에는 NSG Rule과 공개키를 모두 변경한 뒤 접속을 확인했으므로 최초 대기의 단일 원인으로 확정할 수 없다. Azure 서비스 장애로도 단정하지 않는다.

### 확인 명령어와 출력

실제 숫자 Public IP를 Placeholder로 대체한 접속 형태는 다음과 같다.

```bash
ssh -p 50001 azureuser@<LOAD_BALANCER_PUBLIC_IP>
```

```text
응답 없이 대기함
```

별도의 Azure CLI 진단 출력은 제공되지 않았다. 당시 NSG Rule과 이후 추가된 Rule은 Azure Portal에서 확인했다.

### 원인

`미확인`. 접속 위치 변경에 따른 원본 IP 불일치가 가장 가능성 높은 가설이지만, 이후의 종합 재검증만으로는 최초 대기의 단일 원인을 분리해 입증할 수 없다.

### 해결

당시에는 Home의 특정 단일 Public IP만 TCP 22에 허용하는 `allow-ssh-home` Rule을 Priority `211`, `/32`, `Allow`로 추가하는 완화 조치를 적용했다. 이후 집 WSL용 별도 ED25519 SSH 키를 생성하고 기존 랩실 SSH 키를 제거하지 않은 채 두 VM에 집 공개키를 추가했다. 실제 Source IP와 키는 기록하지 않는다.

현재 집 SSH 접속 경로는 동작하지만, NSG Rule 추가와 공개키 추가 이후의 종합 재검증이므로 최초 연결 대기의 단일 원인이 무엇이었는지는 분리해 입증하지 못했다.

### 재검증

- 재검증 일시: `2026-07-26`
- 실행 내용: 집 네트워크에서 Load Balancer Inbound NAT Rule을 통해 두 VM에 SSH 접속
- 실제 결과: Frontend TCP 50001 → `vm-web01:22`, Frontend TCP 50002 → `vm-web02:22` 접속 성공
- 판정: 접속 경로 `해결`, 최초 대기의 단일 원인 `미확인`

### 증거

- [Inbound NAT Port Mappings](screenshots/05-inbound-nat-port-mappings.png)
- [여러 접속 위치를 위한 NSG Inbound Rules](screenshots/06-nsg-inbound-rules-multi-location.png)

05번 스크린샷은 Port Mapping, 06번 스크린샷은 `allow-ssh-home`이 추가된 NSG 구성을 보여 줍니다. 집에서의 후속 접속 결과는 [2026-07-26 프로젝트 로그](PROJECT_LOG.md#2026-07-26--집-ssh-재검증-nginx-구성-및-http-장애-전환복구-검증)에 기록했습니다.

### 후속 TODO

- [x] 집에서 Frontend Port `50001`을 통해 `vm-web01`에 다시 SSH 접속
- [x] 집에서 Frontend Port `50002`를 통해 `vm-web02`에 SSH 접속

---

## 2026-07-26 — vm-web01 HTTP 403 장애 제외와 복구

### 증상

- 정상 상태의 Load Balancer 공용 TCP 80 요청에서는 WEB01과 WEB02 응답이 모두 나타났다.
- 장애 시험을 위해 `vm-web01`의 `/usr/share/nginx/html/index.html` 권한을 의도적으로 `000`으로 변경했다.
- 변경 후에도 Nginx 프로세스는 `active`, TCP 80은 `LISTEN`을 유지했지만 localhost HTTP 상태는 403이었다.
- HTTP 403 발생 후 Load Balancer 외부 요청에서는 WEB01이 나타나지 않고 WEB02만 계속 응답했다.

정상 상태의 백엔드 응답 비율은 정확한 50:50이 아니었으며 이를 장애로 판단하지 않았다.

### 가설

- [x] 웹 문서 읽기 권한 제거로 Nginx가 `index.html`을 제공하지 못해 HTTP 403을 반환했다.
- [ ] Nginx 프로세스 중단 또는 TCP 80 미수신 문제
- [ ] `firewalld` 차단 문제

프로세스·포트·호스트 방화벽 상태와 권한 복구 결과를 비교해 첫 번째 가설을 원인으로 확인했다.

### 확인 명령어와 출력

장애를 발생시킬 때 실제로 실행한 명령은 다음과 같다.

```bash
sudo chmod 000 /usr/share/nginx/html/index.html
```

계층별 실제 확인 결과는 다음과 같다. 상태 확인에 사용한 전체 원문 명령은 제공되지 않아 임의로 재구성하지 않았다.

| 계층 | 대상 | 장애 상태의 실제 결과 | 판정 |
| --- | --- | --- | --- |
| 서비스 | `vm-web01` Nginx | `active` | 프로세스 중단 아님 |
| 전송 | `vm-web01` TCP 80 | `LISTEN` | 포트 미수신 아님 |
| HTTP | `vm-web01` localhost | HTTP 403 | HTTP 계층 장애 확인 |
| 호스트 방화벽 | 두 VM의 `firewalld` | 2026-07-26 당시 모두 `inactive` | `firewalld` 차단과 일치하지 않음 |
| 외부 요청 | Load Balancer 공용 TCP 80 | HTTP 403 발생 후 WEB02만 응답 | 백엔드 제외 동작과 일치 |

`sudo nginx -t` 성공은 `vm-web02`에서만 확인했으므로 `vm-web01`의 장애 원인 판정에 일반화하지 않는다.

### 원인

`vm-web01`의 `/usr/share/nginx/html/index.html` 권한을 `000`으로 변경해 Nginx가 응답 파일을 읽을 수 없게 된 것이 HTTP 403의 원인이었다. Nginx 프로세스와 TCP 80 수신은 계속 유지됐다.

### 해결

다음 명령으로 `index.html` 권한을 `644`로 복구했다.

```bash
sudo chmod 644 /usr/share/nginx/html/index.html
```

### 재검증

- 재검증 일시: `2026-07-26`
- 실행 내용: `vm-web01` localhost HTTP 상태와 Load Balancer 공용 TCP 80 응답 확인
- 실제 결과: localhost HTTP 200 복구, Load Balancer 응답에서 WEB01 재등장
- 판정: `해결`

HTTP 403 발생과 파일 권한 복구 전후 외부 응답에서 백엔드 제외·재포함 동작과 일치하는 결과를 확인했다. Health Probe의 Portal 상태와 정확한 전환 시각은 확인하지 않았으며, 감시 중간에 공백이 있어 WEB01 응답이 사라지기까지의 정확한 시간도 측정하지 못했다.

### 증거

- [Nginx 및 HTTP 장애 전환·복구 명령 기록](commands/2026-07-26-nginx-http-failover.md)
- [2026-07-26 프로젝트 로그](PROJECT_LOG.md#2026-07-26--집-ssh-재검증-nginx-구성-및-http-장애-전환복구-검증)

### 후속 TODO

- [ ] 연속 요청과 시각 기록을 사용해 장애 발생부터 외부 응답에서 WEB01이 사라지기까지의 시간을 별도 측정

---

## 2026-07-27 — 랩실 NSG Source /32 불일치로 인한 SSH timeout

### 증상

- 이전에 접속했던 것과 같은 랩실 Wi-Fi에서 Load Balancer Frontend TCP 50001을 통해 `vm-web01`로 SSH 접속했을 때 timeout 됐다.
- SSH post-quantum 관련 경고가 표시됐지만, NSG 수정 후 동일 접속 경로의 로그인은 성공했다.

### 환경 차이

- `allow-ssh-myip`에는 이전에 확인한 랩실 공용 IP 한 개가 Source `/32`로 등록돼 있었다.
- 장애 시점에 다시 확인한 랩실의 현재 공용 IPv4는 기존 Source `/32`와 달랐다.
- 같은 Wi-Fi를 사용하더라도 공용 IP가 항상 유지된다고 볼 수 없다.

### 가설

- [x] 현재 랩실 원본 IP가 기존 `allow-ssh-myip` Source `/32`와 일치하지 않아 NSG 허용 규칙에 매칭되지 않았다.
- [ ] SSH post-quantum 경고가 접속을 차단했다.

현재 공용 IPv4와 NSG Source의 불일치를 직접 확인했고, Source 갱신 후 SSH 로그인에 성공해 첫 번째 가설을 확인했다. 경고가 표시된 상태에서도 로그인했으므로 post-quantum 경고는 timeout의 원인이 아니었다.

### 확인 명령어와 출력

실제 Load Balancer 및 랩실 공용 IP는 기록하지 않았다. 공개용 SSH 접속 형태는 다음과 같다.

```bash
ssh -p 50001 azureuser@<LOAD_BALANCER_PUBLIC_IP>
```

| 단계 | 실제 결과 |
| --- | --- |
| NSG 갱신 전 | Frontend TCP 50001 SSH timeout |
| 현재 랩실 공용 IPv4 확인 | 기존 `allow-ssh-myip` Source `/32`와 불일치 |
| NSG 갱신 후 | Frontend TCP 50001을 통해 `vm-web01` 로그인 성공 |

### 원인

랩실의 현재 공용 IPv4가 `allow-ssh-myip`에 등록돼 있던 기존 Source `/32`와 달라 NSG 허용 규칙에 매칭되지 않은 것이 원인이었다.

### 해결

`nsg-linux-web`의 `allow-ssh-myip` Source를 현재 랩실 공용 IP 한 개의 `/32`로 수정했다. 실제 주소는 기록하지 않았다.

### 재검증

- 재검증 일시: `2026-07-27`
- 실행 내용: Load Balancer Frontend TCP 50001을 통한 `vm-web01` SSH 접속
- 실제 결과: SSH 로그인 성공
- 판정: `해결`

### 증거

- [2026-07-27 프로젝트 로그](PROJECT_LOG.md#2026-07-27--랩실-nsg-source-갱신-및-firewalld-http-장애복구-검증)
- [firewalld HTTP 장애·복구 명령 기록의 SSH 접근 부분](commands/2026-07-27-firewalld-http-failover.md)

### 후속 TODO

- [ ] 관리 위치에서 SSH timeout이 발생하면 현재 원본 IP와 NSG Source `/32`를 먼저 비교하는 점검 절차를 Runbook에 반영

---

## 2026-07-27 — vm-web01 firewalld HTTP 차단과 복구

### 증상

- `vm-web01`의 `firewalld` public Zone에 `http` 서비스와 `80/tcp` 허용이 없는 상태에서 Load Balancer 공용 TCP 80을 반복 요청하자 WEB02만 계속 응답했다.
- 같은 시점의 `vm-web01`에서는 Nginx가 `active`·`enabled`, TCP 80이 `LISTEN`, localhost HTTP 상태가 200이었다.

### 환경과 사전 설정

- 처음에는 `firewall-offline-cmd` 명령이 존재하지 않았다.
- `rpm -q firewalld || sudo dnf install -y firewalld` 실행으로 패키지를 설치한 뒤 `firewall-offline-cmd`를 포함한 `firewalld` 명령을 사용할 수 있게 됐다.
- NetworkManager에서는 `System eth0` 연결 프로필에만 `connection.zone=public`을 명시적으로 설정했다.
- 활성화 전 public Zone에는 `cockpit`, `dhcpv6-client`, `ssh` 서비스가 있었고, `http` 서비스와 `80/tcp` 허용은 없었다.
- SSH 허용을 확인한 뒤 `firewalld`를 활성화했으며 서비스 상태는 `active`·`enabled`였다.

firewalld 관련 출력은 다음과 같이 서로 다른 범위에서 확인했다.

| 확인 명령 또는 범위 | 실제 결과 |
| --- | --- |
| `sudo nmcli connection modify "System eth0" connection.zone public` | `System eth0`에 `connection.zone=public` 설정 |
| `nmcli -g connection.zone connection show "System eth0"` | `public` |
| `sudo firewall-cmd --get-active-zones` | public Zone에 `eth0`, `eth1` 표시 |
| `sudo firewall-cmd --zone=public --list-all` | `interfaces` 항목에 `eth0` 표시 |

이 결과를 `eth1`에도 NetworkManager의 `connection.zone`을 직접 설정했다는 뜻으로 해석하지 않는다.

### 가설

- [x] public Zone에서 HTTP를 허용하지 않아 호스트 방화벽이 `vm-web01`의 외부 HTTP 접근을 차단했다.
- [ ] Nginx 프로세스가 중지됐다.
- [ ] TCP 80이 수신되지 않았다.
- [ ] Nginx 로컬 HTTP 서비스가 실패했다.

### 확인 명령어와 출력

계층별 관찰 결과는 다음과 같다.

| 계층 | 확인 항목 | 차단 상태의 실제 결과 | 판정 |
| --- | --- | --- | --- |
| 서비스 | Nginx | `active`, `enabled` | 프로세스·자동 시작 정상 |
| 전송 | TCP 80 | `LISTEN` | 포트 수신 정상 |
| 애플리케이션 | localhost HTTP | 200 | 로컬 HTTP 정상 |
| 호스트 방화벽 | public Zone | `http` 및 `80/tcp` 허용 없음 | 외부 HTTP 차단 상태 |
| 외부 요청 | Load Balancer 공용 TCP 80 | WEB02만 계속 응답 | WEB01 제외 동작과 일치 |

`vm-web01`의 `sudo nginx -t` 결과는 이번 검증에서 확인하지 않았다.

### 원인

`vm-web01`의 Nginx 프로세스, TCP 80 수신 및 로컬 HTTP 서비스는 정상이었지만, 활성화한 `firewalld`의 public Zone에서 HTTP를 허용하지 않아 외부 HTTP 접근이 차단됐다.

외부 반복 요청에서 WEB02만 응답한 결과는 Health Probe가 WEB01에 접근하지 못해 WEB01이 트래픽 대상에서 제외된 동작과 일치한다. Azure Portal의 정확한 `Healthy/Unhealthy` 표시와 정확한 제외 시각은 확인하지 않았다.

### 해결

현재 실행 중인 방화벽에서 HTTP를 즉시 복구하기 위해 public Zone의 runtime 설정에 HTTP 서비스를 추가했다. firewalld 재시작 또는 VM 재부팅 후에도 HTTP 허용을 유지하기 위해 permanent 설정에도 추가했다.

```bash
sudo firewall-cmd --zone=public --add-service=http
sudo firewall-cmd --zone=public --add-service=http --permanent
```

두 범위에서 `query-service=http` 결과가 모두 `yes`인 것을 확인했다.

### 재검증

- 재검증 일시: `2026-07-27`
- 실행 내용: localhost HTTP 상태와 Load Balancer 외부 반복 요청 확인
- 실제 결과: localhost HTTP 200, 외부 응답에서 WEB01과 WEB02 재등장
- 판정: `해결`

WEB01의 재등장은 방화벽 복구 후 트래픽 대상에 다시 포함된 동작과 일치한다. 정확한 50:50 분산과 Azure Portal의 Health Probe 상태, 정확한 재포함 시각은 확인하지 않았다.

작업 중 별도 보조 시험으로 `vm-web01`의 Nginx를 잠시 중지했다가 복구했을 때 일시적인 `REQUEST_FAILED`, WEB02 전환 및 WEB01 복귀를 관찰했다. 이 시험은 원인과 계층이 다른 보조 관찰이며, 이번 기록의 주 장애 사례는 `firewalld` HTTP 차단이다.

### 증거

- [로컬 서비스 정상 및 firewalld HTTP 미허용](screenshots/07-firewalld-block-local-service-healthy.png)
- [firewalld 차단 중 WEB02만 응답](screenshots/08-firewalld-web01-excluded.png)
- [HTTP 허용 후 WEB01 재등장](screenshots/09-firewalld-web01-reincluded.png)
- [firewalld HTTP 장애·복구 명령 기록](commands/2026-07-27-firewalld-http-failover.md)
- [2026-07-27 프로젝트 로그](PROJECT_LOG.md#2026-07-27--랩실-nsg-source-갱신-및-firewalld-http-장애복구-검증)

### 후속 TODO

- [ ] Azure Portal의 Health Probe 표시와 외부 응답 변화를 같은 시간축으로 기록

---

## 2026-08-03 — Ansible Check Mode에서 python3-firewall 미설치로 인한 firewalld Task 실패

### 증상

- `vm-web02`에 `web-config.yml`을 Check Mode로 실행했을 때 필수 패키지 Task는 변경 예정으로 표시됐지만, 다음 permanent firewalld 서비스 Task에서 실패했다.
- 최종 결과는 `ok=3`, `changed=1`, `unreachable=0`, `failed=1`, 종료 코드 2였다.
- 관리 대상에는 도달했으므로 Inventory나 SSH 연결 실패와는 다른 문제였다.

### 가설

- [x] Check Mode에서 `python3-firewall` 설치가 예측만 되고 실제로 수행되지 않아, 후속 `ansible.posix.firewalld` Task가 필요한 Python firewall binding을 불러오지 못했다.
- [ ] Inventory 또는 SSH 관리 경로 문제
- [ ] firewalld 서비스 자체의 실행 실패

`unreachable=0`인 상태에서 패키지 Task 다음의 모듈 의존성 import가 실패했고, 실제 적용 후 같은 Playbook이 완료된 결과로 첫 번째 가설을 확인했다.

### 확인 명령어와 출력

`ansible/` 디렉터리에서 실제로 실행한 Check Mode 명령은 다음과 같다.

```bash
ansible-playbook --check --diff --limit vm-web02 playbooks/web-config.yml
```

```text
vm-web02 : ok=3 changed=1 unreachable=0 failed=1
Ansible exit code: 2
```

Check Mode의 필수 패키지 Task에는 `python3-firewall` 설치가 변경 예정으로 표시됐다. 다음 permanent firewalld 서비스 Task는 Python firewall binding을 import하지 못해 실패했다.

### 원인

Check Mode는 선행 패키지 설치 Task의 변경을 예측했지만 패키지를 실제로 설치하지 않았다. 같은 실행에서 이어진 `ansible.posix.firewalld` Task는 아직 없는 Python firewall binding에 의존했기 때문에 실패했다.

### 해결

Check Mode 결과와 실패 지점을 확인한 뒤 `vm-web02`에 실제 적용을 실행했다.

### 실제 적용 결과

```bash
ansible-playbook --diff --limit vm-web02 playbooks/web-config.yml
```

```text
vm-web02 : ok=13 changed=5 unreachable=0 failed=0
```

실제 적용에서는 필수 패키지가 설치돼 후속 firewalld Task를 실행할 수 있었다. Nginx 설정 검사, localhost HTTP 200과 서버별 응답 본문 검증도 성공했다.

### 재검증

- 재검증 일시: `2026-08-04`
- 실행 내용: 같은 구성 Playbook을 `vm-web02`에 다시 적용
- 실제 결과: `ok=13`, `changed=0`, `unreachable=0`, `failed=0`, 종료 코드 0
- 판정: 실제 적용과 멱등성 `확인`, 의존 패키지가 없는 초기 상태의 Check Mode 한계 `기록`

### 교훈

- Check Mode는 변경을 예측하지만 선행 패키지를 실제로 설치하지 않으므로, 같은 실행의 후속 Task가 그 패키지에 의존하면 전체 흐름이 실패할 수 있다.
- `failed=1`, `unreachable=0`은 관리 대상에 도달한 뒤 Task 실행 중 실패한 결과다. Inventory나 SSH 경로에 도달하지 못한 `unreachable=1`과 구분해야 한다.
- Check Mode 실패를 실제 적용 실패로 일반화하지 않고, 실패 지점을 확인한 뒤 실제 적용과 재실행 결과를 별도로 검증한다.

### 증거

- [`vm-web02` 구성 적용 및 멱등성 검증](commands/2026-08-04-ansible-web-config-vm-web02.md)
- [구성 Playbook](ansible/playbooks/web-config.yml)
- [2026-08-04 프로젝트 로그](PROJECT_LOG.md#2026-08-04--두-vm-ansible-멱등성-및-vm-web02-nginx-drift-복구-검증)

### 후속 TODO

- [ ] 의존 패키지가 없는 초기 상태에서도 Check Mode 전체 흐름을 검증해야 한다면 Task 분리 또는 Check Mode 처리 방식을 별도로 설계

---

## YYYY-MM-DD — 문제 제목

### 증상

- 관찰한 현상을 그대로 기록한다.
- 발생 시점, 영향 범위와 재현 조건을 함께 적는다.

### 가설

- [ ] 가능한 원인 1
- [ ] 가능한 원인 2

검증되지 않은 내용에는 반드시 `가설` 또는 `미확인`이라고 표시한다.

### 확인 명령어와 출력

실제로 실행한 명령만 기록한다. 구독 ID(Subscription ID), 비밀번호, 토큰(Token), 개인 키(Private Key) 등의 민감정보는 제거한다.

실제 숫자 Public IP 주소는 변경 가능하며 공개 저장소에 기록할 필요가 없는 운영 정보이므로 기록하지 않는다.

```bash
# 실제 실행한 확인 명령어
```

```text
# 공개할 필요가 없는 운영 정보와 민감정보를 제거한 실제 명령 출력
```

### 원인

검증으로 확인된 원인만 기록한다. 확인되지 않았다면 `미확인`으로 남긴다.

### 해결

실제로 적용한 변경과 적용 결과를 기록한다. 아직 적용하지 않았다면 `미적용`으로 남긴다.

### 재검증

- 재검증 일시:
- 실행 명령:
- 실제 결과:
- 판정: `해결 / 미해결 / 부분 해결 / 미검증`

### 증거

- 관련 스크린샷 또는 명령 로그 경로:

### 후속 TODO

- [ ] 재발 방지 또는 추가 검증 작업
