(() => {
  "use strict";

  const MOD = "/data/adb/modules/dsh_keepalive";
  const PKG = "io.github.ccch1mneyyy.dsh_app";
  const CTRL = "sh " + MOD + "/control.sh";
  const $ = (id) => document.getElementById(id);
  let state = {};

  function toast(msg) {
    try { if (window.ksu && ksu.toast) ksu.toast(String(msg)); } catch (_) {}
  }

  // KernelSU WebUI bridge: ksu.exec(command, optionsJson, callbackName)
  function exec(cmd) {
    return new Promise((resolve) => {
      if (!window.ksu || typeof ksu.exec !== "function") {
        resolve({ errno: -1, stdout: "", stderr: "KernelSU WebUI 桥不可用；请从 SukiSU 模块页打开" });
        return;
      }
      const cb = "dsh_cb_" + Math.random().toString(36).slice(2);
      let done = false;
      const finish = (r) => {
        if (done) return;
        done = true;
        delete window[cb];
        resolve(r);
      };
      window[cb] = (errno, stdout, stderr) => finish({ errno: Number(errno), stdout: stdout || "", stderr: stderr || "" });
      try {
        ksu.exec(cmd, "{}", cb);
      } catch (e) {
        finish({ errno: -1, stdout: "", stderr: String(e) });
      }
      setTimeout(() => finish({ errno: -1, stdout: "", stderr: "命令超时" }), 20000);
    });
  }

  async function load() {
    const res = await exec(CTRL + " status");
    if (res.errno !== 0) {
      $("badge").textContent = "读取失败";
      $("badge").className = "badge bad";
      $("meta").textContent = (res.stderr || res.stdout || "status failed").trim();
      return;
    }
    try {
      state = JSON.parse(res.stdout.trim());
    } catch (e) {
      $("badge").textContent = "解析失败";
      $("badge").className = "badge bad";
      $("meta").textContent = res.stdout.trim();
      return;
    }
    render();
  }

  function render() {
    const s = state;
    const appOk = !!s.app;
    const engOk = !!s.engine;
    const badge = $("badge");
    badge.className = "badge";
    if (appOk && engOk) { badge.textContent = "正常"; badge.classList.add("ok"); }
    else if (!appOk) { badge.textContent = "App 未运行"; badge.classList.add("bad"); }
    else { badge.textContent = "引擎未运行"; badge.classList.add("warn"); }

    $("app").textContent = appOk ? "运行中" : "未运行";
    $("engine").textContent = engOk ? "运行中" : "未运行";
    $("watchdog").textContent = s.watchdog ? "运行中" : "未运行";

    $("phantom").checked = !!s.phantom;
    $("doze").checked = !!s.doze;
    $("battery").checked = !!s.battery;
    $("swipe").checked = !!s.swipe;
    $("autocheck").checked = !!s.autocheck;
    $("interval").value = s.interval || 300;
    $("showAdvanced").checked = !!s.showAdvanced;

    $("phantomSetting").textContent = s.phantomSetting || "—";
    $("maxPhantom").textContent = s.maxPhantom || "—";
    $("bucket").textContent = s.bucket || "—";
    $("meta").textContent = "Doze: " + (s.dozeListed ? "已加入" : "未加入") +
      " · bucket " + (s.bucket || "?") + " · phantom " + (s.phantomSetting || "?");

    const locked = !!(s.swipe && s.battery && s.doze);
    const lock = $("lock");
    lock.textContent = locked ? "🔒" : "🔓";
    lock.classList.toggle("on", locked);

    $("advanced").classList.toggle("hidden", !s.showAdvanced);
  }

  async function setKey(key, value) {
    const res = await exec(CTRL + " set " + key + " " + value);
    if (res.errno !== 0) toast((res.stderr || res.stdout || "设置失败").trim());
    await load();
  }

  async function setLocked() {
    const locked = !!(state.swipe && state.battery && state.doze);
    if (locked) {
      await setKey("swipe", 0);
      toast("已关闭防清理锁定");
    } else {
      await setKey("swipe", 1);
      await setKey("battery", 1);
      await setKey("doze", 1);
      await setKey("phantom", 1);
      toast("已锁定：Doze + 省电无限制 + phantom + 自动拉起");
    }
  }

  $("lock").addEventListener("click", setLocked);

  [["phantom", "phantom"], ["doze", "doze"], ["battery", "battery"],
   ["swipe", "swipe"], ["autocheck", "autocheck"]].forEach(([id, key]) => {
    $(id).addEventListener("change", (e) => setKey(key, e.target.checked ? 1 : 0));
  });

  $("showAdvanced").addEventListener("change", (e) => {
    state.showAdvanced = e.target.checked ? 1 : 0;
    render();
    setKey("show_advanced", e.target.checked ? 1 : 0);
  });

  $("saveInterval").addEventListener("click", async () => {
    let v = parseInt($("interval").value, 10);
    if (!Number.isFinite(v)) v = 300;
    v = Math.max(30, Math.min(3600, v));
    $("interval").value = v;
    await setKey("interval", v);
    toast("检查间隔已设为 " + v + " 秒");
  });

  $("apply").addEventListener("click", async () => {
    const res = await exec(CTRL + " apply");
    toast(res.errno === 0 ? "已应用全部设置" : (res.stderr || "应用失败").trim());
    await load();
  });

  $("check").addEventListener("click", async () => {
    const res = await exec(CTRL + " check");
    const out = (res.stdout || res.stderr || "").trim();
    toast(out || "检查完成");
    await load();
  });

  $("launch").addEventListener("click", async () => {
    const res = await exec(CTRL + " launch");
    toast(res.errno === 0 ? "已尝试启动 DSH" : (res.stderr || "启动失败").trim());
    setTimeout(load, 1200);
  });

  $("sys").addEventListener("click", () => {
    exec("am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:" + PKG);
    toast("已打开系统应用设置");
  });

  $("showLog").addEventListener("click", async () => {
    const box = $("logBox");
    if (!box.classList.contains("hidden")) {
      box.classList.add("hidden");
      $("showLog").textContent = "查看最近日志";
      return;
    }
    const res = await exec(CTRL + " log");
    box.textContent = (res.stdout || res.stderr || "暂无日志").trim();
    box.classList.remove("hidden");
    $("showLog").textContent = "收起日志";
  });

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", load);
  } else {
    load();
  }
})();
