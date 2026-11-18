# 1Panel 适配版镜像

镜像：`ghcr.io/fearless743/openresty:1.31.9.1-1panel`

它与标准版的区别：内置了 1Panel 的 `1pwaf` WAF 程序文件
（`/usr/local/openresty/1pwaf/*.lua`、`libraries/*.so`，以及 LuaJIT 的
`lfs.so` / `lsqlite3.so`）。1Panel 运行时仍会挂载它自己的 `nginx.conf`、
站点配置和 `1pwaf/data`。

## 使用方式

1. 在 1Panel 里找到现有的 OpenResty 应用目录
   （`/opt/1panel/apps/openresty/openresty/`），**先备份整个目录**。
2. 把本目录的 `docker-compose.yml` 放到该应用目录下，覆盖原有 compose
   （或用 1Panel 的「容器编排 / 自定义编排」粘贴）。
3. 保留原有的 `.env`（含 `CONTAINER_NAME`、`WEBSITE_DIR` 等变量）、`conf/`、
   `log/`、`root/`、`modules/`、`1pwaf/data/` 和站点目录，不要改动。
4. 拉镜像并重建：

   ```bash
   docker pull ghcr.io/fearless743/openresty:1.31.9.1-1panel
   cd /opt/1panel/apps/openresty/openresty
   docker compose up -d --force-recreate
   ```

5. 验证：

   ```bash
   docker exec -it <容器名> openresty -v          # openresty/1.31.9
   docker exec -it <容器名> openresty -t          # syntax is ok
   docker exec -it <容器名> ls /usr/local/openresty/1pwaf/init.lua
   ```

## 注意事项

- 如果你在 `1panel/modules/` 里放过按旧版 nginx（1.31.8）编译的第三方
  动态模块 `.so`，换成 1.31.9 后可能因 ABI 不兼容而加载失败；默认安装
  下这个目录是空的，不受影响。
- 1pwaf 的 `.so` 来自 1Panel 1.31.8.1 镜像、按当时的 LuaJIT 编译。LuaJIT
  2.1 通常 ABI 稳定，但升级后请通过上面的 `openresty -t` 和一条实际请求
  确认 WAF 规则正常工作。
- 需要关闭 WAF 的话，删掉宿主机 `conf/nginx.conf` 中的
  `include /usr/local/openresty/1pwaf/data/conf/waf.conf;` 即可。
