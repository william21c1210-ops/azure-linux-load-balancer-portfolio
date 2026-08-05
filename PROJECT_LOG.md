# 프로젝트 로그

날짜별로 **실제로 수행한 작업**과 검증 결과를 기록합니다. Azure 리소스 생성일이 불명확하면 추측하지 않고 `미확인`으로 남깁니다. 새 기록은 기존 기록을 덮어쓰지 않고 날짜별 섹션으로 추가합니다.

## 2026-07-21 — 현재 상태 문서화

### 목표

당시 확인해 둔 Azure 설정과 기존 증거를 기준으로 저장소의 최초 문서 구조와 현재 진행 상태를 기록한다.

### 실제 작업 내용

- 현재까지 확인된 Azure Load Balancer 관련 리소스와 설정을 문서화했다.
- 현재 구성과 최종 목표 구성을 분리했다.
- 미완료 작업을 TODO 체크박스로 정리했다.
- 이 기록에서 Azure 리소스를 새로 생성하거나 변경하지 않았다.

### 설정 이유

기존 Azure 리소스별 선택 이유는 당시 기록만으로는 확인할 수 없다. 실제 선택 이유가 확인되면 이후 기록에 추가한다.

### 실행한 명령어와 출력

Azure 상태를 조회하는 명령은 실행하지 않았다. 기존 증거 파일이 변경되지 않았는지 확인하기 위해 다음 명령을 실행했다.

```bash
sha256sum screenshots/01-load-balancer-overview.png
```

```text
f4964f2d034bb3f9e55a43b399621549fc7a1d1d91ba622f1834f15e1aeec4c8  screenshots/01-load-balancer-overview.png
```

### 검증 결과

- 기존 PNG 파일의 SHA-256 체크섬(Checksum)을 확인했다.
- Azure Portal의 Frontend IP Configuration 연결 상태는 이 기록에서 재검증하지 않았다.
- VM, Rocky Linux, Nginx, 부하 분산 및 장애 복구 동작은 아직 검증하지 않았다.

### 증거 파일

- [screenshots/01-load-balancer-overview.png](screenshots/01-load-balancer-overview.png)

### 문제점 또는 미확인 사항

- `fe-ip-linux-web`과 `pip-linux-web`의 실제 연결 상태는 당시 미확인이었으며, 아래 후속 기록에서 확인함
- VM, NIC, Network Security Group 및 SSH Port Mapping은 이 기록 당시 미정이었으며 후속 기록에서 확인했다.

### 다음 TODO

- [x] Azure Portal에서 Frontend IP Configuration과 Public IP 연결 상태 재검증
- [x] VM 두 대 생성, Availability Zone 분산 배치 및 Backend Pool 등록
- [x] 두 VM의 SSH 접속 및 Rocky Linux 버전 확인
- [x] `vm-web01`의 VM Size 확인
- [x] `vm-web02`의 VM Size와 두 VM의 Azure NIC 리소스 이름 확인 (2026-08-04 Azure Portal 후속 확인)

---

## 2026-07-21 — Frontend IP 연결 검증

### 목표

Azure Portal에서 Frontend IP Configuration과 Public IP 리소스의 실제 연결 상태 및 정확한 리소스 이름을 확인한다.

### 실제 작업 내용

- Frontend IP Configuration `fe-ip-linux-web`의 설정 화면을 확인했다.
- 연결된 Public IP 리소스 이름이 `pip-linux-web`임을 확인했다.
- `fe-ip-linux-web`이 `pip-linux-web`에 연결되어 있음을 확인했다.
- 실제 숫자 Public IP 주소는 기록하지 않았다.

### 설정을 선택한 이유

Frontend 연결 상태가 이전 문서에서 TODO였고 Public IP 리소스 이름도 잘못 기록되어 있어, Backend 구성 전에 Azure Portal의 실제 값을 기준으로 바로잡기 위해 검증했다. Public IP 구성을 처음 선택한 이유는 당시 기록만으로는 확인할 수 없다.

### 예상 결과

검증 전에 별도로 기록한 예상 결과는 없다. 실제 결과에 맞춰 사후에 예상값을 추측하지 않는다.

### 실행한 명령어와 출력

이 기록에는 Azure CLI 또는 Shell 명령이 남아 있지 않다. Azure Portal 화면을 사용해 검증했다.

### 실제 결과

- Frontend IP Configuration: `fe-ip-linux-web`
- 연결된 Public IP 리소스: `pip-linux-web`
- 연결 상태: Azure Portal에서 연결 확인
- 실제 숫자 Public IP 주소: 저장소에 기록하지 않음

### 증거

- [screenshots/02-frontend-ip-configuration.png](screenshots/02-frontend-ip-configuration.png)

### 핵심 요약

> Azure Portal에서 Frontend IP Configuration `fe-ip-linux-web`이 Public IP 리소스 `pip-linux-web`에 연결된 것을 직접 확인하고, 실제 주소를 제외한 검증 증거를 저장소에 남겼습니다.

### 문제점 또는 미확인 사항

- Public IP 구성을 처음 선택한 이유는 미확인이다.
- 이 기록 당시 VM, Nginx, Backend Pool 등록, Health Probe 결과, 부하 분산 및 장애 복구 시험은 미완료였다.

### 다음 TODO

- [x] VM 두 대 생성, Availability Zone 분산 배치 및 Backend Pool 등록
- [x] 두 VM의 SSH 접속 및 Rocky Linux 버전 확인
- [x] `vm-web01`의 VM Size 확인
- [x] `vm-web02`의 VM Size와 두 VM의 Azure NIC 리소스 이름 확인 (2026-08-04 Azure Portal 후속 확인)
- [x] Nginx, Health Probe, 부하 분산 및 장애 복구 검증 (2026-07-26~2026-08-04 후속 작업)

---

## 2026-07-22 — NSG 및 Backend Pool 두 VM 구성 확인

### 목표

Private Subnet의 NSG 연결과 Inbound Rule을 확인하고, VM 두 대의 배치 상태와 Backend Pool 등록 여부를 실제 Azure Portal 증거를 기준으로 기록한다.

### 실제 작업

