# 2026-08-02 Ansible 관리 경로 및 웹 서버 Baseline 검증

## 목표

랩실 노트북과 집 데스크톱을 Ansible Control Node로 사용해 Azure Load Balancer의 Inbound NAT Port를 거쳐 두 Rocky Linux VM을 관리할 수 있는지 확인한다. 이후 서버 설정을 변경하기 전에 Nginx 서비스와 localhost HTTP 상태가 정상인지 읽기 전용 Playbook으로 검증한다.

## 구성 원칙

- 실제 Load Balancer Public IP, SSH Private Key, 관리 위치의 Source IP는 저장소에 기록하지 않는다.
- 공개용 `hosts.example.ini`에는 Placeholder만 둔다.
- 실제 접속 정보는 Git에서 제외된 `hosts.lab.ini`, `hosts.home.ini`에 둔다.
- `hosts.local.ini` 심볼릭 링크가 현재 Control Node에 맞는 실제 Inventory를 가리키도록 한다.
- 두 VM은 같은 Load Balancer Public IP를 사용하지만 Frontend Port `50001`, `50002`로 구분한다.

```text
Control Node
  └─ Load Balancer Public IP
       ├─ TCP 50001 → vm-web01:22
       └─ TCP 50002 → vm-web02:22
```

## 실제 수행 내용

### 1. Inventory 구조 확인

```bash
ansible-inventory --graph
```

확인된 구조:

```text
@all:
  |--@ungrouped:
  |--@webservers:
  |  |--vm-web01
  |  |--vm-web02
```

### 2. Ansible 관리 연결 확인

```bash
ansible webservers -m ansible.builtin.ping
```

랩실 노트북과 집 데스크톱에서 모두 두 VM의 응답을 확인했다.

```text
vm-web01 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
vm-web02 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

이 `ping`은 ICMP Echo가 아니라 SSH 접속, 원격 Python 실행, Ansible Module 실행 가능 여부를 확인한다.

Managed Node의 Python 경로는 두 VM 모두 `/usr/bin/python3.9`로 명시했다.

### 3. sudo 사용 및 Nginx 설정 문법 확인

```bash
ansible vm-web01 \
  --become \
  -m ansible.builtin.command \
  -a 'nginx -t'
```

실제 결과:

```text
vm-web01 | CHANGED | rc=0 >>
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

`rc=0`과 두 성공 메시지로 `vm-web01`의 Nginx 설정 문법이 정상임을 확인했다. `command` Module은 명령이 상태를 변경했는지 자동 판단하지 못하므로 `CHANGED`가 표시됐지만, `nginx -t`는 설정을 적용하거나 서비스를 재시작하지 않았다.

### 4. Baseline Playbook 문법 검사

```bash
ansible-playbook \
  --syntax-check \
  playbooks/web-baseline.yml
```

실제 결과:

```text
playbook: playbooks/web-baseline.yml
```

### 5. 두 웹 서버의 현재 상태 검증

```bash
ansible-playbook playbooks/web-baseline.yml
```

Playbook은 다음 세 작업을 수행한다.

1. `service_facts`로 서비스 상태 수집
2. `assert`로 `nginx.service`가 `running`인지 확인
3. `uri`로 각 VM의 `http://localhost/`가 HTTP 200을 반환하는지 확인

실제 최종 결과:

```text
PLAY RECAP
vm-web01 : ok=3 changed=0 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
vm-web02 : ok=3 changed=0 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

## 검증 결과

- 랩실 노트북과 집 데스크톱 모두 두 Azure VM을 Ansible로 관리할 수 있다.
- Inventory가 `vm-web01`, `vm-web02`를 올바르게 구분한다.
- SSH Key 인증, Inbound NAT Port Mapping, 원격 Python, Ansible Module 실행 경로가 정상이다.
- `--become`을 사용한 원격 sudo 실행이 정상이다.
- `vm-web01`의 Nginx 설정 문법 검사가 성공했다.
- 두 VM의 Nginx 서비스가 실행 중이다.
- 두 VM의 localhost HTTP 응답이 200이다.
- Baseline Playbook은 상태 확인만 수행했으므로 `changed=0`이다.

## 이번 단계에서 변경하지 않은 것

- Nginx Package와 Service 설정
- 웹 페이지 내용
- firewalld 설정
- Azure Load Balancer, NSG, Health Probe 설정

이번 단계의 목적은 자동화 적용 전 정상 상태를 기준선으로 남기는 것이었다.

## 후속 결과

이 Baseline을 기준으로 구성 Playbook을 두 VM에 적용하고 멱등성과 Drift 복구를 후속 검증했다.

- [`vm-web01` 구성 적용 및 멱등성 검증](2026-08-03-ansible-web-config-vm-web01.md)
- [`vm-web02` 구성 적용 및 멱등성 검증](2026-08-04-ansible-web-config-vm-web02.md)
- [`vm-web02` Nginx Drift 및 Ansible 복구](2026-08-04-ansible-nginx-drift-recovery.md)
