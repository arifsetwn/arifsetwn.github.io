# Deploy otomatis Hugo ke VPS dengan Dokploy

Tutorial ini menjalankan website Hugo sebagai container Nginx di VPS yang dikelola Dokploy.
Setiap push ke branch `main` di GitHub memicu build dan redeploy otomatis.

> Contoh repository: `arifsetwn/arifsetwn.github.io`
> 
> Model ini memakai **Dockerfile dari source GitHub**, bukan branch `master` berisi file hasil build. Branch `main` menjadi satu-satunya source of truth.

## Arsitektur

```text
Push ke GitHub/main
        ↓ webhook Dokploy
Dokploy clone repository
        ↓ Dockerfile multi-stage
Hugo build → /public
        ↓
Nginx container → domain HTTPS di VPS
```

## 1. Prasyarat

- VPS Ubuntu/Debian dengan IP publik.
- Dokploy sudah terpasang dan dapat diakses melalui dashboard.
- Repository GitHub berisi source Hugo dan file `Dockerfile` di root.
- DNS domain sudah dapat diarahkan ke IP VPS.

Jangan menaruh password VPS, token GitHub, atau secret lain di `config.yml`, `Dockerfile`, atau repository.

## 2. File deployment di repository

Repository ini sudah memiliki:

- `Dockerfile`: build Hugo, lalu menyalin hasilnya ke Nginx.
- `.dockerignore`: mengecualikan `.git`, `public/`, dan cache Hugo.

Dockerfile yang digunakan:

```dockerfile
FROM hugomods/hugo:exts AS build
WORKDIR /src
COPY . .
RUN hugo --minify --cleanDestinationDir --destination /public

FROM nginx:1.27-alpine
COPY --from=build /public/ /usr/share/nginx/html/
EXPOSE 80
```

Image `hugomods/hugo:exts` dipakai karena tema/aset dapat memerlukan Hugo Extended.

## 3. Hubungkan GitHub ke Dokploy

Di dashboard Dokploy:

1. Buka **Settings → Git Providers** atau menu GitHub yang tersedia pada versi Dokploy Anda.
2. Tambahkan koneksi GitHub.
3. Berikan akses hanya ke repository yang diperlukan bila GitHub menawarkan pilihan repository.
4. Simpan koneksi dan pastikan repository `arifsetwn/arifsetwn.github.io` dapat dipilih.

Nama menu dapat sedikit berbeda antarversi Dokploy. Prinsipnya: Dokploy harus memiliki izin clone repository dan menerima event push.

## 4. Buat aplikasi di Dokploy

1. Buat **Project** baru, misalnya `arif-academic`.
2. Tambahkan **Application**.
3. Pilih source dari GitHub.
4. Isi konfigurasi:

| Field | Nilai |
|---|---|
| Repository | `arifsetwn/arifsetwn.github.io` |
| Branch | `main` |
| Build Type | `Dockerfile` |
| Dockerfile Path | `./Dockerfile` |
| Build Context | `.` |
| Container Port | `80` |

5. Simpan konfigurasi.
6. Jalankan **Deploy** manual pertama kali.

Jika build gagal, buka log build. Error Hugo biasanya berarti versi/theme/submodule atau konfigurasi repository belum tersedia di build context.

## 5. Hubungkan domain dan HTTPS

1. Buka aplikasi → **Domains**.
2. Tambahkan domain, misalnya `arifsetiawan.id` atau subdomain `www.arifsetiawan.id`.
3. Set target container port ke `80`.
4. Pastikan DNS memiliki record:

```text
A     @      IP_VPS
A     www    IP_VPS
```

Atau untuk subdomain:

```text
A     www    IP_VPS
```

5. Tunggu DNS terpropagasi.
6. Aktifkan sertifikat Let's Encrypt/HTTPS dari Dokploy.
7. Buka domain menggunakan HTTPS dan pastikan homepage, foto, stylesheet, serta halaman `/tentang/`, `/riset/`, `/pengajaran/`, dan `/kontak/` tampil.

