# Azure Load Balancer 기반 Rocky Linux 웹 서버 이중화 및 장애 복구

개별 Public IP가 없는 Rocky Linux VM 두 대를 Azure Load Balancer 뒤에 구성하고, HTTP 403·firewalld 차단·Nginx 중지 장애를 계층별로 검증한 뒤 Ansible로 멱등성과 수동 Drift 복구를 확인한 개인 프로젝트입니다.

![Azure Load Balancer와 Rocky Linux 백엔드 토폴로지](docs/images/architecture-topology.jpg)

## 한눈에 보기

| 구분 | 내용 |
| --- | --- |
| 시작 배경 | 팀 프로젝트에서 맡지 않았던 Linux 서버와 네트워크를 직접 구성하고 진단하는 경험을 보완하고자 시작했습니다. |
| 구조 | Azure Load Balancer 뒤에 개별 Public IP가 없는 Rocky Linux VM 두 대를 두고 Zone 1과 2에 나누어 배치했습니다. |
| 통신 경로 | HTTP 사용자 경로와 Inbound NAT를 이용한 SSH·Ansible 관리 경로를 분리했습니다. |
| 서비스·접근 제어 | Nginx, firewalld, Health Probe, NSG와 Inbound NAT를 함께 구성하고 상태를 점검했습니다. |
| 구성 관리 | Ansible로 두 VM의 구성을 맞추고 멱등성과 Drift 복구를 검증했습니다. `serial: 1`로 한 대씩 순차 처리했습니다. |

실제 Public IP와 관리 Source IP는 공개하지 않으며, 실제 Inventory도 Git에서 제외합니다.

## 핵심 결과

- HTTP 403과 firewalld HTTP 차단을 각각 애플리케이션 계층과 호스트 방화벽 계층의 장애로 구분했습니다.
- `vm-web02`의 Nginx를 중지하자 내부 HTTP가 실패했고, 단일 클라이언트에서 잠시 `REQUEST FAILED`가 나타난 뒤 WEB01만 응답했으며 Portal에서는 `vm-web02`가 `Down`으로 표시됐습니다.
- 운영자가 동일한 Ansible Playbook을 수동 실행해 Drift를 복구했으며, Nginx 시작 Task만 `changed=1`이었습니다.
- 복구 후 외부 응답에 WEB02가 다시 나타났고 Portal의 두 VM이 `Up`으로 돌아왔으며, 마지막 전체 재실행은 두 VM 모두 `changed=0`이었습니다.

Portal의 50%·100%는 백엔드 건강도입니다. 실제 Zone 장애와 정확한 50:50 트래픽 분산은 검증하지 않았습니다.

## 빠른 링크

- [아키텍처](docs/architecture.md)
- [운영 Runbook](docs/operations-runbook.md)
- [Nginx Drift Postmortem](docs/postmortem-2026-08-04-nginx-drift.md)
- [Ansible 구성 Playbook](ansible/playbooks/web-config.yml)

## 시작한 이유

DCT 팀 프로젝트에서 GitHub Actions와 Azure Functions를 이용한 자동 배포 흐름을 맡아 학습하고 발표했습니다. 협업과 자동 배포 흐름을 경험했지만, 담당 영역 밖의 서버와 네트워크를 처음부터 구성하고 진단하는 경험은 부족했습니다.

이를 보완하려고 이 프로젝트를 시작했습니다. Azure는 실습 환경으로 사용하고 있으며, 핵심은 특정 서비스 사용법보다 Linux 서버와 네트워크가 어떻게 연결되는지 이해하고 직접 확인하는 데 있습니다. 특히 포트 흐름, 접근 제어, 상태 확인, 장애 발생 시의 진단과 복구 과정을 제 손으로 기록하는 것을 목표로 합니다.

## 현재 구성

| 영역 | 상태 | 구성 |
| --- | --- | --- |
| 네트워크 | 구성 확인 | `Korea Central`의 `vnet-linux-lb-lab` 안에 프라이빗 서브넷 `snet-web`과 NSG `nsg-linux-web`을 구성했습니다. |
| Load Balancer | 구성 확인 | Standard Regional Public Load Balancer `lb-linux-web`에 프런트엔드 `fe-ip-linux-web`, 공용 IP 리소스 `pip-linux-web`, HTTP 부하 분산 규칙·상태 프로브(Health Probe)·아웃바운드 규칙을 구성했습니다. |
| 백엔드 | 구성 확인 | 개별 공용 IP가 없는 `vm-web01`과 `vm-web02`를 가용 영역(Zone) 1과 2에 나누어 배치하고 `be-pool-linux-web`에 등록했습니다. |
| 관리 접속 | 접속 검증 | 기존 랩실 SSH 키를 유지한 채 집 WSL용 별도 ED25519 공개키를 두 VM에 추가하고, 집에서 프런트엔드 TCP 50001 → `vm-web01:22`, TCP 50002 → `vm-web02:22` 경로로 접속했습니다. |
| 웹·장애 실험 | 동작 검증 | Load Balancer TCP 80 요청에서 두 백엔드의 응답을 확인하고, `vm-web01`의 HTTP 403·firewalld 차단과 `vm-web02`의 Nginx 중지·복구를 시험했습니다. |
| Ansible | 구성·멱등성·Drift 복구 완료 | 두 VM에 웹 서버 구성을 적용하고 전체 재실행에서 `changed=0`을 확인했습니다. `vm-web02`의 Nginx Drift도 같은 Playbook으로 복구했습니다. |

