/**
 * ─────────────────────────────────────────────────────────────────────
 *  Claude AI — Backend Auth Google Apps Script (kode.gs)
 * ─────────────────────────────────────────────────────────────────────
 *
 *  Fitur:
 *   • register       → simpan user pending + kirim kode 6-digit ke email
 *   • verify         → validasi kode, promote pending → verified
 *   • login          → cek email + password hash
 *   • resend         → kirim ulang kode verifikasi
 *   • profile        → get profile by uid
 *   • updateProfile  → update nama / avatar
 *   • socialUpsert   → (M16) upsert user hasil Firebase OAuth (Google/Facebook),
 *                       auto-verified, tanpa password
 *
 *  Data disimpan di **Google Sheet** yang di-bind ke GAS ini. Sheet
 *  `users` kolom:
 *    uid | email | name | passwordHash | verified | code | codeExpiresAt |
 *    createdAt | avatarUrl | provider
 *
 *  Deploy:
 *   1. Buka https://script.google.com → New project → paste file ini.
 *   2. Klik Deploy → New deployment → Web app:
 *        - Execute as: Me
 *        - Who has access: Anyone
 *      → copy URL "https://script.google.com/macros/s/xxxx/exec"
 *   3. Set URL itu ke GitHub Secret `GAS_AUTH_URL` (dipakai workflow).
 *
 *  Password: client kirim SHA-256(salt||plain). Server tambah salt lokal
 *  sekali lagi sebelum simpan → double-salt.
 *
 *  ⚠️  M16 HOTFIX — Persistent Spreadsheet
 *  ─────────────────────────────────────────
 *  Bug sebelumnya: `SpreadsheetApp.getActiveSpreadsheet()` di STANDALONE
 *  script (bukan container-bound) return **null**. Fallback lama
 *  `SpreadsheetApp.create(...)` bikin spreadsheet BARU tiap invocation
 *  → register nulis ke sheet A, verify baca sheet B → error
 *  "Email belum terdaftar" padahal user baru daftar detik lalu.
 *
 *  Fix: simpan `spreadsheetId` di `PropertiesService.getScriptProperties()`
 *  first-run, dan reuse selamanya. Sheet ID persistent di Drive account
 *  pemilik script.
 * ─────────────────────────────────────────────────────────────────────
 */

const SHEET_NAME = 'users';
const APP_NAME   = 'Claude AI';
const APP_ACCENT = '#7C3AED';        // ungu brand
const APP_ACCENT2 = '#F97316';       // oranye brand
const SERVER_SALT = 'c48-server-salt-2026';   // ganti sekali saat first deploy
const CODE_TTL_MS = 15 * 60 * 1000;  // 15 menit
const SS_ID_PROP  = 'CLAUDE_AI_SS_ID';        // key di ScriptProperties

// ─── HTTP entry ──────────────────────────────────────────────────────
function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents || '{}');
    const action = body.action || '';
    let result;
    switch (action) {
      case 'register':      result = actionRegister(body);      break;
      case 'verify':        result = actionVerify(body);        break;
      case 'login':         result = actionLogin(body);         break;
      case 'resend':        result = actionResend(body);        break;
      case 'profile':       result = actionProfile(body);       break;
      case 'updateProfile': result = actionUpdateProfile(body); break;
      case 'socialUpsert':  result = actionSocialUpsert(body);  break;
      default: throw new Error('Unknown action: ' + action);
    }
    return jsonOut({ ok: true, ...result });
  } catch (err) {
    return jsonOut({ ok: false, error: String(err.message || err) });
  }
}

function doGet() {
  return jsonOut({ ok: true, service: APP_NAME + ' auth', ts: Date.now() });
}

// ─── Actions ─────────────────────────────────────────────────────────
function actionRegister(b) {
  const email = norm(b.email);
  const name  = (b.name || '').trim();
  const pass  = (b.password || '').trim();
  if (!email || !pass || !name) throw new Error('Email, password, dan nama wajib diisi.');
  if (!isEmail(email)) throw new Error('Format email tidak valid.');

  const sh = getSheet();
  const row = findRow(sh, email);
  const code = genCode();
  const expiresAt = Date.now() + CODE_TTL_MS;
  const hash = hashPassword(pass);

  if (row === -1) {
    sh.appendRow([
      Utilities.getUuid(), email, name, hash, false,
      code, expiresAt, new Date().toISOString(), '', 'email'
    ]);
  } else {
    const existing = readRow(sh, row);
    if (existing.verified) throw new Error('Email sudah terdaftar. Silakan login.');
    // Overwrite pending
    sh.getRange(row, 3).setValue(name);
    sh.getRange(row, 4).setValue(hash);
    sh.getRange(row, 6).setValue(code);
    sh.getRange(row, 7).setValue(expiresAt);
  }

  sendVerificationEmail(email, name, code);
  return { message: 'Kode verifikasi dikirim.' };
}