- Network Security Group `nsg-linux-web`이 Private Subnet `snet-web`에 연결된 것을 확인했다.
- `allow-http-80`, `allow-ssh-myip`, `AllowAzureLoadBalancerInBound` 및 `DenyAllInBound`의 존재와 설정을 확인했다.
- `vm-web01`과 `vm-web02`가 Running 상태이며 개별 Public IP가 없음을 확인했다.
- `vm-web01`은 Availability Zone 1과 Private IP `10.10.1.4`, `vm-web02`는 Availability Zone 2와 Private IP `10.10.1.5`를 사용하는 것을 확인했다.
- 두 VM이 Backend Pool `be-pool-linux-web`에 등록된 것을 확인했다.

### 설정을 선택한 이유

- VM에 개별 Public IP를 부여하지 않고 Private Subnet에 배치했다.
- SSH는 Internet 전체가 아니라 특정 단일 관리 Public IP에만 허용했다. 실제 Source IP 주소는 기록하지 않는다.
- 두 VM을 Availability Zone 1과 2에 나눠 단일 Zone 장애의 영향을 줄이도록 설계했다.
- 실제 Availability Zone 장애 내성은 아직 시험하지 않았다.

### 예상 결과

- NSG가 `snet-web`에 연결되고, 사용자 정의 Inbound Rule과 Azure 기본 Inbound Rule이 의도한 값으로 표시될 것으로 예상했다.
- 두 VM이 서로 다른 Availability Zone에서 Running 상태로 표시되고 `be-pool-linux-web`의 구성원으로 확인될 것으로 예상했다.
- 이 예상은 배치와 등록 상태에 관한 것이며 SSH, OS, Outbound, 애플리케이션 및 장애 대응 동작의 성공을 의미하지 않는다.

### 실행한 명령어와 출력

이 기록에는 Azure CLI 또는 Shell 명령 출력이 남아 있지 않다. Azure Portal 화면을 증거로 사용했다.

### 실제 결과

- `nsg-linux-web` 연결 대상: `snet-web` (`10.10.1.0/24`)
- `allow-http-80`: Priority `200`, Source `Internet`, Protocol `TCP`, Destination Port `80`, Action `Allow`
- `allow-ssh-myip`: Priority `210`, Source `특정 단일 관리 Public IP`, Protocol `TCP`, Destination Port `22`, Action `Allow`
- Azure 기본 Rule: `AllowAzureLoadBalancerInBound` 존재, 그 밖의 Inbound 트래픽은 `DenyAllInBound`에 의해 차단
- `vm-web01`: Private IP `10.10.1.4`, Availability Zone `1`, Running, Public IP 없음
- `vm-web02`: Private IP `10.10.1.5`, Availability Zone `2`, Running, Public IP 없음
- 두 VM 모두 `be-pool-linux-web`에 등록됨

### 증거

- [Load Balancer 개요](screenshots/01-load-balancer-overview.png)
- [Frontend IP Configuration](screenshots/02-frontend-ip-configuration.png)
- [NSG Inbound Rules](screenshots/03-nsg-inbound-rules.png)
- [Backend Pool의 VM 두 대](screenshots/04-backend-pool-two-vms.png)

### 핵심 요약

> 개별 Public IP가 없는 VM 두 대를 Private Subnet의 Availability Zone 1과 2에 분산 배치해 Backend Pool에 등록하고, NSG에서 HTTP는 Internet에, SSH는 특정 단일 관리 Public IP에만 허용했지만 실제 고가용성과 통신 동작은 아직 검증하지 않았습니다.

### 미확인 사항

- VM 크기, Rocky Linux 버전, NIC 이름 및 SSH NAT Port는 이 기록 당시 미확인이었으며 2026-07-23~2026-08-04 후속 기록에서 확인했다.
- 두 VM의 SSH 접속, Outbound 통신, Nginx 및 Health Probe 정상 상태는 미검증이다.
- HTTP 부하 분산, 장애 제외·복구 및 실제 Availability Zone 장애 내성은 미검증이다.

### 다음 TODO

- [x] `vm-web01`의 VM Size 확인
- [x] `vm-web02`의 VM Size와 두 VM의 Azure NIC 리소스 이름 확인 (2026-08-04 Azure Portal 후속 확인)
- [x] 두 VM의 SSH 접속, Rocky Linux 버전 및 Outbound 통신 검증
- [x] Nginx 설치와 Health Probe 정상 상태 검증 (2026-07-26~2026-08-04 후속 작업)
- [x] HTTP 부하 분산, 장애 제외 및 복구 검증 (2026-07-26~2026-08-04 후속 작업)

실제 Availability Zone 장애 내성 시험은 미검증 한계이자 선택 확장 과제로 남아 있다.

---

## 2026-07-23 — SSH NAT, NSG 접근 제어 및 Linux Baseline 검증

### 목표

개별 Public IP가 없는 두 VM의 Inbound NAT Port Mapping과 SSH 관리 경로를 확인하고, Linux 기본 상태와 Outbound 통신 결과를 실제 확인 범위에 맞춰 기록한다. 접속 위치 변경으로 발생한 집 SSH 문제는 원인 가설, 완화 조치 및 재검증 상태를 구분하여 남긴다.

### 실제 작업 내용

- `vm-web01`의 Load Balancer Frontend TCP 50001 → Backend TCP 22 Mapping과 `vm-web02`의 Frontend TCP 50002 → Backend TCP 22 Mapping을 확인했다.
- DCT 랩실의 특정 단일 관리 Public IP만 허용하는 기존 `allow-ssh-myip`을 유지하고, 집 접속을 위해 `allow-ssh-home`을 Priority `211`, 특정 단일 Home Public IP, TCP 22, `Allow`로 추가했다.
- 두 VM에 `azureuser`로 SSH 접속하고 Hostname, Rocky Linux 버전, Private IP 및 외부 HTTPS·Outbound 동작을 확인했다.
- `vm-web01`에서는 Kernel, Default Route, `sshd` 상태, TCP 22 Listening, IPv4 DNS 조회, VM Size, Image Reference, 시간 동기화 및 Network Interface Driver 구조를 추가로 확인했다.
- 집에서 `vm-web01`의 Frontend Port 50001로 접속했을 때 응답 없이 대기한 현상을 별도의 트러블슈팅 기록으로 남겼다.

