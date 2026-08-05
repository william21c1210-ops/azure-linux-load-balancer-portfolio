# 2026-08-04 — vm-web02 Nginx Drift 및 Ansible 복구

## 목적

두 VM이 원하는 상태에 있는지 확인한 뒤 `vm-web02`의 Nginx를 수동으로 중지해 Drift를 만들고, `web-config.yml`이 서비스 상태를 복구하는지 서버 내부·외부 응답·Azure Portal Health Probe에서 확인했다.

실제 Load Balancer Public IP, SSH 허용 Source IP, SSH Key 경로는 기록하지 않는다.

## 정상 기준선

Drift 생성 전 두 VM 전체에 구성 Playbook을 실행했다. `serial: 1` 설정에 따라 `vm-web01`, `vm-web02` 순서로 한 대씩 처리됐다.

```bash
ansible-playbook --diff playbooks/web-config.yml
```

```text
vm-web01 : ok=13 changed=0 unreachable=0 failed=0
vm-web02 : ok=13 changed=0 unreachable=0 failed=0
Ansible exit code: 0
```

[두 VM 전체 멱등성 증거](../screenshots/10-ansible-two-vm-idempotency.png)에서 두 호스트의 `changed=0`을 확인할 수 있다.

## Drift 생성

`vm-web02`의 Nginx를 수동으로 중지했다. Ansible이 관리하는 구성 파일이나 다른 서비스는 변경하지 않고 Nginx 실행 상태만 원하는 상태에서 벗어나게 했다.

실제로 실행한 명령은 다음과 같다.

```bash
ansible vm-web02 \
  --become \
  -m ansible.builtin.systemd_service \
  -a "name=nginx state=stopped"
```

## 서버 내부 증상

Drift 생성 후 `vm-web02`에서 다음 결과를 확인했다.

- Nginx: `inactive`
- TCP 80: `NOT_LISTENING`
- localhost HTTP: 연결 실패

## 외부 사용자 경로 영향

Load Balancer 외부 반복 요청에서는 잠시 `REQUEST FAILED`가 나타난 뒤 WEB01만 응답했다. 이 관찰은 단일 클라이언트의 요청 결과이며 완전한 무중단 전환을 의미하지 않는다.

[Drift 상태 외부 응답 증거](../screenshots/11-drift-web01-only.png)에는 서버 내부 증상과 외부 응답 변화가 함께 기록돼 있다.

## Portal Health Probe 상태

Azure Portal의 `hp-http-80` 상태에서 다음 결과를 확인했다.

- `vm-web01`: `Up`
- `vm-web02`: `Down`
- 전체 상태: 인스턴스의 50% 정상

이 50%는 두 백엔드의 Health Probe 집계이며 트래픽이 정확히 50:50으로 분산됐다는 의미가 아니다.

- [vm-web02 Down 상태 증거](../screenshots/12-probe-vm-web02-unhealthy.png)

## Ansible 복구

구성 Playbook을 `vm-web02`에 다시 실행했다.

```bash
ansible-playbook --diff --limit vm-web02 playbooks/web-config.yml
```

`Start and enable nginx` Task만 변경됐고 나머지 항목은 이미 원하는 상태였다.

```text
vm-web02 : ok=13 changed=1 unreachable=0 failed=0
Ansible exit code: 0
```

복구 실행 안에서 다음 검증도 성공했다.

- `nginx -t` 성공
- localhost HTTP 200
- 응답 본문에 `WEB02 - Zone 2` 포함
- 응답 본문에 `vm-web02` 포함

## 외부 재포함

복구 후 Load Balancer 외부 반복 요청에서 WEB02가 다시 관찰됐다. [Ansible Drift 복구 증거](../screenshots/13-ansible-drift-recovery.png)에는 Nginx Task의 변경과 WEB02 재등장이 함께 기록돼 있다.

## Portal 100% 정상 복귀

복구 후 Azure Portal에서 두 백엔드가 모두 `Up`이고 전체 상태가 인스턴스의 100% 정상인 것을 확인했다.

- [두 백엔드 Up 상태 증거](../screenshots/14-probe-vm-web02-recovered.png)

## 최종 전체 멱등성

복구 뒤 두 VM 전체에 구성 Playbook을 다시 실행했다.

```text
vm-web01 : ok=13 changed=0 unreachable=0 failed=0
vm-web02 : ok=13 changed=0 unreachable=0 failed=0
Ansible exit code: 0
```

최종 실행에서도 두 VM 모두 불필요한 변경이 없었다.

## 관찰된 한계

- Probe가 `vm-web02`를 제외하고 다시 포함한 내부 판정 시각을 초 단위로 완전히 측정하지 않았다.
- 외부 응답은 단일 클라이언트에서 관찰했으므로 모든 사용자에 대한 무중단을 보장하지 않는다.
- Portal의 50%·100% 표시는 백엔드 건강도이며 정확한 트래픽 분산 비율이 아니다.
- 실제 Availability Zone 장애 내성과 다중 Region 동작은 검증하지 않았다.

## 증거 링크

- [두 VM 전체 멱등성](../screenshots/10-ansible-two-vm-idempotency.png)
- [Drift 상태와 WEB01-only 관찰](../screenshots/11-drift-web01-only.png)
- [Portal의 vm-web02 Down 상태](../screenshots/12-probe-vm-web02-unhealthy.png)
- [Ansible 복구와 WEB02 재등장](../screenshots/13-ansible-drift-recovery.png)
- [Portal의 두 VM Up 상태](../screenshots/14-probe-vm-web02-recovered.png)
- [구성 Playbook](../ansible/playbooks/web-config.yml)
- [서버별 웹 페이지 Template](../ansible/templates/index.html.j2)
- [2026-08-04 프로젝트 로그](../PROJECT_LOG.md#2026-08-04--두-vm-ansible-멱등성-및-vm-web02-nginx-drift-복구-검증)
