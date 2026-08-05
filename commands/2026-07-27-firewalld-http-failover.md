# 2026-07-27 — NSG Source 갱신 및 firewalld HTTP 장애·복구

## 목적

랩실의 공용 IPv4 변경으로 발생한 SSH timeout을 NSG Source `/32` 관점에서 확인하고, `vm-web01`의 로컬 HTTP 서비스가 정상인 상태에서 호스트 방화벽이 외부 HTTP 경로에 미치는 영향을 시험합니다.

실제 Load Balancer 공용 IP와 랩실 공용 IP는 기록하지 않습니다. SSH 키, Host Key Fingerprint 및 구독 ID도 이 기록에 포함하지 않습니다.

## 랩실 SSH 접근 복구

이전에 접속했던 것과 같은 랩실 Wi-Fi에서 Load Balancer Frontend TCP 50001을 통한 `vm-web01` SSH가 timeout 됐습니다. 현재 랩실 공용 IPv4를 확인해 기존 `allow-ssh-myip` Source `/32`와 비교한 결과 두 값이 달랐습니다.

`allow-ssh-myip`의 Source를 현재 랩실 공용 IPv4 `/32`로 갱신한 뒤 다음 공개용 형태의 경로로 다시 접속했습니다.

```bash
ssh -p 50001 azureuser@<LOAD_BALANCER_PUBLIC_IP>
```

재접속 결과는 성공이었습니다. 로그인 과정에서 post-quantum 관련 경고가 표시됐지만 로그인이 완료됐으므로 이번 timeout의 원인은 아니었습니다. 같은 Wi-Fi를 사용하더라도 공용 IP가 계속 유지된다고 가정하지 않습니다.

## firewalld 설치와 사전 설정

처음에는 `firewall-offline-cmd` 명령이 존재하지 않았습니다. 다음 명령으로 패키지 설치 여부를 확인하고, 설치되지 않은 경우 `firewalld`를 설치했습니다.

```bash
rpm -q firewalld || sudo dnf install -y firewalld
```

설치 후에는 `firewall-offline-cmd`를 사용할 수 있었습니다. NetworkManager 연결 프로필과 firewalld 출력은 서로 다른 확인 범위이므로 다음과 같이 구분합니다.

| 확인 위치 | 실제 결과 |
| --- | --- |
| NetworkManager 연결 프로필 | `System eth0`의 `connection.zone`을 `public`으로 지정 |
| `sudo firewall-cmd --get-active-zones` | `public` Zone에 `eth0`, `eth1` 표시 |
| `sudo firewall-cmd --zone=public --list-all` | `interfaces` 항목에 `eth0` 표시 |

`eth1`에도 `connection.zone=public`을 직접 설정한 것으로 해석하지 않습니다.

NetworkManager 설정과 firewalld 상태 확인에 실제로 사용한 명령은 다음과 같습니다.

```bash
sudo nmcli connection modify "System eth0" connection.zone public
nmcli -g connection.zone connection show "System eth0"

sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=public --list-all
```

firewalld 활성화 전 public Zone의 서비스와 포트 설정은 다음과 같았습니다.

| 확인 항목 | 실제 결과 |
| --- | --- |
| Services | `cockpit`, `dhcpv6-client`, `ssh` |
| HTTP Service | 허용되지 않음 |
| `80/tcp` Port | 허용되지 않음 |
| SSH | 허용 상태 확인 |

SSH 허용 상태를 확인한 뒤 다음 명령으로 firewalld를 활성화했습니다.

```bash
sudo systemctl enable --now firewalld
```

이후 firewalld는 `active`, `enabled` 상태였습니다.

## HTTP 차단 상태

`vm-web01` 내부에서는 다음 상태를 확인했습니다.

| 확인 항목 | 실제 결과 |
| --- | --- |
| Nginx 실행 상태 | `active` |
| Nginx 자동 시작 상태 | `enabled` |
| TCP 80 | `LISTEN` |
| localhost HTTP | 200 |
| `sudo nginx -t` | 미확인 |
| firewalld public Zone의 HTTP | Service와 `80/tcp` 모두 미허용 |

[로컬 서비스 정상 및 firewalld HTTP 미허용 증거](../screenshots/07-firewalld-block-local-service-healthy.png)에서 Nginx, TCP 80, localhost HTTP와 방화벽 설정을 함께 확인할 수 있습니다.

