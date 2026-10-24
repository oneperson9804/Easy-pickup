"use strict";

// Change this version when the offline page shell changes.
const SHELL_VERSION = "v1.0.0";
const CACHE_PREFIX = "pickup-direct-shell:" + self.registration.scope + ":";
const CACHE_NAME = CACHE_PREFIX + SHELL_VERSION;
const SCOPE_URL = new URL("./", self.location.href);
const REQUIRED_FILES = ["./", "./index.html", "./styles.css", "./app.js", "./manifest.webmanifest", "./icons/icon.svg"];
const OPTIONAL_FILES = ["./icons/icon-192.png", "./icons/icon-512.png", "./icons/apple-touch-icon.png"];
const ALLOWED_URLS = new Set(REQUIRED_FILES.concat(OPTIONAL_FILES).map((path) => new URL(path, SCOPE_URL).href));

self.addEventListener("install", (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await cache.addAll(REQUIRED_FILES.map((path) => new URL(path, SCOPE_URL).href));
    await self.skipWaiting();
  })());
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter((name) => name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME).map((name) => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (url.origin !== SCOPE_URL.origin || url.search || !ALLOWED_URLS.has(url.href)) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    try {
      const response = await fetch(request);
      if (response.ok && response.type === "basic" && !response.redirected) {
        await cache.put(request, response.clone());
      }
      return response;
    } catch {
      const cached = await cache.match(request);
      return cached || Response.error();
    }
  })());
});
