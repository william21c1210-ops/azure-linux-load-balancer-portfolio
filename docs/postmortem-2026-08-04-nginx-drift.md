# 통제된 vm-web02 Nginx Drift 시험 Postmortem

## 1. 요약

2026-08-04에 실제 고객 장애가 아닌 통제 시험으로 `vm-web02`의 Nginx를 의도적으로 중지했다. 서버 내부 상태, 단일 클라이언트의 Load Balancer 외부 응답과 Azure Portal Backend Health를 함께 관찰한 뒤, 기존 `web-config.yml`을 수동 실행해 원하는 상태로 복구했다.

시험 중 `REQUEST FAILED` 구간을 관찰했으며 이를 숨기지 않는다. 이번 결과는 모든 사용자에 대한 무중단, 정확한 전환 시간 또는 실제 Zone 장애 내성을 입증하지 않는다.

## 2. 시험 목적

- 두 Backend의 정상 기준선을 먼저 확보한다.
- 한 Backend의 Nginx 실행 상태만 원하는 상태에서 벗어나게 한다.
- 서버 내부, 외부 사용자 경로와 Portal에서 영향을 교차 확인한다.
- 같은 Ansible Playbook으로 복구하고 최종 멱등성을 확인한다.

## 3. 영향 범위

- 변경 대상은 `vm-web02` 한 대의 Nginx 실행 상태였다.
- `vm-web02`의 TCP 80과 localhost HTTP가 동작하지 않았다.
- 단일 외부 클라이언트에서 잠시 `REQUEST FAILED`가 나타난 뒤 WEB01만 관찰됐다.
- 실제 고객 트래픽이나 모든 클라이언트의 영향을 측정한 시험은 아니다.

## 4. 정상 기준선

Drift 생성 전에 두 VM 전체에 구성 Playbook을 실행했다.

```bash
ansible-playbook --diff playbooks/web-config.yml
```

```text
vm-web01 : ok=13 changed=0 unreachable=0 failed=0
vm-web02 : ok=13 changed=0 unreachable=0 failed=0
Ansible exit code: 0
```

Playbook이 관리하는 항목은 두 VM 모두 원하는 상태였으며 불필요한 변경은 없었다.

## 5. 변경 내용

`vm-web02`의 Nginx 서비스만 다음 명령으로 중지했다.

```bash
ansible vm-web02 \
  --become \
  -m ansible.builtin.systemd_service \
  -a "name=nginx state=stopped"
```

Ansible이 관리하는 구성 파일이나 다른 서비스는 이 명령으로 변경하지 않았다.

## 6. 관찰 타임라인

| 시각 | 관찰 내용 | 확인 범위 |
| --- | --- | --- |
| 시험 전 | 두 VM 모두 `changed=0`, `failed=0`, `unreachable=0` | Ansible 정상 기준선 |
| `11:21:33` | WEB02 마지막 관찰 | 단일 클라이언트 외부 응답 |
| `11:21:34`~`11:21:40` | `REQUEST FAILED` 관찰 | 단일 클라이언트 외부 응답 |
| `11:21:41` | WEB01-only 응답 시작 | 단일 클라이언트 외부 응답 |
| 정확한 시각 미기록 | `vm-web01` `Up`, `vm-web02` `Down`, 전체 건강도 50% | Azure Portal |
| 정확한 시각 미기록 | `web-config.yml`로 `vm-web02` 복구 | Ansible |
| `11:28:33` | WEB02 재등장 | 단일 클라이언트 외부 응답 |
| 정확한 시각 미기록 | 두 VM `Up`, 전체 건강도 100% | Azure Portal |
| 복구 검증 단계 | 두 VM 모두 최종 `changed=0` | Ansible 전체 재실행 |

위 시각은 클라이언트 출력에서 관찰한 값이다. Azure Load Balancer 내부의 Probe 판정 또는 Backend 제외·재포함 시각으로 일반화하지 않는다. 스크린샷 사이의 모든 연속 출력이 보존된 것도 아니므로 관찰되지 않은 구간의 응답을 단정하지 않는다.

## 7. 탐지

세 경로를 사용해 상태를 확인했다.

- 서버 내부: Nginx `inactive`, TCP 80 `NOT_LISTENING`, localhost HTTP 연결 실패
- 외부 사용자 경로: `REQUEST FAILED` 이후 WEB01-only 응답
- Azure Portal: `vm-web01` `Up`, `vm-web02` `Down`, 전체 건강도 50%

Portal의 50%는 두 Backend의 건강도 집계이며 트래픽 분산 비율이 아니다.

## 8. 직접 원인

통제 시험에서 `vm-web02`의 Nginx 서비스를 의도적으로 중지한 것이 직접 원인이다. Azure 서비스 장애나 예기치 않은 운영 장애가 아니었다.