function actionResend(b) {
  const email = norm(b.email);
  const sh = getSheet();
  const row = findRow(sh, email);
  if (row === -1) {
    // M16 — pesan lebih ramah: kemungkinan sesi verify expired
    throw new Error('Sesi pendaftaran tidak ditemukan. Silakan daftar ulang.');
  }
  const r = readRow(sh, row);
  if (r.verified) throw new Error('Akun sudah terverifikasi. Silakan login.');
  const code = genCode();
  sh.getRange(row, 6).setValue(code);
  sh.getRange(row, 7).setValue(Date.now() + CODE_TTL_MS);
  sendVerificationEmail(email, r.name, code);
  return { message: 'Kode baru dikirim.' };
}

function actionVerify(b) {
  const email = norm(b.email);
  const code  = (b.code || '').trim();
  const sh = getSheet();
  const row = findRow(sh, email);
  if (row === -1) {
    // M16 — dulu bilang "Email belum terdaftar" — bikin bingung user
    // karena mereka emang lagi verify pendaftaran baru. Root cause
    // sebenernya: (a) session pendaftaran expired / dihapus, atau
    // (b) user salah ketik email dari step register.
    throw new Error(
      'Sesi verifikasi tidak ditemukan. Silakan kembali ke halaman daftar dan kirim ulang kode.'
    );
  }
  const r = readRow(sh, row);
  if (r.verified) throw new Error('Akun sudah terverifikasi. Silakan login.');
  if (String(r.code) !== code) throw new Error('Kode salah. Periksa email kamu lagi.');
  if (Number(r.codeExpiresAt) < Date.now()) {
    throw new Error('Kode sudah kadaluarsa. Tekan "Kirim ulang" untuk minta kode baru.');
  }
  sh.getRange(row, 5).setValue(true);
  sh.getRange(row, 6).setValue('');
  sh.getRange(row, 7).setValue('');
  return { uid: r.uid, email: r.email, name: r.name };
}

function actionLogin(b) {
  const email = norm(b.email);
  const pass  = (b.password || '').trim();
  const sh = getSheet();
  const row = findRow(sh, email);
  if (row === -1) throw new Error('Email tidak ditemukan. Daftar dulu ya.');
  const r = readRow(sh, row);
  if (!r.verified) throw new Error('Akun belum terverifikasi. Cek email untuk kode verifikasi.');
  if (r.passwordHash !== hashPassword(pass)) throw new Error('Password salah.');
  return { uid: r.uid, email: r.email, name: r.name, avatarUrl: r.avatarUrl };
}

/**
 * M16 — Upsert user hasil Firebase OAuth (Google / Facebook).
 * Body: { action:'socialUpsert', uid, email, name, avatarUrl?, provider }
 * Provider: 'google' | 'facebook'
 * Idempotent: kalau email sudah ada → update name/avatar/provider,
 * kalau belum → append row baru dengan `verified=true` (OAuth = trusted).
 */
function actionSocialUpsert(b) {
  const email    = norm(b.email);
  const uid      = (b.uid || '').trim();
  const name     = (b.name || '').trim() || 'User';
  const avatar   = (b.avatarUrl || '').trim();
  const provider = (b.provider || 'oauth').trim();
  if (!email || !uid) throw new Error('uid dan email wajib.');
  if (!isEmail(email)) throw new Error('Format email tidak valid.');

  const sh = getSheet();
  const row = findRow(sh, email);
  if (row === -1) {
    sh.appendRow([
      uid, email, name, '', true, '', '',
      new Date().toISOString(), avatar, provider
    ]);
    return { uid: uid, email: email, name: name, avatarUrl: avatar, created: true };
  }
  // Update fields tanpa nabrak password hash existing (kalau user ini
  // sebelumnya udah daftar via email/password).
  const r = readRow(sh, row);
  if (name)     sh.getRange(row, 3).setValue(name);
  if (!r.verified) sh.getRange(row, 5).setValue(true);
  if (avatar)   sh.getRange(row, 9).setValue(avatar);
  sh.getRange(row, 10).setValue(provider);
  return { uid: r.uid, email: r.email, name: name || r.name, avatarUrl: avatar || r.avatarUrl, created: false };
}

function actionProfile(b) {
  const uid = (b.uid || '').trim();
  const sh = getSheet();
  const data = sh.getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (data[i][0] === uid) {
      return { uid, email: data[i][1], name: data[i][2], avatarUrl: data[i][8] };
    }
  }
  throw new Error('User tidak ditemukan.');
}

function actionUpdateProfile(b) {
  const uid  = (b.uid || '').trim();
  const name = (b.name || '').trim();
  const av   = (b.avatarUrl || '').trim();
  const sh = getSheet();
  const data = sh.getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (data[i][0] === uid) {
      if (name) sh.getRange(i + 1, 3).setValue(name);
      if (av)   sh.getRange(i + 1, 9).setValue(av);
      return { message: 'Profile updated.' };
    }
  }
  throw new Error('User tidak ditemukan.');
}

// ─── Email (HTML) ────────────────────────────────────────────────────
function sendVerificationEmail(email, name, code) {
  const subject = APP_NAME + ' — Kode verifikasi kamu';
  const html = buildEmailHtml(name || 'there', code);
  GmailApp.sendEmail(email, subject, 'Kode verifikasi: ' + code, {
    htmlBody: html,
    name: APP_NAME
  });
}

