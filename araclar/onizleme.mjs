// Web önizlemesi: build/web klasörünü sunar, /api ve /mesaj-foto isteklerini Kadran sitesine iletir.
// Uygulama ile site aynı adresten açıldığı için oturum çerezi tarayıcıda kendiliğinden taşınır.
// Kullanım: node araclar/onizleme.mjs [kapı=3300] [site=http://localhost:3000]
import { createServer, request } from "node:http"
import { readFile, stat } from "node:fs/promises"
import { extname, join, normalize } from "node:path"

const KAPI = Number(process.argv[2] || 3300)
const SITE = new URL(process.argv[3] || "http://localhost:3000")
const KOK = join(process.cwd(), "build", "web")
const TUR = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json", ".png": "image/png", ".wasm": "application/wasm", ".ttf": "font/ttf", ".otf": "font/otf", ".css": "text/css", ".ico": "image/x-icon", ".svg": "image/svg+xml" }

createServer(async (istek, yanit) => {
  const yol = decodeURIComponent(new URL(istek.url, "http://x").pathname)
  if (yol.startsWith("/api/") || yol.startsWith("/mesaj-foto/")) {
    const ilet = request({ hostname: SITE.hostname, port: SITE.port, path: istek.url, method: istek.method, headers: { ...istek.headers, host: SITE.host } }, (s) => {
      yanit.writeHead(s.statusCode ?? 502, s.headers)
      s.pipe(yanit)
    })
    ilet.on("error", () => { yanit.writeHead(502); yanit.end("Site açık değil") })
    istek.pipe(ilet)
    return
  }
  let dosya = normalize(join(KOK, yol))
  if (!dosya.startsWith(KOK)) return yanit.writeHead(403).end()
  try { if ((await stat(dosya)).isDirectory()) dosya = join(dosya, "index.html") } catch { dosya = join(KOK, "index.html") }
  try {
    const icerik = await readFile(dosya)
    yanit.writeHead(200, { "Content-Type": TUR[extname(dosya)] ?? "application/octet-stream", "Cache-Control": "no-store" })
    yanit.end(icerik)
  } catch { yanit.writeHead(404).end() }
}).listen(KAPI, () => console.log(`Önizleme: http://localhost:${KAPI}  (site: ${SITE.origin})`))
