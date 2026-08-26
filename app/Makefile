# Poetry Mate APP 常用命令
#
# 注意: 本机 http_proxy 指向公司 Squid,会劫持 flutter tester 的本地 WebSocket,
# 必须先卸载代理变量(见 test 目标)。分析器不受影响。

.PHONY: analyze test run clean

analyze:
	flutter analyze

test:
	env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY flutter test

run:
	env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY flutter run

clean:
	flutter clean