실제 공용 IP와 SSH 허용 원본 IP의 숫자 값은 공개 저장소에 남기지 않았습니다. 실제 Inventory는 Git에서 제외하고 공개용 예제에는 Placeholder만 사용합니다.

## 직접 확인한 결과

- 두 VM에 개별 공용 IP를 부여하지 않고 Load Balancer의 인바운드 NAT 포트를 통해 `azureuser`로 SSH 접속했습니다.
- 두 VM은 모두 `Standard_B2as_v2`(2 vCPU, 8 GiB)이며 개별 공용 IP가 없습니다. `vm-web01`은 Rocky Linux 9.8, `10.10.1.4/24`, Zone 1, NIC `vm-web01938_z1`이고, `vm-web02`는 Rocky Linux 9.8, `10.10.1.5/24`, Zone 2, NIC `vm-web02737_z2`입니다.
- 두 VM 모두 외부 HTTPS 요청에서 `HTTP/2 200`을 받았습니다. 두 VM이 외부로 통신할 때 Load Balancer의 프런트엔드 공용 IP가 사용되는 것도 확인했습니다.
- 집 WSL용 별도 ED25519 SSH 키를 생성하고 기존 랩실 키를 제거하지 않은 채 두 VM에 집 공개키를 추가했습니다. 집 네트워크에서 Inbound NAT Rule의 TCP 50001·50002를 통해 각 VM에 접속했습니다.
- `vm-web02`에 Nginx를 설치해 `active`·`enabled`, TCP 80 `LISTEN`, localhost HTTP 200, `WEB02 - Zone 2` 응답 및 `sudo nginx -t` 성공을 확인했습니다. 두 VM의 `firewalld`가 `inactive`였다는 기록은 2026-07-26 시험 당시의 결과입니다.
- 2026-07-27에는 `vm-web01`의 Nginx가 `active`·`enabled`이고 TCP 80을 수신하며 localhost HTTP 200을 반환하는 것을 확인했습니다. 2026-08-02에는 Ansible `--become`을 통해 `nginx -t`를 실행해 설정 문법이 정상임을 추가로 확인했습니다.
- Load Balancer의 공용 TCP 80으로 반복 요청했을 때 WEB01과 WEB02 응답이 모두 나타났습니다.
- 랩실 노트북과 집 데스크톱에서 `ansible.builtin.ping`을 실행해 두 VM의 SSH 인증, NAT 관리 경로, 원격 Python 및 Ansible Module 실행을 확인했습니다.
- `web-baseline.yml`을 실행해 두 VM의 Nginx가 실행 중이고 localhost HTTP가 200임을 검증했습니다. 최종 결과는 두 VM 모두 `ok=3`, `changed=0`, `unreachable=0`, `failed=0`이었습니다.
- `web-config.yml`을 두 VM에 적용한 뒤 전체 재실행에서 각각 `ok=13`, `changed=0`, `unreachable=0`, `failed=0`과 종료 코드 0을 확인했습니다. `serial: 1` 설정에 따라 한 대씩 순차 처리됐습니다.
- `vm-web02`의 Nginx를 중지해 Drift를 만든 뒤 `web-config.yml`을 다시 실행했을 때 Nginx 시작 Task만 변경됐고, 최종 전체 재실행은 두 VM 모두 `changed=0`이었습니다.

## 핵심 장애 대응 결과

`vm-web01`의 `index.html` 권한을 `000`으로 바꿔 HTTP 계층 장애를 발생시켰습니다. Nginx는 `active`, TCP 80은 `LISTEN`을 유지했지만 localhost 요청은 HTTP 403을 반환했습니다. 이후 외부 요청에서는 WEB01이 사라지고 WEB02만 응답했으며, 권한을 `644`로 복구하자 localhost가 HTTP 200으로 돌아오고 Load Balancer 응답에 WEB01이 다시 나타났습니다.

2026-07-27에는 `vm-web01`의 내부 HTTP 서비스가 정상인 상태에서 firewalld의 public Zone이 HTTP를 허용하지 않도록 했습니다. 차단 중에는 외부 반복 요청에 WEB02만 응답했고, public Zone에 HTTP 서비스를 runtime과 permanent 설정으로 허용한 뒤 WEB01이 다시 나타났습니다.