### 설정을 선택한 이유

- 두 VM에는 개별 Public IP를 부여하지 않았으므로, Load Balancer Frontend의 서로 다른 Inbound NAT Port를 각 VM의 TCP 22에 연결해 관리 접점을 구분했다.
- SSH Source를 Internet 전체에 열지 않고, DCT 랩실과 Home의 특정 단일 관리 Public IP에만 각각 허용하도록 제한했다. 실제 Source IP 주소는 기록하지 않는다.
- `allow-ssh-home`은 접속 위치가 DCT 랩실에서 집으로 바뀐 상황에서 Home 원본 IP를 별도로 허용하기 위한 완화 조치로 추가했다.
- Outbound 검증은 개별 Public IP가 없는 VM이 외부 HTTPS Endpoint에 도달하고 Load Balancer Frontend Public IP를 통해 나가는지 확인하기 위해 수행했다.

### 예상 결과

작업 전에 별도로 보존한 예상 결과 문서는 없다. 이번 검증에서 확인하려던 성공 조건은 다음과 같았다.

- Frontend TCP 50001과 50002를 통해 각각 의도한 VM의 TCP 22에 접속한다.
- 두 VM에서 실제 Hostname, OS, Private IP를 확인한다.
- 두 VM이 외부 HTTPS 요청에 성공하고, 관찰된 Outbound Public IP가 Load Balancer Frontend Public IP와 일치한다.
- `allow-ssh-home` 추가 후 집 SSH 연결이 허용될 것으로 예상했지만, 재접속하지 않아 결과는 미검증으로 남긴다.

### 실행한 명령어와 출력

SSH 접속 명령의 실제 Public IP는 공개용 Placeholder로 대체했다.

```bash
ssh -p 50001 azureuser@<LOAD_BALANCER_PUBLIC_IP>
ssh -p 50002 azureuser@<LOAD_BALANCER_PUBLIC_IP>
```

실제 출력은 공개할 필요가 없는 운영 정보와 식별자를 제외하고 다음과 같이 요약했다.

| 대상 | 명령 또는 확인 도구 | 실제 결과 요약 |
| --- | --- | --- |
| `vm-web01` | SSH, `hostnamectl`, `/etc/os-release`, `ip`, Route, `systemctl`, `ss`, `getent`, `curl`, Azure IMDS | `azureuser` 로그인, Hostname `vm-web01`, Rocky Linux 9.8, Private IP `10.10.1.4/24`, 외부 HTTPS `HTTP/2 200` 및 Outbound 경로 확인 |
| `vm-web02` | SSH, Hostname·OS·IP 확인, `curl` | `azureuser` 로그인, Hostname `vm-web02`, Rocky Linux 9.8, Private IP `10.10.1.5/24`, 외부 HTTPS `HTTP/2 200` 및 Outbound 경로 확인 |

명령별 목적과 공개용 실제 결과 요약은 [Linux Baseline 및 SSH 경로 검증 기록](commands/01-linux-baseline.md)에 분리하여 기록했다.

### 실제 결과

- `vm-web01`
  - SSH 사용자 `azureuser`, Hostname `vm-web01`
  - Rocky Linux 9.8 (Blue Onyx)
  - Kernel `5.14.0-687.10.1.el9_8.0.1.x86_64`
  - Private IP `10.10.1.4/24`, Default Route `10.10.1.1`
  - `sshd`: `active`, `enabled`; TCP 22 Listening 확인
  - IPv4 DNS 조회 성공, 외부 HTTPS 요청 `HTTP/2 200`
  - Outbound Public IP가 Load Balancer Frontend Public IP와 일치 (실제 주소 미기록)
  - VM Size `Standard_B2as_v2`, Availability Zone `1`, Location `KoreaCentral`, Resource Group `rg-linux-lb-lab`
  - Image Reference `resf / rockylinux-x86_64 / 9-base / latest`
  - Time Zone `UTC`, NTP `active`, System Clock 동기화 확인
  - `eth0` Driver `hv_netvsc`, `eth1` Driver `mlx5_core`, 동일 MAC 및 `eth1`의 `SLAVE` 상태를 통해 Accelerated Networking 구조를 보조적으로 확인
- `vm-web02`
  - SSH 사용자 `azureuser`, Hostname `vm-web02`
  - Rocky Linux 9.8 (Blue Onyx)
  - Private IP `10.10.1.5/24`, Availability Zone `2`
  - 외부 HTTPS 요청 `HTTP/2 200`
  - Outbound Public IP가 Load Balancer Frontend Public IP와 일치 (실제 주소 미기록)
- `allow-ssh-home` 추가 직후에는 집에서 다시 접속하지 않아 이 기록 당시 해당 경로의 최종 결과는 미검증이었다. 2026-07-26 후속 접속에서 해당 관리 경로를 확인했다.

### 증거