## 9. 영향이 발생한 이유

Nginx가 중지되면서 `vm-web02`의 TCP 80 Listener와 localhost HTTP 응답이 사라져 해당 Backend가 HTTP 요청에 응답할 수 없었다. 이후 WEB01-only 응답이 관찰되기 전 `REQUEST FAILED` 구간이 나타났다.

다만 Probe Interval·Threshold와 Azure 내부 판정 시각을 함께 기록하지 않았으므로 각 `REQUEST FAILED`의 정확한 Load Balancer 내부 원인까지 확정하지 않는다. Portal 화면의 일반 안내 문구를 NSG나 방화벽 장애의 증거로 해석하지도 않는다.

## 10. 복구

`vm-web02` 한 대에 기존 구성 Playbook을 다시 적용했다.

```bash
ansible-playbook --diff --limit vm-web02 playbooks/web-config.yml
```

`Start and enable nginx` Task만 변경됐고 나머지 관리 항목은 이미 원하는 상태였다.

```text
vm-web02 : ok=13 changed=1 unreachable=0 failed=0
Ansible exit code: 0
```

## 11. 복구 검증

- `nginx -t` 성공
- localhost HTTP 200
- 응답 본문에 `WEB02 - Zone 2` 포함
- 응답 본문에 `vm-web02` 포함
- 외부 감시에서 `11:28:33`에 WEB02 재등장
- Portal에서 두 VM `Up`, 전체 건강도 100%
- 최종 전체 재실행에서 두 VM 모두 `changed=0`, `unreachable=0`, `failed=0`, 종료 코드 0

## 12. 잘된 점

- 변경 전에 두 VM의 정상 기준선을 확보했다.
- 한 Backend의 Nginx 실행 상태만 변경했다.
- 서버 내부, 외부 사용자 경로와 Portal 상태를 함께 확인했다.
- 별도 복구 스크립트를 만들지 않고 기존 원하는 상태 Playbook을 사용했다.
- 복구 후 전체 재실행에서 `changed=0`을 확인했다.
- `REQUEST FAILED` 구간과 미검증 범위를 결과에 포함했다.

## 13. 개선할 점

- Probe Interval·Threshold와 Azure 내부 상태 전환 시각을 같은 시간축으로 기록하지 못했다.
- 단일 클라이언트에서만 외부 응답을 관찰했다.
- 사용자 경로에 HTTPS와 DNS가 없다.
- Health Probe가 전용 `/health` Endpoint가 아니라 `/`를 사용한다.
- 전환 구간에 `REQUEST FAILED`가 나타난 원인을 더 세밀하게 분리할 관찰 자료가 부족했다.

## 14. 후속 조치

| 조치 | 상태 |
| --- | --- |
| 반복 가능한 점검·복구 절차를 Runbook으로 정리 | 완료: [운영 Runbook](operations-runbook.md) |
| Probe 설정과 Portal·클라이언트 관찰을 같은 시간축으로 기록 | TODO |
| 여러 관찰 지점에서 동일 시험 비교 | 선택 개선안 |
| 전용 `/health` Endpoint 검토 | 선택 개선안 |
| HTTPS와 DNS 경로 검토 | 선택 개선안 |

HTTPS, DNS와 전용 Health Endpoint는 구현 완료 항목이 아니다.

## 15. 미검증 범위

- 모든 사용자에 대한 무중단 전환
- 정확한 50:50 트래픽 분산
- Azure 내부의 정확한 Backend 제외·재포함 시간
- 실제 Availability Zone 장애 내성
- 다중 Region 장애 전환
- HTTPS·DNS 사용자 경로
- 전용 Health Endpoint

## 16. 증거

- [Drift 생성 및 Ansible 복구 명령 기록](../commands/2026-08-04-ansible-nginx-drift-recovery.md)
- [두 VM 정상 기준선](../screenshots/10-ansible-two-vm-idempotency.png)
- [Nginx 중지 상태와 외부 응답](../screenshots/11-drift-web01-only.png)
- [Portal의 vm-web02 Down 상태](../screenshots/12-probe-vm-web02-unhealthy.png)
- [Ansible 복구와 WEB02 재등장](../screenshots/13-ansible-drift-recovery.png)
- [Portal의 두 VM Up 상태](../screenshots/14-probe-vm-web02-recovered.png)
- [구성 Playbook](../ansible/playbooks/web-config.yml)
- [외부 HTTP 반복 점검 스크립트](../scripts/monitor-lb-http.sh)
- [2026-08-04 프로젝트 로그](../PROJECT_LOG.md#2026-08-04--두-vm-ansible-멱등성-및-vm-web02-nginx-drift-복구-검증)
