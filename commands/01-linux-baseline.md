# 2026-07-23 — Linux Baseline 및 SSH 경로 검증

## 목적

Load Balancer의 Inbound NAT Port Mapping을 통해 개별 Public IP가 없는 `vm-web01`과 `vm-web02`에 SSH로 접속하고, 각 VM에서 실제로 확인한 Linux 기본 상태와 Outbound 통신 결과를 기록합니다.

이 문서는 원본 전체 출력을 복제하지 않고 공개할 필요가 없는 운영 정보와 식별자를 제거한 **실제 결과 요약**입니다. `<LOAD_BALANCER_PUBLIC_IP>`, `<DNS_TEST_HOST>`, `<HTTPS_TEST_URL>`, `<PUBLIC_IP_CHECK_URL>`, `<IMDS_API_VERSION>`은 저장소에 실제 값을 남기지 않기 위한 대체 표기입니다.

정확한 옵션이나 URL이 제공되지 않은 명령은 임의로 원문 명령줄을 재구성하지 않고, 실제 사용한 명령 종류와 확인 목적만 기록합니다. 따라서 아래의 SSH와 IMDS 예시를 제외한 명령 표기는 실행 도구 수준의 요약입니다.

## SSH 관리 경로

실제 숫자 Public IP를 Placeholder로 대체한 공개용 접속 형태입니다.

```bash
ssh -p 50001 azureuser@<LOAD_BALANCER_PUBLIC_IP>
ssh -p 50002 azureuser@<LOAD_BALANCER_PUBLIC_IP>
```

| 대상 | Frontend | Backend | 로그인 결과 |
| --- | --- | --- | --- |
| `vm-web01` | TCP `50001` | TCP `22` | `azureuser`로 SSH 접속 성공 |
| `vm-web02` | TCP `50002` | TCP `22` | `azureuser`로 SSH 접속 성공, Prompt `[azureuser@vm-web02 ~]$` 확인 |

이 SSH 성공 결과는 두 VM의 관리 접속 확인 사실입니다. `allow-ssh-home` 추가 직후 집에서 다시 접속한 결과를 뜻하지 않았으며, 해당 관리 경로는 2026-07-26 후속 접속에서 확인했습니다.

## vm-web01

### 실제 명령과 결과 요약

| 확인 항목 | 실제 사용한 명령 또는 도구 | 명령 목적 | 공개용 실제 결과 요약 |
| --- | --- | --- | --- |
| Hostname, Kernel | `hostnamectl` | System Identity와 Kernel 확인 | Hostname `vm-web01`, Kernel `5.14.0-687.10.1.el9_8.0.1.x86_64` |
| OS | `/etc/os-release` 조회 | Distribution과 Version 확인 | Rocky Linux 9.8 (Blue Onyx) |
| IP | `ip` | IPv4 주소와 Interface 상태 확인 | Private IP `10.10.1.4/24` |
| Route | Route 조회 명령 | Default Gateway 확인 | Default Route `10.10.1.1` |
| SSH Service | `systemctl` | `sshd` 실행 및 자동 시작 상태 확인 | `active`, `enabled` |
| Listening Port | `ss` | SSH Port Listening 확인 | TCP 22 Listening |
| DNS | `getent` | `<DNS_TEST_HOST>`의 IPv4 이름 조회 확인 | IPv4 DNS 조회 성공 |
| 외부 HTTPS | `curl` | `<HTTPS_TEST_URL>`에 HTTPS 요청 | `HTTP/2 200` |
| Outbound Public IP | `curl` | `<PUBLIC_IP_CHECK_URL>`로 Egress 주소 확인 | 관찰된 Outbound Public IP가 Load Balancer Frontend Public IP와 일치, 실제 주소 미기록 |
| Azure VM Metadata | Azure IMDS 요청 | VM Size, Zone, Location, Resource Group 및 Image Reference 확인 | `Standard_B2as_v2`, Zone `1`, `KoreaCentral`, `rg-linux-lb-lab`, `resf / rockylinux-x86_64 / 9-base / latest` |
| 시간 동기화 | 시간 상태 확인 명령 | Time Zone, NTP 및 System Clock 상태 확인 | `UTC`, NTP `active`, System Clock 동기화 |
| Network Interface 구조 | Interface 및 Driver 확인 명령 | Accelerated Networking Interface 관계 확인 | `eth0`: `hv_netvsc`, `eth1`: `mlx5_core`, 동일 MAC 및 `eth1`의 `SLAVE` 상태 확인 |

