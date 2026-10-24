"use strict";

(() => {
  const pickupAction = document.getElementById("pickup-action");
  const openStatus = document.getElementById("open-status");
  const shareButton = document.getElementById("share-button");
  const shareStatus = document.getElementById("share-status");
  const shareFallback = document.getElementById("share-fallback");
  const shareLink = document.getElementById("share-link");
  const copyUriButton = document.getElementById("copy-uri-button");
  const shortcutUri = document.getElementById("shortcut-uri");
  const copyUriStatus = document.getElementById("copy-uri-status");
  const installButton = document.getElementById("install-button");
  const installStatus = document.getElementById("install-status");
  let installPrompt = null;

  pickupAction.addEventListener("click", () => {
    openStatus.textContent = "已请求唤起拼多多。若没有跳转，请用系统浏览器打开本页，并确认已安装、登录拼多多。";
  });

  async function copyIfAllowed(text) {
    if (!window.isSecureContext || !navigator.clipboard || !navigator.clipboard.writeText) {
      return false;
    }
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch {
      return false;
    }
  }

  function selectForManualCopy(field) {
    field.focus();
    field.select();
    field.setSelectionRange(0, field.value.length);
  }

  async function copyShareLink(url) {
    if (await copyIfAllowed(url)) {
      shareFallback.hidden = true;
      shareStatus.textContent = "链接已复制，可以粘贴发给同学。";
      return;
    }
    shareLink.value = url;
    shareFallback.hidden = false;
    shareStatus.textContent = "浏览器未允许自动复制，请长按下面的链接手动复制。";
    selectForManualCopy(shareLink);
  }

  shareButton.addEventListener("click", async () => {
    const pageUrl = new URL(window.location.href);
    pageUrl.hash = "";
    pageUrl.search = "";
    if (typeof navigator.share === "function") {
      try {
        await navigator.share({
          title: "取件直达",
          text: "打开拼多多取件页，少绕一圈。安卓与 iPhone 使用指南都在这里。",
          url: pageUrl.href
        });
        shareStatus.textContent = "分享操作已交给系统处理。";
        return;
      } catch (error) {
        if (error && error.name === "AbortError") {
          shareStatus.textContent = "已取消分享。";
          return;
        }
      }
    }
    await copyShareLink(pageUrl.href);
  });

  copyUriButton.addEventListener("click", async () => {
    if (await copyIfAllowed(shortcutUri.value)) {
      copyUriStatus.textContent = "取件页地址已复制。";
      return;
    }
    copyUriStatus.textContent = "浏览器未允许自动复制，请长按上方地址并选择复制。";
    selectForManualCopy(shortcutUri);
  });

  window.addEventListener("beforeinstallprompt", (event) => {
    const isStandalone = window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true;
    if (isStandalone) return;
    event.preventDefault();
    installPrompt = event;
    installButton.hidden = false;
  });

  installButton.addEventListener("click", async () => {
    if (!installPrompt) {
      installButton.hidden = true;
      return;
    }
    const prompt = installPrompt;
    installPrompt = null;
    installButton.disabled = true;
    try {
      await prompt.prompt();
      const choice = await prompt.userChoice;
      installStatus.textContent = choice.outcome === "accepted"
        ? "已接受浏览器的添加请求，结果请以手机系统提示为准。"
        : "已取消添加，仍可直接使用本页。";
    } catch {
      installStatus.textContent = "当前浏览器未能显示添加提示，可尝试浏览器菜单中的“添加到主屏幕”。";
    } finally {
      installButton.disabled = false;
      installButton.hidden = true;
    }
  });

  window.addEventListener("appinstalled", () => {
    installPrompt = null;
    installButton.hidden = true;
    installStatus.textContent = "浏览器报告此网页已添加到桌面。";
  });

  if ("serviceWorker" in navigator && window.isSecureContext) {
    navigator.serviceWorker.register("./sw.js", { scope: "./" }).catch((error) => {
      console.warn("取件直达：离线页面缓存未启用。", error);
    });
  }
})();
