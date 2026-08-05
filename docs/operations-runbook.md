# Azure Load Balancer Rocky Linux 웹 서비스 운영 Runbook

## 1. 범위와 전제

이 Runbook은 Azure Load Balancer 뒤의 Rocky Linux 웹 서버 `vm-web01`, `vm-web02`에서 HTTP 서비스 이상이 발생했을 때 확인·복구·재검증하는 절차다. 일반 운영 대응에서는 장애를 재현하기 위한 서비스 중지 명령을 실행하지 않는다.

작업자는 다음 조건을 충족해야 한다.

- Azure Portal에서 Load Balancer Backend Health, NSG와 Inbound NAT Rule을 확인할 수 있다.
- Control Node에 Ansible과 `ansible.posix` Collection이 준비돼 있다.
- Git에서 제외된 실제 Inventory와 SSH Key를 사용할 수 있다.
- 현재 관리 위치의 Source Public IP `/32`가 NSG의 SSH 허용 규칙과 일치한다.
- 실제 Load Balancer Public IP와 SSH Key 경로는 문서나 공개 로그에 남기지 않는다.

`web-config.yml`은 Nginx·firewalld·필수 패키지, public Zone, 서버별 페이지와 서비스 상태를 관리한다. `serial: 1`로 한 대씩 처리하며, 실패 시 이후 작업이 중단될 수 있으므로 항상 전체 Recap을 확인한다. Azure Load Balancer, NSG와 Health Probe 자체는 변경하지 않는다.

## 2. 서비스 경로와 관리 경로

서비스 경로:

```text
Browser / curl
  → Load Balancer Public Frontend TCP 80
  → lbr-http-80
  → be-pool-linux-web
  → 정상 Backend Nginx TCP 80
```

관리 경로:

```text
Control Node
  → Load Balancer Frontend TCP 50001 또는 50002
  → vm-web01 또는 vm-web02 TCP 22
  → SSH / Ansible
```

- TCP `50001` → `vm-web01:22`
- TCP `50002` → `vm-web02:22`

## 3. 작업 전 안전 확인