랩실 WSL에서 Load Balancer 공용 TCP 80으로 반복 요청했을 때 WEB02 응답만 나타났습니다. 이 결과는 WEB01 내부 서비스는 정상이지만 호스트 방화벽이 외부 HTTP와 Health Probe 접근을 차단해 WEB01이 트래픽 대상에서 제외된 동작과 일치합니다.

[WEB01 제외 중 외부 반복 요청 증거](../screenshots/08-firewalld-web01-excluded.png)는 관찰 구간에 WEB02만 응답한 사실을 보여 줍니다. 이 화면만으로 Portal의 Probe 상태나 정확한 제외 시각을 확인할 수는 없습니다.

## HTTP 허용과 복구

현재 실행 중인 방화벽에서 HTTP를 즉시 복구하기 위해 runtime 설정에 HTTP Service를 추가했습니다. firewalld 재시작 또는 VM 재부팅 후에도 HTTP 허용을 유지하기 위해 permanent 설정에도 추가했습니다.

```bash
sudo firewall-cmd --zone=public --add-service=http
sudo firewall-cmd --zone=public --add-service=http --permanent
```

추가 후 `query-service=http` 결과는 runtime과 permanent에서 모두 `yes`였습니다. localhost HTTP도 200을 유지했습니다.

Load Balancer 공용 TCP 80 반복 요청에서 WEB01과 WEB02 응답이 다시 나타났습니다. 이를 통해 방화벽 복구 후 WEB01이 트래픽 대상에 재포함된 동작을 외부 응답에서 확인했습니다. 정확한 50:50 분산을 확인한 결과는 아닙니다.

[HTTP 허용 및 WEB01 재포함 증거](../screenshots/09-firewalld-web01-reincluded.png)는 runtime·permanent HTTP 허용과 복구 후 WEB01 재등장을 보여 줍니다.

## 재사용 가능한 반복 요청

이번 시험에 사용한 반복 `curl` 흐름을 다음 스크립트로 재사용할 수 있게 정리했습니다.

```bash
LB_IP=<LOAD_BALANCER_PUBLIC_IP> ./scripts/monitor-lb-http.sh
```

- `LB_IP`는 환경 변수로만 전달합니다.
- 각 결과는 `HH:MM:SS | 응답` 형식으로 출력하며, 요청 실패 시 `HH:MM:SS | REQUEST_FAILED`를 출력합니다.
- 스크립트와 저장소에는 실제 IP를 저장하지 않습니다.
- 실행 로그는 공용 IP를 마스킹하기 전에 공개 저장소에 커밋하지 않습니다.
- `curl -sS`의 실행 중 오류 메시지에는 전달한 주소가 표시될 수 있습니다.

이 스크립트는 시험 후 반복 점검을 위해 정리한 것으로, 스크린샷에 보이는 기존 명령을 이 파일이 대신 실행했다고 기록하지 않습니다.

## 별도 Nginx 중지 시험

작업 중 `vm-web01`의 Nginx를 잠시 중지했다가 복구하는 시험도 수행했습니다. 일시적인 `REQUEST_FAILED`, WEB02 전환 및 WEB01 복귀를 관찰했지만, 정확한 서비스 제어 명령 원문과 전환 시간은 이 기록에 제공되지 않았습니다. 이번 체크포인트의 주 장애 사례는 firewalld의 HTTP 차단입니다.

## 검증 범위와 한계

- HTTP 403 시험은 웹 문서 권한에 따른 애플리케이션 계층 장애입니다.
- 이번 시험은 localhost HTTP 200이 유지된 상태의 호스트 방화벽 계층 장애입니다.
- 외부 반복 응답에서 WEB01 제외·재포함과 일치하는 동작을 확인했습니다.
- Azure Portal의 정확한 `Healthy`·`Unhealthy` 표시와 정확한 제외·재포함 시각은 확인하지 않았습니다.
- 정상 응답을 정확한 50:50 분산으로 검증하지 않았습니다.

## 관련 기록

- [2026-07-27 프로젝트 로그](../PROJECT_LOG.md#2026-07-27--랩실-nsg-source-갱신-및-firewalld-http-장애복구-검증)
- [트러블슈팅 기록](../TROUBLESHOOTING.md)
- [반복 HTTP 점검 스크립트](../scripts/monitor-lb-http.sh)