Jangan menambahkan port container `80` ke URL publik. Reverse proxy Dokploy yang menghubungkan domain ke container.

## 6. Aktifkan auto-deploy dari GitHub

Di aplikasi Dokploy:

1. Buka tab **Deployments**.
2. Aktifkan auto-deploy bila tersedia.
3. Salin **Webhook URL** aplikasi.
4. Di GitHub buka **Settings → Webhooks → Add webhook**.
5. Isi:

| Field | Nilai |
|---|---|
| Payload URL | Webhook URL dari Dokploy |
| Content type | `application/json` |
| Which events | `Just the push event` |
| Active | dicentang |

6. Simpan webhook.

Jika Dokploy menyediakan tombol atau konfigurasi **Auto Deploy** langsung dari Git provider, gunakan konfigurasi bawaan itu dan jangan membuat webhook kedua.

## 7. Uji alur otomatis

Buat perubahan kecil pada source, misalnya isi halaman, lalu:

```bash
git checkout main
git add content/ config.yml
git commit -m "content: update academic website"
git push origin main
```

Verifikasi berurutan:

1. GitHub menerima commit.
2. GitHub webhook menunjukkan status `200` pada delivery terakhir.
3. Dokploy membuat deployment baru.
4. Build Docker selesai tanpa error.
5. Container berstatus running.
6. Domain menampilkan perubahan.

Jangan push hasil build `public/` sebagai source aplikasi Dokploy. Dokploy harus checkout `main` dan membangun ulang image dari Dockerfile.

## 8. Checklist production

- [ ] Repository Dokploy menunjuk ke branch `main`.
- [ ] `Dockerfile` berada di root repository.
- [ ] Build context adalah root repository (`.`).
- [ ] Container port adalah `80`.
- [ ] Domain DNS menunjuk ke IP VPS.
- [ ] HTTPS aktif.
- [ ] Webhook hanya satu dan aktif.
- [ ] Push ke `main` memicu deployment.
- [ ] Tidak ada token/password di repository.
- [ ] Backup konfigurasi Dokploy dan VPS tersedia.

## Troubleshooting

### Push GitHub tidak memicu deployment

- Periksa **GitHub → Settings → Webhooks → Recent Deliveries**.
- Pastikan payload dikirim ke Webhook URL Dokploy yang benar.
- Pastikan branch webhook adalah `main` melalui konfigurasi aplikasi Dokploy.
- Pastikan auto-deploy aktif.
- Jangan membuat dua webhook yang sama-sama memicu deployment.

### Build gagal karena Hugo atau theme

- Pastikan theme tersedia sebagai submodule atau file repository biasa.
- Jika memakai submodule, Dokploy harus clone submodule atau repository harus menyimpan theme secara langsung.
- Jalankan build lokal dengan Docker:

```bash
docker build --progress=plain -t arif-academic:local .
docker run --rm -p 8080:80 arif-academic:local
```

Buka `http://localhost:8080` untuk memeriksa hasilnya.

### Domain menampilkan halaman lama

- Pastikan deployment terbaru berstatus sukses.
- Periksa bahwa domain terhubung ke aplikasi Dokploy yang benar.
- Bersihkan cache browser/CDN.
- Periksa DNS dengan `dig +short domain-anda.tld`.

### Container hidup tetapi halaman 404

- Pastikan `hugo` menghasilkan `/public/index.html`.
- Pastikan `COPY --from=build /public/ /usr/share/nginx/html/` tidak berubah.
- Pastikan base URL di `config.yml` sesuai domain produksi.

## Referensi

- [Dokploy — Applications](https://docs.dokploy.com/docs/core/applications)
- [Dokploy — Auto Deploy](https://docs.dokploy.com/docs/core/auto-deploy)
- [Dokploy — GitHub](https://docs.dokploy.com/docs/core/github)
- [Dokploy — Going Production](https://docs.dokploy.com/docs/core/applications/going-production)
- [Hugo Docker images](https://hugomods.com/docs/docker/)