- [Inbound NAT Port Mappings](screenshots/05-inbound-nat-port-mappings.png)
- [여러 접속 위치를 위한 NSG Inbound Rules](screenshots/06-nsg-inbound-rules-multi-location.png)
- [Linux Baseline 및 SSH 경로 검증 기록](commands/01-linux-baseline.md)
- [집 SSH 연결 대기 트러블슈팅 기록](TROUBLESHOOTING.md#2026-07-23--집에서-vm-web01-ssh-연결-대기)

### 핵심 요약

> 개별 Public IP가 없는 두 Rocky Linux VM에 Load Balancer의 Inbound NAT Port를 통해 `azureuser`로 SSH 접속해 Rocky Linux 버전과 Outbound 동작을 확인했으며, 접속 위치 변경으로 발생한 SSH 문제는 NSG 원본 IP 불일치 가설에 따라 완화 조치를 적용하고 재검증 대기 상태로 관리했습니다.

### 문제점 또는 미확인 사항

- 집에서 발생한 SSH 연결 대기의 원인은 확정되지 않았다. Home 원본 IP가 당시 `allow-ssh-myip`에 매칭되지 않았을 가능성을 가장 높은 가설로 두고 있다.
- `allow-ssh-home` 추가 직후에는 집에서 재접속하지 않아 이 기록 당시 완화 조치의 최종 효과는 미검증이었다. 2026-07-26 후속 접속에서 해당 관리 경로를 확인했다.
- 두 VM의 Azure NIC 리소스 이름은 이 기록 당시 미확인이었으며, 2026-08-04 Azure Portal에서 후속 확인했다.
- `vm-web02`의 VM Size, Kernel, `sshd` 상태, Image Reference 및 시간 동기화는 이번 검증에서 별도로 확인하지 않았다. VM Size는 2026-08-04 Azure Portal에서 후속 확인했으며, 나머지 항목은 별도 확인하지 않았다.
- Nginx, Linux `firewalld`, Health Probe, HTTP 부하 분산, 장애 제외·복구는 미검증이다.
- 실제 Availability Zone 장애 내성은 시험하지 않았다.
- Runbook, Postmortem 및 점검 스크립트는 이 기록 당시 작성하지 않았다. 점검 스크립트는 2026-07-27, Runbook과 Postmortem은 2026-08-04에 후속 작성했다.

### 다음 TODO

- [x] 집에서 `allow-ssh-home` 규칙을 통한 `vm-web01` SSH 재접속 및 결과 기록 (2026-07-26)
- [x] 두 VM의 Azure NIC 리소스 이름과 `vm-web02`의 VM Size 확인 (2026-08-04 Azure Portal 후속 확인)
- [x] Nginx 설치·설정과 Linux `firewalld` 상태·HTTP 허용 검증 (2026-07-26~2026-08-03)
- [x] Health Probe 정상 결과와 HTTP Load Balancing 검증 (2026-08-04)
- [x] 장애 제외와 복구 검증 (2026-07-26~2026-08-04)
- [x] 반복 점검 스크립트 작성 (2026-07-27)
- [x] Runbook 및 Postmortem 작성 (2026-08-04 후속 작업)

실제 Availability Zone 장애 내성 시험은 현재 미검증 한계이며, 필요 시 선택 확장 과제로 수행한다.

---

## 2026-07-26 — 집 SSH 재검증, Nginx 구성 및 HTTP 장애 전환·복구 검증

### 목표

집 WSL에서 두 VM으로 연결되는 SSH 관리 경로를 재검증하고, Nginx의 HTTP 응답과 Load Balancer의 두 백엔드 트래픽 처리를 확인한다. 이후 `vm-web01`에 HTTP 403 장애를 의도적으로 발생시켜 장애·복구 전후 외부 응답이 백엔드 제외·재포함 동작과 일치하는지 확인한다.

### 실제 작업 내용

1. 집 WSL용 별도 ED25519 SSH 키를 생성했다.
2. 기존 랩실 SSH 키를 제거하지 않고 `vm-web01`과 `vm-web02`에 집 공개키를 추가했다.
3. 집 네트워크에서 Load Balancer Inbound NAT Rule을 통해 Frontend TCP 50001 → `vm-web01:22`, Frontend TCP 50002 → `vm-web02:22` SSH 접속을 확인했다.
4. `vm-web02`에 Nginx를 설치하고 즉시 실행과 자동 시작을 설정했다.
5. `vm-web02`에서 Nginx `active`·`enabled`, TCP 80 `LISTEN`, localhost HTTP 200, `WEB02 - Zone 2` 응답 및 `sudo nginx -t` 성공을 확인했다. 2026-07-26 당시 `firewalld`는 두 VM에서 모두 `inactive`임을 확인했다.
6. Load Balancer 공용 TCP 80으로 요청해 WEB01과 WEB02 응답이 모두 나타나는 것을 확인했다.
7. `vm-web01`의 `/usr/share/nginx/html/index.html` 권한을 `000`으로 바꿔 HTTP 계층 장애를 발생시켰다.
8. 장애 중에도 `vm-web01`의 Nginx는 `active`, TCP 80은 `LISTEN`을 유지했으며 localhost 요청은 HTTP 403을 반환했다.
9. HTTP 403 발생 후 Load Balancer 외부 요청에서 WEB01 응답이 사라지고 WEB02만 계속 응답하는 것을 확인했다.
10. 파일 권한을 `644`로 복구한 뒤 localhost HTTP 200과 Load Balancer 응답에서 WEB01 재등장을 확인했다.

### 설정을 선택한 이유

- 집 WSL용 키를 랩실 키와 분리하고 기존 랩실 키를 유지한 상태에서 집 공개키를 추가해 두 관리 환경의 SSH 키를 함께 사용했다.
- 각 서버를 구분할 수 있는 응답으로 두 백엔드가 실제로 HTTP 요청을 처리하는지 확인했다.
- Nginx 프로세스를 중지하지 않고 웹 문서 읽기 권한만 제거해 프로세스·전송 계층은 유지된 HTTP 계층 장애를 시험했다.

### 예상 결과

작업 전에 별도로 보존한 예상 결과 문서는 없다. 이번 시험에서 확인하려던 성공 조건은 다음과 같았다.

- 집에서 각 Inbound NAT Port를 통해 의도한 VM에 SSH로 접속한다.
- 정상 상태의 외부 요청에서 WEB01과 WEB02 응답을 모두 확인한다.
- `vm-web01`의 HTTP 403 발생 후 외부 요청에서 WEB01이 사라지고 WEB02만 응답한다.
- 파일 권한 복구 후 `vm-web01`이 HTTP 200으로 돌아오고 Load Balancer 트래픽 대상에 다시 포함된다.

### 실행한 명령어와 출력

`vm-web02`에서 실제로 실행한 Nginx 설치·실행 명령은 다음과 같다.

```bash
sudo dnf install -y nginx
sudo systemctl enable --now nginx
```

`vm-web01`에서 실제로 실행한 장애 발생·복구 명령은 다음과 같다.

```bash
sudo chmod 000 /usr/share/nginx/html/index.html
sudo chmod 644 /usr/share/nginx/html/index.html
```

SSH 키 생성·공개키 추가와 상태 확인에 사용한 전체 원문 명령은 당시 기록으로 보존하지 못했다. 임의로 재구성하지 않고 공개 가능한 실제 결과만 다음과 같이 요약했다.

| 대상 또는 경로 | 확인 항목 | 실제 결과 |
| --- | --- | --- |
| 집 → `vm-web01` | Frontend TCP 50001 → Backend TCP 22 | SSH 접속 성공 |
| 집 → `vm-web02` | Frontend TCP 50002 → Backend TCP 22 | SSH 접속 성공 |
| `vm-web02` | Nginx 서비스 | `active`, `enabled`, TCP 80 `LISTEN` |
| `vm-web02` | HTTP·설정 검사 | localhost HTTP 200, `WEB02 - Zone 2`, `sudo nginx -t` 성공 |
| 두 VM | 2026-07-26 당시 `firewalld` | 모두 `inactive` |
| Load Balancer TCP 80 | 정상 상태의 백엔드 응답 | WEB01과 WEB02 모두 관찰 |
| `vm-web01` 장애 상태 | 서비스·포트·HTTP | Nginx `active`, TCP 80 `LISTEN`, localhost HTTP 403 |
| Load Balancer TCP 80 | `vm-web01` HTTP 403 발생 후 | WEB01은 나타나지 않고 WEB02만 계속 응답 |
| `vm-web01` 복구 후 | 로컬·외부 HTTP | localhost HTTP 200, Load Balancer 응답에 WEB01 재등장 |

명령과 단계별 결과는 [Nginx 및 HTTP 장애 전환·복구 명령 기록](commands/2026-07-26-nginx-http-failover.md)에 정리했다.

### 실제 결과

- 기존 랩실 SSH 키를 제거하지 않고 집 공개키를 추가한 뒤, 집에서 두 Inbound NAT Port를 통한 VM별 SSH 접속에 성공했다.
- `vm-web02`의 Nginx 서비스·부팅 설정·TCP 80 수신·로컬 HTTP 응답·응답 페이지·설정 문법을 확인했다.
- 2026-07-26 당시 두 VM에서 `firewalld inactive`를 확인했다.
- 정상 상태의 Load Balancer 요청에서 두 백엔드 응답을 모두 확인했다. 응답 비율은 정확한 50:50이 아니었지만 이를 장애로 판단하지 않았다.
- `vm-web01`의 파일 권한 변경으로 Nginx 프로세스와 TCP 80 수신은 유지하면서 HTTP 403을 발생시켰다.
- HTTP 403 발생과 권한 복구 전후 외부 응답에서 백엔드 제외·재포함 동작과 일치하는 결과를 확인했다.

### 증거

- [Nginx 및 HTTP 장애 전환·복구 명령 기록](commands/2026-07-26-nginx-http-failover.md)
- [vm-web01 HTTP 403 장애 트러블슈팅 기록](TROUBLESHOOTING.md#2026-07-26--vm-web01-http-403-장애-제외와-복구)

### 핵심 요약

> Nginx 프로세스와 TCP 80 수신은 유지한 채 `vm-web01`의 웹 문서 권한을 제거해 HTTP 403 장애를 만들고, 권한 복구 전후 외부 응답에서 백엔드 제외·재포함 동작과 일치하는 결과를 확인했습니다.

### 문제점 또는 미확인 사항

- 감시 중간에 공백이 있어 장애 발생부터 WEB01 제외까지의 정확한 시간은 측정하지 못했다.
- Health Probe의 Portal 표시 상태와 정확한 상태 전환 시각은 기록하지 않았다.
- 정상 상태의 WEB01·WEB02 응답 비율은 정확한 50:50이 아니었으며, 정확한 균등 분산을 검증한 결과로 해석하지 않는다.
- `sudo nginx -t` 성공은 `vm-web02`에서만 확인했다.
- 실제 Availability Zone 장애 내성은 시험하지 않았다.

### 다음 TODO

- [ ] 연속 요청과 시각 기록을 사용해 외부 응답에서 WEB01이 사라지는 시점을 별도 측정
- [x] 두 VM의 Azure NIC 리소스 이름과 `vm-web02`의 VM Size 확인 (2026-08-04 Azure Portal 후속 확인)
- [x] Runbook 및 Postmortem 작성 (2026-08-04 후속 작업)
- [x] 반복 점검 스크립트 작성 (2026-07-27 후속 작업)

---

## 2026-07-27 — 랩실 NSG Source 갱신 및 firewalld HTTP 장애·복구 검증

### 목표

랩실에서 발생한 SSH timeout의 접근 제어 원인을 확인하고, `vm-web01`에 `firewalld`를 활성화한 뒤 HTTP 미허용 상태와 복구 전후의 Load Balancer 외부 응답을 비교한다.

### 실제 작업 내용

1. 이전에 접속했던 것과 같은 랩실 Wi-Fi에서 Load Balancer Frontend TCP 50001을 통한 `vm-web01` SSH 접속이 timeout 되는 것을 확인했다.
2. 랩실의 현재 공용 IPv4와 `allow-ssh-myip`에 등록된 기존 Source `/32`를 비교해 두 값이 다른 것을 확인했다. 실제 주소는 기록하지 않았다.
3. `allow-ssh-myip`의 Source를 현재 랩실 공용 IP `/32`로 수정했다.
4. 수정 후 Frontend TCP 50001을 통해 `vm-web01`에 SSH로 접속했다. SSH post-quantum 관련 경고가 표시됐지만 로그인은 성공했으므로 해당 경고는 접속 실패 원인이 아니었다.
5. `vm-web01`에서 처음에는 `firewall-offline-cmd` 명령이 존재하지 않는 것을 확인한 뒤 `firewalld` 패키지를 설치했다.
6. NetworkManager 연결 프로필 `System eth0`의 `connection.zone`을 `public`으로 명시적으로 설정했다.
7. 활성화 전 public Zone에 `cockpit`, `dhcpv6-client`, `ssh` 서비스가 있고, `http` 서비스와 `80/tcp` 허용은 없는 것을 확인했다. SSH 허용 상태를 확인한 뒤 `firewalld`를 활성화했다.
8. `firewalld`가 `active`·`enabled` 상태이고, `sudo firewall-cmd --get-active-zones`에서는 public Zone에 `eth0`과 `eth1`이 표시되는 것을 확인했다. 별도로 `sudo firewall-cmd --zone=public --list-all`의 `interfaces` 항목에는 `eth0`만 표시됐다.
9. 장애 상태에서도 `vm-web01`의 Nginx는 `active`·`enabled`, TCP 80은 `LISTEN`, localhost HTTP 상태는 200이었다. `sudo nginx -t` 결과는 이번 검증에서 확인하지 않았다.
10. 랩실 WSL에서 Load Balancer 공용 TCP 80을 반복 요청했을 때 WEB02만 계속 응답하는 것을 관찰했다.
11. public Zone의 runtime과 permanent 설정에 HTTP 서비스를 추가한 뒤 두 범위에서 `query-service=http` 결과가 모두 `yes`인 것을 확인했다.
12. 복구 후 외부 반복 요청에서 WEB01과 WEB02 응답이 다시 나타나는 것을 확인했다. 정확한 50:50 분산은 검증하지 않았다.
13. 별도 보조 시험으로 `vm-web01`의 Nginx를 잠시 중지했다가 복구했으며, 일시적인 `REQUEST_FAILED`, WEB02 전환 및 WEB01 복귀를 관찰했다. 이번 기록의 주 장애 사례는 Nginx 중지가 아니라 `firewalld`의 HTTP 차단이다.

### 설정을 선택한 이유

- SSH Source를 Internet 전체에 열지 않고 관리 위치의 단일 공용 IP `/32`로 제한하는 원칙을 유지하면서, 실제 접속 위치의 현재 주소에 맞춰 `allow-ssh-myip`을 갱신했다.
- 같은 Wi-Fi를 사용하더라도 공용 IP가 항상 유지되는 것은 아니므로, SSH timeout 발생 시 현재 원본 IP와 NSG Source를 먼저 비교했다.
- Nginx 프로세스와 로컬 HTTP 서비스가 정상인 상태에서 호스트 방화벽의 HTTP 허용 여부만 바꿔 네트워크 계층 차단이 외부 응답에 미치는 영향을 분리해 확인했다.
- runtime 설정은 현재 실행 중인 방화벽에서 HTTP를 즉시 복구하기 위해 적용했다.
- permanent 설정은 firewalld 재시작 또는 VM 재부팅 후에도 HTTP 허용을 유지하기 위해 적용했다.

### 예상 결과

이번 작업에서 확인하려던 조건은 다음과 같았다.

- 현재 랩실 공용 IPv4와 NSG Source `/32`가 다르다면 Source 갱신 후 SSH 관리 경로가 다시 동작한다.
- Nginx와 localhost HTTP가 정상이어도 public Zone에서 HTTP를 허용하지 않으면 외부 반복 요청에서 WEB01이 나타나지 않는다.
- public Zone에 HTTP를 허용한 뒤 외부 반복 요청에서 WEB01이 다시 나타난다.

### 실행한 명령어와 출력

실제 공용 IP는 Placeholder로 대체했다.

```bash
ssh -p 50001 azureuser@<LOAD_BALANCER_PUBLIC_IP>
rpm -q firewalld || sudo dnf install -y firewalld
sudo nmcli connection modify "System eth0" connection.zone public
nmcli -g connection.zone connection show "System eth0"
sudo systemctl enable --now firewalld
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=public --list-all
sudo firewall-cmd --zone=public --add-service=http
sudo firewall-cmd --zone=public --add-service=http --permanent
```

설치 전에는 `firewall-offline-cmd`가 존재하지 않았고, 위 패키지 확인·설치 명령 실행 후 `firewall-offline-cmd`를 포함한 `firewalld` 명령을 사용할 수 있었다. 상태 확인 결과는 출력 범위를 섞지 않고 다음과 같이 요약했다.

| 확인 범위 | 실제 결과 |
| --- | --- |
| NetworkManager 연결 프로필 | `System eth0`에 `connection.zone=public`을 명시적으로 설정 |
| `sudo firewall-cmd --get-active-zones` | public Zone에 `eth0`, `eth1` 표시 |
| `sudo firewall-cmd --zone=public --list-all` | `interfaces` 항목에 `eth0` 표시 |
| HTTP 허용 전 public Zone | `cockpit`, `dhcpv6-client`, `ssh`; `http`와 `80/tcp` 허용 없음 |
| `vm-web01` 로컬 상태 | Nginx `active`·`enabled`, TCP 80 `LISTEN`, localhost HTTP 200 |
| HTTP 허용 후 조회 | runtime 및 permanent의 `query-service=http` 결과 모두 `yes` |
| Load Balancer 외부 반복 요청 | 차단 중 WEB02만 관찰, 복구 후 WEB01과 WEB02 관찰 |

`eth1`에도 NetworkManager의 `connection.zone`을 직접 설정한 것으로 해석하지 않는다. 명령과 단계별 공개용 결과는 [firewalld HTTP 장애·복구 명령 기록](commands/2026-07-27-firewalld-http-failover.md)에 정리했다.

### 실제 결과

- 오래된 랩실 Source `/32`와 현재 랩실 공용 IPv4의 불일치를 확인하고 `allow-ssh-myip`을 갱신한 뒤, Frontend TCP 50001을 통한 `vm-web01` SSH 접속에 성공했다.
- `vm-web01`의 Nginx 프로세스, 자동 시작, TCP 80 수신 및 로컬 HTTP 서비스가 정상인 상태에서 `firewalld` public Zone의 HTTP 미허용을 확인했다.
- HTTP 미허용 상태의 외부 반복 요청에서는 WEB02만 관찰됐다. 이 결과는 호스트 방화벽이 외부 HTTP와 Health Probe 접근을 차단해 WEB01이 트래픽 대상에서 제외된 동작과 일치한다.
- HTTP 서비스를 runtime과 permanent에 허용한 뒤 외부 반복 요청에서 WEB01이 다시 나타나 트래픽 대상 재포함과 일치하는 결과를 확인했다.
- Azure Portal의 정확한 `Healthy/Unhealthy` 표시와 제외·재포함 시각은 확인하지 않았다.

### 증거

- [로컬 서비스 정상 및 firewalld HTTP 미허용](screenshots/07-firewalld-block-local-service-healthy.png)
- [firewalld 차단 중 WEB02만 응답](screenshots/08-firewalld-web01-excluded.png)
- [HTTP 허용 후 WEB01 재등장](screenshots/09-firewalld-web01-reincluded.png)
- [firewalld HTTP 장애·복구 명령 기록](commands/2026-07-27-firewalld-http-failover.md)
- [반복 HTTP 점검 스크립트](scripts/monitor-lb-http.sh)
- [랩실 NSG Source `/32` 불일치 트러블슈팅 기록](TROUBLESHOOTING.md#2026-07-27--랩실-nsg-source-32-불일치로-인한-ssh-timeout)
- [firewalld HTTP 차단 트러블슈팅 기록](TROUBLESHOOTING.md#2026-07-27--vm-web01-firewalld-http-차단과-복구)

### 핵심 요약

> 랩실 SSH timeout은 현재 원본 IP와 NSG Source `/32`를 비교해 복구했고, Nginx와 localhost HTTP가 정상인 상태에서 `firewalld`가 HTTP를 차단하도록 시험한 뒤 외부 응답의 WEB01 제외·재포함과 일치하는 동작을 확인했습니다.

### 문제점 또는 미확인 사항

- 같은 랩실 Wi-Fi를 사용하더라도 공용 IPv4가 항상 유지된다고 볼 수 없다.
- Azure Portal의 정확한 Health Probe `Healthy/Unhealthy` 표시와 상태 전환 시각은 확인하지 않았다.
- 외부 응답에서 WEB01과 WEB02가 모두 관찰됐지만 정확한 50:50 분산은 검증하지 않았다.
- `vm-web01`의 `sudo nginx -t` 결과는 이 작업 당시 미확인이었으며, 2026-08-03 구성 Playbook 적용에서 성공을 확인했다.
- 별도 Nginx 중지 시험의 일시적인 `REQUEST_FAILED` 원인과 정확한 전환 시각은 따로 측정하지 않았다.
- 두 VM의 Azure NIC 리소스 이름과 `vm-web02`의 VM Size는 이 기록 당시 미확인이었으며, 2026-08-04 Azure Portal에서 후속 확인했다.

### 다음 TODO

- [ ] Azure Portal의 Health Probe 표시와 외부 응답 변화를 같은 시간축으로 기록
- [x] `vm-web01`에서 `sudo nginx -t` 실행 결과 확인 (2026-08-03 구성 Playbook 적용)
- [x] 두 VM의 Azure NIC 리소스 이름과 `vm-web02`의 VM Size 확인 (2026-08-04 Azure Portal 후속 확인)
- [x] Runbook 및 Postmortem 작성 (2026-08-04 후속 작업)

---

## 2026-08-04 — 두 VM Ansible 멱등성 및 vm-web02 Nginx Drift 복구 검증

### 목표

`web-config.yml`을 두 VM에 적용한 뒤 전체 재실행의 멱등성을 확인하고, `vm-web02`의 Nginx 실행 상태를 의도적으로 변경한 뒤 같은 Playbook으로 원하는 상태를 복구할 수 있는지 검증한다.

### 실제 작업 내용

1. 2026-08-03 선행 작업으로 `vm-web01`에 구성 Playbook을 처음 적용해 필요한 두 항목을 변경하고, 두 번째 실행에서 `changed=0`을 확인했다.
2. 같은 날 `vm-web02`의 Check Mode에서 선행 패키지가 실제로 설치되지 않아 다음 firewalld Task가 실패하는 것을 확인했다. 실제 적용에서는 다섯 항목이 변경됐고 내부 검증까지 성공했다.
3. 관리 네트워크 이동으로 원본 IP와 NSG Source `/32`가 달라졌을 때 `vm-web02`가 `unreachable=1`로 종료되는 것을 확인했다. 랩실로 돌아온 뒤 `ansible.builtin.ping`에 성공했다.
4. 2026-08-04에 `vm-web02`를 다시 실행해 `changed=0`을 확인하고, 두 VM 전체 실행에서도 각 호스트가 `changed=0`으로 끝나는 것을 확인했다. `serial: 1`에 따라 한 대씩 순차 처리됐다.
5. `vm-web02`의 Nginx를 수동으로 중지해 Drift를 만들었다. 서버에서 Nginx `inactive`, TCP 80 `NOT_LISTENING`, localhost HTTP 연결 실패를 확인했다.
6. 외부 반복 요청에서는 잠시 `REQUEST FAILED`가 나타난 뒤 WEB01만 응답했다. Azure Portal에서는 `vm-web01`이 `Up`, `vm-web02`가 `Down`, 전체 상태가 50%로 표시됐다.
7. 구성 Playbook을 `vm-web02`에 다시 적용했다. `Start and enable nginx` Task만 변경됐고, `nginx -t`, localhost HTTP 200과 서버별 응답 본문 검증에 성공했다.
8. 복구 후 외부 응답에 WEB02가 다시 나타났고, Portal에서 두 VM이 모두 `Up`, 전체 상태가 100%인 것을 확인했다.
9. 마지막으로 두 VM 전체에 구성 Playbook을 실행해 두 호스트 모두 다시 `changed=0`인 것을 확인했다.
10. Azure Portal에서 두 VM의 VM Size, 표시 사양과 Azure NIC 리소스 이름을 확인했다.
11. 반복 가능한 점검·복구 절차를 운영 Runbook으로, 통제 시험의 영향과 한계를 Postmortem으로 정리했다.

### 설정을 선택한 이유

- `serial: 1`로 한 번에 한 백엔드만 처리해 두 VM을 동시에 변경하지 않도록 구성했다.
- 서버별 HTML, Nginx와 firewalld 상태를 Playbook의 원하는 상태로 정의해 수동 변경으로 생긴 Drift를 같은 절차로 복구하고자 했다.
- 서버 내부 상태, Load Balancer 외부 응답과 Portal Health Probe를 함께 확인해 복구 결과를 한 계층의 출력에만 의존하지 않았다.
- 운영 절차와 시험 회고를 분리해 장애 대응 순서와 관찰된 한계를 각각 재사용할 수 있게 기록했다.

### 예상 결과

작업 전에 별도로 보존한 예상 결과 문서는 없다. 이번 단계에서 확인하려던 성공 조건은 다음과 같았다.

- 두 VM이 이미 원하는 상태라면 전체 재실행에서 `changed=0`이 된다.
- `vm-web02`의 Nginx를 중지하면 로컬 HTTP가 실패하고 Health Probe와 외부 응답에서 영향이 나타난다.
- 구성 Playbook을 다시 적용하면 Nginx 실행 상태만 복구되고 내부·외부 HTTP와 Portal 상태가 정상으로 돌아온다.
- 복구 후 최종 전체 실행에서도 두 VM 모두 `changed=0`이 된다.

### 실행한 명령어와 출력

공개용 명령은 `ansible/` 디렉터리를 기준으로 기록했다. 실제 Inventory와 SSH Key 경로는 Git에서 제외했다.

```bash
ansible-playbook --diff --limit vm-web01 playbooks/web-config.yml
ansible-playbook --check --diff --limit vm-web02 playbooks/web-config.yml
ansible-playbook --diff --limit vm-web02 playbooks/web-config.yml
ansible-playbook --diff playbooks/web-config.yml
```

주요 실행 결과는 다음과 같다.

| 단계 | 실제 결과 | 종료 코드 |
| --- | --- | --- |
| `vm-web01` 첫 적용 | `ok=13 changed=2 unreachable=0 failed=0` | 미기록 |
| `vm-web01` 두 번째 실행 | `ok=13 changed=0 unreachable=0 failed=0` | 0 |
| `vm-web02` Check Mode | `ok=3 changed=1 unreachable=0 failed=1` | 2 |
| `vm-web02` 첫 실제 적용 | `ok=13 changed=5 unreachable=0 failed=0` | 0 |
| 관리 경로 불일치 상태 | `unreachable=1` | 4 |
| `vm-web02` 두 번째 실행 | `ok=13 changed=0 unreachable=0 failed=0` | 0 |
| Drift 전 두 VM 전체 실행 | 두 VM 각각 `ok=13 changed=0 unreachable=0 failed=0` | 0 |
| `vm-web02` Drift 복구 | `ok=13 changed=1 unreachable=0 failed=0` | 0 |
| 복구 후 두 VM 전체 실행 | 두 VM 각각 `ok=13 changed=0 unreachable=0 failed=0` | 0 |

Drift를 만들 때 실제로 실행한 명령은 다음과 같다.

```bash
ansible vm-web02 \
  --become \
  -m ansible.builtin.systemd_service \
  -a "name=nginx state=stopped"
```

### 실제 결과

- 구성 Playbook을 두 VM에 적용한 뒤 전체 실행과 최종 재실행에서 두 호스트 모두 `changed=0`을 확인했다.
- `vm-web02`의 Nginx 중지 상태에서 내부 HTTP 실패, 외부 WEB01 단독 응답과 Portal의 `vm-web02` `Down`을 확인했다.
- Ansible 복구에서는 Nginx 시작 Task만 변경됐고, 내부 검증과 외부 WEB02 재등장 및 Portal의 두 VM `Up`을 확인했다.
- Check Mode 실패와 관리 경로의 `unreachable`은 원인과 실행 단계가 다른 문제로 구분했다.
- 두 VM 모두 `Standard_B2as_v2`(2 vCPU, 8 GiB)임을 확인했다. `vm-web01`의 Azure NIC는 `vm-web01938_z1`, `vm-web02`의 Azure NIC는 `vm-web02737_z2`였다.
- 운영 Runbook과 통제된 Nginx Drift 시험 Postmortem을 작성했다.

### 증거

- [`vm-web01` 구성 및 멱등성 검증](commands/2026-08-03-ansible-web-config-vm-web01.md)
- [`vm-web02` 구성 및 멱등성 검증](commands/2026-08-04-ansible-web-config-vm-web02.md)
- [`vm-web02` Nginx Drift 및 복구 기록](commands/2026-08-04-ansible-nginx-drift-recovery.md)
- [두 VM 전체 멱등성](screenshots/10-ansible-two-vm-idempotency.png)
- [Drift 상태와 WEB01 단독 응답](screenshots/11-drift-web01-only.png)
- [Portal의 vm-web02 Down 상태](screenshots/12-probe-vm-web02-unhealthy.png)
- [Ansible 복구와 WEB02 재등장](screenshots/13-ansible-drift-recovery.png)
- [복구 후 Portal의 두 VM Up 상태](screenshots/14-probe-vm-web02-recovered.png)
- [Check Mode 의존성 실패 트러블슈팅](TROUBLESHOOTING.md#2026-08-03--ansible-check-mode에서-python3-firewall-미설치로-인한-firewalld-task-실패)
- [웹 서비스 운영 Runbook](docs/operations-runbook.md)
- [2026-08-04 Nginx Drift 통제 시험 Postmortem](docs/postmortem-2026-08-04-nginx-drift.md)

### 핵심 요약

> 두 Rocky Linux 백엔드의 웹 서버 상태를 Ansible로 동일하게 구성하고 멱등성을 확인한 뒤, `vm-web02`의 Nginx Drift를 같은 Playbook으로 복구해 내부 HTTP, 외부 응답과 Portal Health Probe의 정상 복귀를 확인했습니다.

### 문제점 또는 미확인 사항

- Health Probe가 `vm-web02`를 제외하고 다시 포함한 내부 판정 시각은 초 단위로 완전히 측정하지 않았다.
- 단일 클라이언트의 외부 요청만 관찰했으므로 모든 사용자에 대한 무중단을 입증한 결과는 아니다.
- Portal의 50%와 100%는 백엔드 건강도이며 정확한 50:50 트래픽 분산 결과가 아니다.
- 실제 Availability Zone 장애와 다중 Region 동작은 시험하지 않았다.

### 다음 TODO

- [x] 두 Azure NIC 리소스 이름 확인 (2026-08-04 Azure Portal)
- [x] `vm-web02`의 VM Size 확인 (2026-08-04 Azure Portal)
- [x] 반복 가능한 점검·복구 Runbook 작성 (`docs/operations-runbook.md`)
- [x] 장애 시험 Postmortem 작성 (`docs/postmortem-2026-08-04-nginx-drift.md`)

---