2026-08-04에는 `vm-web02`의 Nginx를 중지하자 localhost 연결이 실패하고 외부 요청에서 잠시 `REQUEST FAILED`가 나타난 뒤 WEB01만 응답했습니다. Portal에서는 `vm-web02`가 `Down`, 전체 상태가 50%로 표시됐습니다. Ansible로 복구한 뒤 외부 응답에 WEB02가 다시 나타났고 Portal에서도 두 VM이 `Up`, 전체 상태가 100%로 돌아왔습니다.

Portal의 장애 상태와 복구 후 상태를 각각 확인했지만 정확한 전환 시간과 50:50 트래픽 분산은 측정하지 않았습니다. HTTP 403 시험도 감시 중간에 공백이 있어 제외까지 걸린 시간을 확인하지 못했습니다.

## 현재 상태

구축·장애 시험·Ansible 멱등성 및 Drift 복구·운영 Runbook·Postmortem을 완료했습니다. 이 저장소는 검증을 마친 최종 트리만 담은 공개 제출용 스냅샷이며, 원본 전체 이력과 로컬 운영정보는 Private으로 보존합니다. 핵심 내용은 제출용 PDF 요약본으로 정리합니다.

정확한 50:50 분산, 실제 Availability Zone 장애 시험과 다중 Region 구성은 미검증 한계 및 선택 확장 항목으로 남깁니다.

## 상세 문서와 증거 링크

상세 기록:

- [아키텍처와 현재 구성](docs/architecture.md)
- [웹 서비스 운영 Runbook](docs/operations-runbook.md)
- [2026-08-04 Nginx Drift 통제 시험 Postmortem](docs/postmortem-2026-08-04-nginx-drift.md)
- [날짜별 프로젝트 로그](PROJECT_LOG.md)
- [트러블슈팅 기록](TROUBLESHOOTING.md)
- [Linux 기본 상태 및 SSH 검증 명령 기록](commands/01-linux-baseline.md)
- [Nginx 및 HTTP 장애 전환·복구 명령 기록](commands/2026-07-26-nginx-http-failover.md)
- [NSG 및 firewalld HTTP 장애 전환·복구 명령 기록](commands/2026-07-27-firewalld-http-failover.md)
- [Ansible 관리 경로 및 웹 서버 Baseline 검증](commands/2026-08-02-ansible-baseline.md)
- [`vm-web01` 웹 서버 구성 및 멱등성 검증](commands/2026-08-03-ansible-web-config-vm-web01.md)
- [`vm-web02` 웹 서버 구성 및 멱등성 검증](commands/2026-08-04-ansible-web-config-vm-web02.md)
- [`vm-web02` Nginx Drift 발생·복구 검증](commands/2026-08-04-ansible-nginx-drift-recovery.md)
- [Ansible Baseline 검증 Playbook](ansible/playbooks/web-baseline.yml)
- [Ansible 웹 서버 구성 Playbook](ansible/playbooks/web-config.yml)
- [서버별 웹 페이지 Template](ansible/templates/index.html.j2)
- [Load Balancer HTTP 반복 점검 스크립트](scripts/monitor-lb-http.sh)

증거 이미지:

- 기본 인프라: [01 Load Balancer 개요](screenshots/01-load-balancer-overview.png), [02 프런트엔드 IP 연결](screenshots/02-frontend-ip-configuration.png), [03 NSG 인바운드 규칙](screenshots/03-nsg-inbound-rules.png), [04 백엔드 풀의 VM 두 대](screenshots/04-backend-pool-two-vms.png)
- 관리 접속: [05 인바운드 NAT 포트 매핑](screenshots/05-inbound-nat-port-mappings.png), [06 접속 위치별 NSG 규칙](screenshots/06-nsg-inbound-rules-multi-location.png)
- firewalld 장애 시험: [07 로컬 서비스 정상과 HTTP 미허용](screenshots/07-firewalld-block-local-service-healthy.png), [08 WEB01 제외 관찰](screenshots/08-firewalld-web01-excluded.png), [09 WEB01 재포함 관찰](screenshots/09-firewalld-web01-reincluded.png)
- Ansible 및 Nginx Drift 복구: [10 두 VM 멱등성](screenshots/10-ansible-two-vm-idempotency.png), [11 WEB02 중지와 WEB01 단독 응답](screenshots/11-drift-web01-only.png), [12 Portal의 WEB02 Down](screenshots/12-probe-vm-web02-unhealthy.png), [13 Ansible 복구와 WEB02 재등장](screenshots/13-ansible-drift-recovery.png), [14 Portal의 두 VM Up](screenshots/14-probe-vm-web02-recovered.png)
