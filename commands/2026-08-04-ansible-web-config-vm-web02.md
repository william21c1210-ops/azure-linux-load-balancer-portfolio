# 2026-08-03~04 — vm-web02 Ansible 구성 적용 및 멱등성 검증

## 목적

`vm-web02`에 Nginx, firewalld, 서버별 웹 페이지 구성을 적용하고, 같은 Playbook을 다시 실행했을 때 불필요한 변경이 없는지 확인했다.

실제 Load Balancer Public IP, SSH 허용 Source IP, SSH Key 경로는 기록하지 않는다.

## Check Mode 한계

첫 Check Mode에서는 `python3-firewall`을 포함한 필수 패키지 설치 Task가 변경 예정으로 표시됐다. Check Mode는 패키지를 실제로 설치하지 않으므로, 다음 `ansible.posix.firewalld` Task가 Python firewall binding을 불러오지 못해 실패했다.

```bash
ansible-playbook --check --diff --limit vm-web02 playbooks/web-config.yml
```

```text
vm-web02 : ok=3 changed=1 unreachable=0 failed=1
Ansible exit code: 2
```

관리 대상에는 도달했으므로 Inventory나 SSH 문제가 아니다. 같은 실행 안에서 선행 패키지 설치에 의존하는 Task는 Check Mode만으로 전체 실행을 완전히 재현하지 못할 수 있음을 확인했다.

## 첫 실제 적용

Check Mode 결과를 확인한 뒤 실제 적용을 실행했다.

```bash
ansible-playbook --diff --limit vm-web02 playbooks/web-config.yml
```

변경된 항목은 다음 다섯 가지였다.

1. Nginx, firewalld와 `python3-firewall`을 관리하는 필수 패키지 Task
2. permanent public Zone의 HTTP 서비스 허용
3. 기본 인터페이스의 permanent public Zone 연결
4. firewalld 시작 및 자동 시작 설정
5. `vm-web02`용 웹 페이지 Template

```text
vm-web02 : ok=13 changed=5 unreachable=0 failed=0
```

후속 검증도 성공했다.

- `nginx -t` 성공
- localhost HTTP 200
- 응답 본문에 `WEB02 - Zone 2` 포함
- 응답 본문에 `vm-web02` 포함

## 관리 네트워크 변경과 unreachable

이동 중 관리 Source Public IP가 NSG Source `/32`와 달라졌을 때 `vm-web02`는 `unreachable=1`로 종료됐고 Ansible exit code는 4였다. 실제 주소는 기록하지 않는다.

랩실로 복귀한 뒤 `ansible.builtin.ping`에 성공해 관리 경로가 다시 동작하는 것을 확인했다. 이 사례는 모듈 실행 중 발생한 Check Mode의 `failed=1`과, SSH 관리 경로에 도달하지 못한 `unreachable=1`의 차이를 보여 준다.

유사한 원인과 복구 절차는 [기존 NSG Source `/32` 트러블슈팅 기록](../TROUBLESHOOTING.md#2026-07-27--랩실-nsg-source-32-불일치로-인한-ssh-timeout)에 정리돼 있어 별도 사건으로 중복 작성하지 않는다.

## 두 번째 실행 changed=0

2026-08-04에 같은 Playbook을 `vm-web02`에 다시 실행했다.

```bash
ansible-playbook --diff --limit vm-web02 playbooks/web-config.yml
```

```text
vm-web02 : ok=13 changed=0 unreachable=0 failed=0
Ansible exit code: 0
```

Nginx 설정, localhost HTTP 200과 `vm-web02` 서버별 본문 검증도 다시 성공했다.

## 판정

`vm-web02`의 첫 실제 적용과 후속 검증에 성공했고, 두 번째 실행에서 `changed=0`을 확인했다. Check Mode 실패는 관리 연결 문제가 아니라 실제로 설치되지 않은 Python firewall binding에 의존한 후속 Task의 한계였다.

- [Check Mode 의존성 실패 트러블슈팅](../TROUBLESHOOTING.md#2026-08-03--ansible-check-mode에서-python3-firewall-미설치로-인한-firewalld-task-실패)
- [두 VM 전체 멱등성 및 Drift 복구 기록](2026-08-04-ansible-nginx-drift-recovery.md)