Azure IMDS 요청은 공개용으로 다음과 같이 정규화했습니다. 실제 API Version 값은 기록하지 않습니다.

```bash
curl -sS -H Metadata:true \
  "http://169.254.169.254/metadata/instance/compute?api-version=<IMDS_API_VERSION>"
```

Interface와 Driver 확인은 Accelerated Networking 구조를 이해하기 위한 보조 점검입니다. 이 관찰을 웹 서비스 가용성이나 프로젝트의 핵심 성과로 해석하지 않습니다.

## vm-web02

### 실제 명령과 결과 요약

| 확인 항목 | 실제 사용한 명령 또는 도구 | 명령 목적 | 공개용 실제 결과 요약 |
| --- | --- | --- | --- |
| SSH 사용자와 Hostname | SSH 및 Hostname 확인 | 로그인 사용자와 대상 VM 확인 | 사용자 `azureuser`, Hostname `vm-web02` |
| OS | `/etc/os-release` 조회 | Distribution과 Version 확인 | Rocky Linux 9.8 (Blue Onyx) |
| IP | `ip` | IPv4 주소 확인 | Private IP `10.10.1.5/24` |
| Availability Zone | Azure VM 정보 확인 | 배치 Zone 확인 | Zone `2` |
| 외부 HTTPS | `curl` | `<HTTPS_TEST_URL>`에 HTTPS 요청 | `HTTP/2 200` |
| Outbound Public IP | `curl` | `<PUBLIC_IP_CHECK_URL>`로 Egress 주소 확인 | 관찰된 Outbound Public IP가 Load Balancer Frontend Public IP와 일치, 실제 주소 미기록 |

### 이번 검증에서 별도로 확인하지 않은 항목

- VM Size
- Kernel
- `sshd`의 `active`·`enabled` 상태
- Image Reference
- Time Zone, NTP 및 System Clock 동기화
- Default Route와 IPv4 DNS 조회
- Network Interface Driver 구조

`vm-web01`의 결과를 `vm-web02`에도 같다고 추측하지 않습니다.

## 기록에서 제외한 값

- 실제 Load Balancer Frontend Public IP와 VM Outbound Public IP
- DCT 랩실 및 Home의 SSH 허용 Source IP
- Subscription ID
- Machine ID와 Boot ID
- SSH Host Key Fingerprint
- Network Interface의 실제 MAC 주소

값을 제외해도 Hostname, OS, Private IP, Port, 응답 상태 및 Outbound 주소의 일치 여부 등 검증의 의미는 바꾸지 않았습니다.

## 후속 재검증 상태

- [x] 집에서 `allow-ssh-home`을 통한 `vm-web01` SSH 재접속 (2026-07-26 후속 확인)
- [x] 두 VM의 Azure NIC 리소스 이름 확인 (`vm-web01938_z1`, `vm-web02737_z2`; 2026-08-04 Azure Portal 후속 확인)
- [x] `vm-web02`의 VM Size 확인 (`Standard_B2as_v2`, 2 vCPU, 8 GiB; 2026-08-04 Azure Portal 후속 확인)
- [ ] `vm-web02`의 Kernel, `sshd`, Image Reference 및 시간 동기화 별도 확인
- [x] Nginx와 Linux `firewalld` 검증 (2026-07-26~2026-08-03 후속 확인)
- [x] Health Probe, HTTP Load Balancing, 장애 제외 및 복구 검증 (2026-07-26~2026-08-04 후속 확인)

## 관련 증거

- [Inbound NAT Port Mappings](../screenshots/05-inbound-nat-port-mappings.png)
- [여러 접속 위치를 위한 NSG Inbound Rules](../screenshots/06-nsg-inbound-rules-multi-location.png)
- [2026-07-23 프로젝트 로그](../PROJECT_LOG.md#2026-07-23--ssh-nat-nsg-접근-제어-및-linux-baseline-검증)
- [집 SSH 연결 대기 트러블슈팅 기록](../TROUBLESHOOTING.md#2026-07-23--집에서-vm-web01-ssh-연결-대기)
