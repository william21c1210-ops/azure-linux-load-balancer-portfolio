# 2026-08-03 — Ansible 구성 Playbook 1차 적용 (`vm-web01`)

## 목표

두 백엔드를 동시에 변경하지 않고 `vm-web01` 한 대에만 구성 Playbook을 먼저 적용해 작업 범위와 검증 절차를 확인한다.

## 적용 전 확인

다음 순서로 진행했다.

```bash
ansible-playbook --syntax-check playbooks/web-config.yml
ansible-playbook --check --diff --limit vm-web01 playbooks/web-config.yml
```

Check Mode에서는 다음 세 항목이 변경 대상으로 표시됐다.

- 기본 인터페이스의 permanent public Zone 연결
- 기본 인터페이스의 active public Zone 연결
- `/usr/share/nginx/html/index.html` 교체

Fact 참조는 향후 Ansible 변경에 대비해 다음 형식으로 수정했다.

```yaml
interface: "{{ ansible_facts['default_ipv4']['interface'] }}"
```

수정 후 YAML 오류와 Deprecation 경고 없이 Check Mode를 통과했다.

## 실제 적용

```bash
ansible-playbook --diff --limit vm-web01 playbooks/web-config.yml
```

실제 변경은 두 건이었다.

1. 기본 인터페이스를 permanent public Zone에 연결
2. 서버 식별용 HTML을 Template으로 배포

active Zone 연결과 SSH·HTTP 서비스 허용, Nginx·firewalld 실행 상태는 이미 원하는 상태여서 `ok`로 처리됐다.

최종 결과:

```text
vm-web01 : ok=13 changed=2 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

후속 검증도 성공했다.

- `nginx -t` 성공
- localhost HTTP 200
- 응답 본문에 `WEB01 - Zone 1` 포함
- 응답 본문에 `vm-web01` 포함

## 1차 적용 판정

`web-config.yml`은 `vm-web01` 한 대에서 실제 적용과 후속 검증까지 성공했다. 이 단계에서는 두 번째 실행 결과를 별도로 확인해 멱등성을 판단하기로 했다.

## 2차 실행 — 멱등성 검증

### 목적

`vm-web01`에 구성 Playbook을 다시 실행해, 이미 원하는 상태인 서버에서 불필요한 변경이 발생하지 않는지 확인했다.

### 실행 전 문제와 수정

처음에는 저장소 루트에서 Playbook을 실행해 `ansible/ansible.cfg`가 로드되지 않았다.

```text
No inventory was parsed
skipping: no hosts matched
```

이 실행은 관리 대상에 도달하지 않았으므로 멱등성 결과에 포함하지 않았다. `ansible/` 디렉터리에서 같은 Playbook을 다시 실행했다.

```bash
ansible-playbook --diff --limit vm-web01 playbooks/web-config.yml
```

### 실제 결과

두 번째 실행에서는 변경이 발생하지 않았다.

```text
vm-web01 : ok=13 changed=0 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

후속 검증도 다시 성공했다.

- `nginx -t` 성공
- localhost HTTP 200
- 응답 본문에 `WEB01 - Zone 1` 포함
- 응답 본문에 `vm-web01` 포함

### 판정

첫 적용에서 필요한 두 변경을 수행한 뒤 두 번째 실행이 `changed=0`으로 끝났으므로, `vm-web01`에 대한 구성 Playbook의 멱등성을 확인했다.

두 번째 백엔드 적용과 Drift 복구는 다음 기록으로 분리했다.

- [`vm-web02` 구성 적용 및 멱등성 검증](2026-08-04-ansible-web-config-vm-web02.md)
- [`vm-web02` Nginx Drift 및 Ansible 복구](2026-08-04-ansible-nginx-drift-recovery.md)