function buildEmailHtml(name, code) {
  return `<!doctype html>
<html lang="id">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>${APP_NAME}</title>
  </head>
  <body style="margin:0;padding:0;background:#F5F5F7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#1D1D1F;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#F5F5F7;padding:40px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:480px;background:#FFFFFF;border-radius:14px;border:1px solid #E5E5EA;">
            <tr>
              <td style="height:4px;background:${APP_ACCENT};border-top-left-radius:14px;border-top-right-radius:14px;line-height:4px;font-size:0;">&nbsp;</td>
            </tr>
            <tr>
              <td style="padding:32px 32px 8px;">
                <p style="margin:0;font-size:13px;font-weight:600;letter-spacing:0.5px;color:${APP_ACCENT};text-transform:uppercase;">${APP_NAME}</p>
                <h1 style="margin:12px 0 0;font-size:22px;font-weight:600;color:#1D1D1F;letter-spacing:-0.3px;">Verifikasi email kamu</h1>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 32px 8px;">
                <p style="margin:0 0 20px;font-size:15px;line-height:1.6;color:#3C3C43;">
                  Halo ${escapeHtml(name)}, terima kasih sudah mendaftar di <b>${APP_NAME}</b>.
                  Masukkan kode berikut di aplikasi untuk menyelesaikan pendaftaran.
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:0 32px 8px;">
                <div style="background:#F5F5F7;border-radius:10px;padding:22px 16px;text-align:center;">
                  <div style="font-family:'SF Mono',Menlo,Consolas,monospace;font-size:34px;font-weight:600;letter-spacing:10px;color:#1D1D1F;">
                    ${escapeHtml(code)}
                  </div>
                  <p style="margin:10px 0 0;font-size:12px;color:#8E8E93;">Berlaku 15 menit</p>
                </div>
              </td>
            </tr>
            <tr>
              <td style="padding:20px 32px 28px;">
                <p style="margin:0;font-size:13px;line-height:1.6;color:#8E8E93;">
                  Kalau kamu tidak merasa mendaftar, abaikan email ini &mdash; akun tidak akan dibuat.
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 32px 24px;border-top:1px solid #E5E5EA;">
                <p style="margin:0;font-size:11px;line-height:1.5;color:#8E8E93;text-align:center;">
                  &copy; ${new Date().getFullYear()} ${APP_NAME}. Email otomatis, mohon tidak dibalas.
                </p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

// ─── Helpers ─────────────────────────────────────────────────────────

/**
 * M16 — Persistent spreadsheet resolver.
 *
 * Urutan lookup:
 *  1. Kalau script container-bound (dibuka dari sheet), pakai
 *     `getActiveSpreadsheet()`.
 *  2. Cek `ScriptProperties.CLAUDE_AI_SS_ID` — kalau ada, `openById`.
 *  3. Kalau nggak ada, create sekali → simpan ID-nya → pakai selamanya.
 *
 * Ini fix bug lama: standalone script + `getActiveSpreadsheet()==null`
 * bikin `create(...)` dipanggil TIAP request → sheet baru terus →
 * data user hilang antar-request. Sekarang ID di-persist.
 */
function getSheet() {
  const props = PropertiesService.getScriptProperties();
  let ss = SpreadsheetApp.getActiveSpreadsheet();
  if (!ss) {
    const savedId = props.getProperty(SS_ID_PROP);
    if (savedId) {
      try {
        ss = SpreadsheetApp.openById(savedId);
      } catch (_) {
        ss = null;
      }
    }
  }
  if (!ss) {
    ss = SpreadsheetApp.create(APP_NAME + ' Auth DB');
    props.setProperty(SS_ID_PROP, ss.getId());
  }
  let sh = ss.getSheetByName(SHEET_NAME);
  if (!sh) {
    sh = ss.insertSheet(SHEET_NAME);
    sh.appendRow([
      'uid','email','name','passwordHash','verified','code','codeExpiresAt',
      'createdAt','avatarUrl','provider'
    ]);
  }
  return sh;
}

function findRow(sh, email) {
  const data = sh.getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (String(data[i][1]).toLowerCase() === email) return i + 1;
  }
  return -1;
}

function readRow(sh, row) {
  const v = sh.getRange(row, 1, 1, 10).getValues()[0];
  return {
    uid: v[0], email: v[1], name: v[2], passwordHash: v[3],
    verified: v[4] === true || v[4] === 'TRUE',
    code: v[5], codeExpiresAt: v[6], createdAt: v[7], avatarUrl: v[8],
    provider: v[9] || 'email'
  };
}

function jsonOut(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function norm(s) { return String(s || '').trim().toLowerCase(); }
function isEmail(s) { return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s); }
function genCode() { return String(Math.floor(100000 + Math.random() * 900000)); }
function hashPassword(clientHash) {
  const raw = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    SERVER_SALT + '|' + clientHash
  );
  return raw.map(function (b) {
    const v = (b < 0 ? b + 256 : b).toString(16);
    return v.length === 1 ? '0' + v : v;
  }).join('');
}
function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, function (c) {
    return { '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c];
  });
}