1. 변경 대상 VM 이름과 NAT Port를 다시 확인한다.
2. Azure Portal에서 다른 Backend가 `Up`인지 확인한다.
3. 외부 HTTP 감시를 별도 터미널에서 먼저 시작한다.
4. 실제 Inventory가 Git에서 제외돼 있고 현재 Control Node용 파일을 가리키는지 확인한다.
5. 두 Backend가 모두 비정상이거나 영향 범위를 구분할 수 없으면 변경하지 않고 [중단·에스컬레이션 조건](#12-중단에스컬레이션-조건)을 따른다.

외부 감시는 저장소 루트에서 실행한다.

```bash
cd ~/projects/azure-linux-load-balancer-lab
LB_IP='<LOAD_BALANCER_PUBLIC_IP>' \
  COUNT=60 \
  INTERVAL=2 \
  TIMEOUT=3 \
  ./scripts/monitor-lb-http.sh
```

`LB_IP`는 환경 변수로만 전달한다. 실행 오류에는 실제 주소가 표시될 수 있으므로 원본 로그를 마스킹하지 않은 채 공개 저장소에 올리지 않는다. 이 스크립트의 `REQUEST_FAILED`는 연결 또는 timeout 같은 `curl` 실패를 뜻하며, HTTP 4xx·5xx를 모두 실패로 판정하는 도구는 아니다.

## 4. 정상 기준선

모든 Ansible 명령은 `ansible/` 디렉터리에서 실행한다.

```bash
cd ~/projects/azure-linux-load-balancer-lab/ansible
ansible --version
ansible-inventory --graph
ansible webservers -m ansible.builtin.ping
ansible-playbook playbooks/web-baseline.yml
```

정상 기준은 다음과 같다.

- `ansible --version`에 현재 저장소의 `ansible.cfg`가 표시된다.
- Inventory의 `webservers` Group에 `vm-web01`, `vm-web02`만 나타난다.
- 두 VM의 `ansible.builtin.ping`이 `SUCCESS`, `pong`을 반환한다.
- Baseline Playbook에서 두 VM 모두 `ok=3 changed=0 unreachable=0 failed=0`이다.
- 외부 감시에서 WEB01과 WEB02 응답이 관찰된다.
- Portal Backend Health에서 두 VM이 `Up`이다.

Baseline Playbook은 Nginx 실행 상태와 localhost HTTP 200만 확인한다. 외부 Load Balancer, Portal Health와 서버별 본문은 별도로 확인한다.

## 5. 증상별 진단

다음 순서를 바꾸지 않고 영향 범위를 좁힌다.

1. **영향 범위:** 전체 서비스가 응답하지 않는지, WEB01 또는 WEB02 한 대만 보이지 않는지 확인한다.
2. **외부 Load Balancer HTTP:** `monitor-lb-http.sh`의 시간별 응답과 `REQUEST_FAILED`를 확인한다.
3. **Azure Portal Backend Health:** `hp-http-80`에서 각 Backend의 `Up`·`Down` 상태를 확인한다.
4. **Ansible 연결:** 대상 VM 또는 `webservers` Group에 `ansible.builtin.ping`을 실행한다. `UNREACHABLE`이면 즉시 [SSH/Ansible unreachable 대응](#9-sshansible-unreachable-대응)으로 분기하고, 성공한 경우에만 다음 Managed Node 점검을 계속한다.
5. **Nginx Service:** 대상 VM에서 실행·자동 시작 상태를 확인한다.
6. **TCP 80 LISTEN:** Nginx가 TCP 80을 수신하는지 확인한다.
7. **Nginx 설정:** `nginx -t`의 종료 상태와 성공 메시지를 확인한다.
8. **localhost HTTP:** 대상 VM 내부의 `/`가 HTTP 200인지 확인한다.
9. **firewalld:** public Zone의 runtime과 permanent 설정에 SSH·HTTP가 있는지 확인한다.
10. **NSG 관리 Source `/32`:** 현재 관리 위치의 Source Public IP와 SSH 허용 규칙이 일치하는지 Portal에서 확인한다.
11. **Inbound NAT Port Mapping:** TCP 50001·50002가 의도한 VM의 TCP 22에 연결되는지 Portal에서 확인한다.

다음 명령은 Control Node가 아니라 정확한 대상 VM에 SSH로 접속한 세션에서 실행한다.

```bash
systemctl is-active nginx
systemctl is-enabled nginx
sudo nginx -t
sudo ss -lntp 'sport = :80'
curl -sS --max-time 3 -o /dev/null -w '%{http_code}\n' http://localhost/
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=public --list-all
sudo firewall-cmd --permanent --zone=public --list-all
```

서버별 본문은 구성 Playbook의 검증 결과에서 `WEB01 - Zone 1`·`vm-web01` 또는 `WEB02 - Zone 2`·`vm-web02`가 포함됐는지 확인한다.

## 6. 단일 Backend 복구

다른 Backend가 정상이고 복구 대상을 명확히 구분한 경우에만 한 대씩 적용한다.

```bash
cd ~/projects/azure-linux-load-balancer-lab/ansible
ansible-playbook --syntax-check playbooks/web-config.yml
```

대상이 `vm-web01`일 때 다음 명령을 실행한다.

```bash
ansible-playbook --diff --limit vm-web01 playbooks/web-config.yml
```

또는 대상이 `vm-web02`일 때만 다음 명령을 사용한다.

```bash
ansible-playbook --diff --limit vm-web02 playbooks/web-config.yml
```

판정 기준:

- 대상 Host가 정확하다.
- `unreachable=0`, `failed=0`이다.
- `nginx -t`, localhost HTTP 200과 서버별 본문 검증이 성공한다.
- 변경된 Task가 관찰한 Drift와 일치한다.

Nginx 실행 상태만 복구하는 상황에서 다른 패키지·방화벽·Template까지 예상치 않게 변경되면 성공으로 선언하지 말고 Diff와 원인을 확인한다.

## 7. 두 Backend 전체 구성 재검증

단일 Backend 복구와 외부 재포함을 확인한 뒤 전체 구성을 재검증한다.

다음 명령은 읽기 전용 검사가 아니다. 두 Backend 중 Drift가 있는 항목을 즉시 원하는 상태로 변경하므로, 두 VM에 대한 변경 범위와 실행 승인을 확인한 경우에만 실행한다.

```bash
cd ~/projects/azure-linux-load-balancer-lab/ansible
ansible-playbook --diff playbooks/web-config.yml
```

현재 정상 상태의 성공 기준:

- `serial: 1`에 따라 두 Host가 각각 처리된다.
- Recap에 `vm-web01`, `vm-web02` 두 행이 모두 있다.
- 두 VM 모두 `changed=0`, `unreachable=0`, `failed=0`이다.

빈 Recap, 한 Host만 있는 Recap 또는 `changed>0`이면 멱등성 확인을 완료로 처리하지 않는다.

## 8. Load Balancer와 Health Probe 확인

Azure Portal에서 Load Balancer `lb-linux-web`의 Backend Health와 Probe `hp-http-80`을 확인한다.

- Backend별 `Up`·`Down` 상태를 외부 응답과 비교한다.
- 복구 후 두 VM이 `Up`인지 확인한다.
- Probe는 HTTP 80, Path `/`를 사용한다.
- Portal의 50%·100%는 Backend 건강도 집계이며 트래픽 분산 비율이 아니다.
- 외부 응답 변화 시각을 Azure 내부 판정 시각으로 기록하지 않는다.

Portal과 외부 감시 결과가 계속 다르면 작업을 확대하지 말고 시간, 대상, 관찰 결과를 보존한 뒤 에스컬레이션한다.

## 9. SSH/Ansible unreachable 대응

`UNREACHABLE` 또는 Ansible 종료 코드 4가 발생하면 구성 Playbook을 적용하지 않는다. 다음 순서로 확인한다.

1. `pwd`와 `ansible --version`으로 작업 디렉터리와 적용 중인 `ansible.cfg`를 확인한다.
2. `ansible-inventory --graph`로 Host 이름을 확인하고, Git에서 제외된 실제 Inventory에서 대상 NAT Port를 점검한다.
3. 현재 관리 Source Public IP와 NSG SSH 허용 Source `/32`가 일치하는지 확인한다.
4. Load Balancer Inbound NAT Rule의 50001·50002 Mapping을 확인한다.
5. SSH 사용자, 로컬 Key 선택과 Host Key 검증 상태를 확인한다. Key 경로와 Fingerprint는 공개 로그에 남기지 않는다.
6. 관리 접속이 복구된 뒤 정확한 대상 VM의 SSH 세션에서 `sshd`와 TCP 22 수신을 확인한다.

```bash
systemctl is-active sshd
systemctl is-enabled sshd
sudo ss -lntp 'sport = :22'
```

SSH를 `Any` 또는 Internet 전체에 허용하는 방식으로 해결하지 않는다. 관리 위치의 단일 Source Public IP `/32` 원칙을 유지한다.

## 10. Ansible failed 대응

`failed>0`, 종료 코드 2 또는 Task 오류가 발생하면 다음 순서로 분류한다.

1. 실패한 Task 이름과 오류 메시지를 확인한다.
2. `unreachable=0`인지 확인해 SSH 이후 Module 실행 실패인지 구분한다.
3. 실제 Inventory의 원격 Python 설정과 Managed Node의 Python 사용 가능 여부를 확인한다.
4. Control Node에 필요한 `ansible.posix` Collection이 준비돼 있는지 확인한다.
5. Nginx, firewalld와 `python3-firewall` 등 실패 Task의 패키지 의존성을 확인한다.
6. Check Mode가 선행 패키지를 실제로 설치하지 않는 한계인지 확인한다.
7. 실제 적용 전에 대상 Host, 다른 Backend 상태와 예상 변경 범위를 다시 확인한다.

알려진 사례로, 초기 `vm-web02` Check Mode에서는 `python3-firewall` 설치가 예측만 되고 후속 firewalld Task가 Python Binding을 불러오지 못해 실패했다. 이 경우도 오류를 확인하지 않은 채 무조건 실제 적용하지 않는다. 다른 `failed` 오류를 같은 원인으로 일반화하지 않는다.

## 11. 복구 후 검증

복구 후 다음 항목을 모두 확인한다.

- Ansible Recap: `failed=0`, `unreachable=0`
- `nginx -t` 성공
- localhost HTTP 200
- 대상 VM의 서버별 제목과 Hostname 포함
- 외부 감시에서 복구 Backend 응답 재등장
- Portal Backend Health에서 복구 대상 `Up`
- 마지막 전체 구성 재실행에서 두 VM 모두 `changed=0`

한 항목이라도 확인하지 못하면 복구 완료로 표시하지 않는다.

## 12. 중단·에스컬레이션 조건

다음 상황에서는 추가 변경을 중단하고 현재 출력과 시각을 보존한다.

- 작업 전 두 Backend가 모두 비정상이다.
- Inventory가 비었거나 예상하지 않은 Host가 나타난다.
- `ansible.builtin.ping`이 실패하거나 `UNREACHABLE`이 발생한다.
- 실제 적용에서 `failed>0`, `unreachable>0` 또는 비정상 종료가 발생한다.
- 단일 Backend 복구에서 예상하지 않은 패키지·방화벽·Template 변경이 나타난다.
- 복구 후 Portal과 외부 응답이 일치하지 않는다.
- NSG를 Internet 전체에 열거나 Load Balancer Rule을 변경해야만 진행할 수 있다.
- 실제 Public IP, Key, Fingerprint 또는 계정·구독 정보가 로그에 포함됐다.

에스컬레이션 기록에는 발생 시각, 대상 VM, 실패 Task, Recap, 외부 응답과 Portal 상태만 남기고 비밀 값은 제거한다.

## 13. 보안 주의사항

- 실제 Load Balancer Public IP와 관리 Source Public IP를 저장소에 기록하지 않는다.
- SSH Private Key의 내용·경로, Host Key Fingerprint를 기록하지 않는다.
- Subscription ID, Tenant ID와 계정 정보를 기록하지 않는다.
- 실제 Inventory와 마스킹 전 실행 로그를 커밋하지 않는다.
- SSH Source는 관리 위치별 단일 `/32`만 허용하며 `Any` 또는 Internet 전체로 확대하지 않는다.
- 화면을 증거로 저장하기 전에 주소, Key 경로와 계정 정보를 확인한다.

## 14. 현재 한계

- 외부 관찰은 단일 클라이언트에서 수행했다.
- 정확한 Probe Interval·Threshold와 Azure 내부 전환 시각은 별도로 기록하지 않았다.
- 정확한 50:50 트래픽 분산과 모든 사용자에 대한 무중단을 검증하지 않았다.
- 실제 Availability Zone 장애와 다중 Region 동작을 시험하지 않았다.
- 사용자 경로에 HTTPS와 DNS가 없고 Probe는 전용 Health Endpoint가 아닌 `/`를 사용한다.

## 15. 관련 증거와 구현 파일

- [현재 아키텍처](architecture.md)
- [트러블슈팅 기록](../TROUBLESHOOTING.md)
- [Ansible 관리 경로와 Baseline 검증](../commands/2026-08-02-ansible-baseline.md)
- [`vm-web01` 구성 및 멱등성 검증](../commands/2026-08-03-ansible-web-config-vm-web01.md)
- [`vm-web02` 구성 및 멱등성 검증](../commands/2026-08-04-ansible-web-config-vm-web02.md)
- [`vm-web02` Nginx Drift 및 복구](../commands/2026-08-04-ansible-nginx-drift-recovery.md)
- [2026-08-04 Nginx Drift 통제 시험 Postmortem](postmortem-2026-08-04-nginx-drift.md)
- [Baseline Playbook](../ansible/playbooks/web-baseline.yml)
- [구성 Playbook](../ansible/playbooks/web-config.yml)
- [외부 HTTP 반복 점검 스크립트](../scripts/monitor-lb-http.sh)
- [Inbound NAT Port Mapping](../screenshots/05-inbound-nat-port-mappings.png)
- [NSG 접근 제어](../screenshots/06-nsg-inbound-rules-multi-location.png)
- [두 VM 구성 Playbook 멱등성](../screenshots/10-ansible-two-vm-idempotency.png)
