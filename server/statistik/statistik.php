<?php
declare(strict_types=1);
/**
 * Statistik-Endpunkt (siehe docs/adr/0021-statistik-rueckkanal.md).
 *
 * Nimmt die Spielstatistik der verteilten EXE an: je Profil einen Snapshot des Spielstands
 * und die bereinigte Spur in Stücken. Zugeordnet wird über eine zufällige `stats_id` je
 * Profil; ein Name kommt hier nie an.
 *
 * Zwei Aktionen, Body JSON, wahlweise gzip-gepackt (`Content-Encoding: gzip`):
 *   {"action":"snapshot","key_version":1,"stats_id":"…32 hex…","format":1,…}
 *       -> {"ok":true,"stored":true}
 *   {"action":"trace","key_version":1,"stats_id":"…","from":[at,ms],"to":[at,ms],"events":[…]}
 *       -> {"ok":true,"stored":true|false,"have":[at,ms]}
 *
 * Der Zugang ist ein App-Schlüssel: ein Token im Format von token.php mit einem Label
 * `app-*`, das beim Export in die EXE kommt. Er ist herauslesbar und damit kein Geheimnis,
 * sondern ein Spamschutz — gesperrt wird er wie ein Melde-Token über revoked.txt. Was die
 * Ablage begrenzt, sind die Grenzen unten, nicht der Schlüssel.
 *
 * Fehler wie beim Melde-Endpunkt: bad_request, bad_token, stale_key, revoked, too_large,
 * rate_limited, quota, bad_payload, server_error.
 *
 * Deployen: server/statistik/README.md (nach server/melden/README.md).
 */

require __DIR__ . '/../melden/token.php';

/** Dieselbe Konfiguration wie melden.php: MS_SECRET_HEX, MS_KEY_VERSION, MS_DATA_DIR. */
const MS_CONFIG = __DIR__ . '/../../ms-secret.php';

/** Gepackt. Ein Snapshot mit einigen tausend Lernständen liegt gepackt bei ~50 KB. */
const MS_STATS_MAX_BODY = 262144;

/** Entpackt. Schützt vor einer Zip-Bombe und vor allem, was kein Spielstand mehr ist. */
const MS_STATS_MAX_JSON = 2097152;

const MS_STATS_DEPTH = 16;
const MS_STATS_FORMAT = 1;

/**
 * Felder, die in keiner Spurzeile ankommen dürfen. Die App bereinigt selbst (Allowlist in
 * TraceSanitizer); das hier ist die zweite Linie, falls eine ältere oder fehlerhafte App
 * etwas durchlässt: getippter Text, Lemmata, Erklärungen, Profilnamen. (`why` heißt in der
 * Rohspur sowohl der Auswahlgrund als auch die Boss-Erklärung; die App sendet den
 * Auswahlgrund deshalb als `pick`.)
 */
const MS_STATS_FORBIDDEN = ['text', 'canonical', 'prompt', 'answers', 'why', 'profile'];

/** Je stats_id und Tag: Snapshots und Spurstücke zusammen. */
const MS_STATS_PER_ID_DAY = 60;

/** Je IP und Tag, über alle Ids. Die IP selbst wird nicht gespeichert, nur ein HMAC davon. */
const MS_STATS_PER_IP_DAY = 400;

/** Mehr Profile nimmt die Ablage nicht an — neue Ids bekommen `quota`. */
const MS_STATS_MAX_IDS = 1000;

/** Gepackte Spur je Id und Monat. */
const MS_STATS_TRACE_MONTH = 20971520;


function ms_send(array $body, int $status = 200): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($body, JSON_UNESCAPED_UNICODE), "\n";
    exit;
}

function ms_fail(string $code, int $status = 400): void
{
    ms_send(['ok' => false, 'error' => $code], $status);
}

/** Wie in melden.php — CGI/FastCGI reicht den Header nicht immer durch. */
function ms_bearer(): string
{
    $raw = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if ($raw === '' && function_exists('apache_request_headers')) {
        foreach (apache_request_headers() as $name => $value) {
            if (strcasecmp($name, 'Authorization') === 0) {
                $raw = $value;
                break;
            }
        }
    }
    if (stripos($raw, 'Bearer ') !== 0) {
        return '';
    }
    return trim(substr($raw, 7));
}

function ms_is_https(): bool
{
    if (($_SERVER['HTTPS'] ?? '') !== '' && strtolower((string) $_SERVER['HTTPS']) !== 'off') {
        return true;
    }
    return strtolower($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https';
}

/**
 * Zählt einen Vorgang unter `$key` für heute und gibt die Zahl davor zurück. Der Zähler
 * ist die Dateigröße (ein Byte je Vorgang) — kein Lesen, kein Parsen, kein Lock-Tanz.
 * Dateien früherer Tage räumt der erste Vorgang eines Tages weg.
 */
function ms_count(string $rate_dir, string $key, string $day): int
{
    $path = "$rate_dir/$day-$key";
    if (!is_file($path)) {
        foreach (glob("$rate_dir/*") ?: [] as $old) {
            if (strpos(basename($old), "$day-") !== 0) {
                @unlink($old);
            }
        }
    }
    clearstatcache(true, $path);
    $before = is_file($path) ? (int) filesize($path) : 0;
    file_put_contents($path, '.', FILE_APPEND | LOCK_EX);
    return $before;
}

/** Entfernt die verbotenen Felder aus einer Spurzeile, auf jeder Ebene. */
function ms_scrub(array $value): array
{
    $out = [];
    foreach ($value as $key => $item) {
        if (is_string($key) && in_array($key, MS_STATS_FORBIDDEN, true)) {
            continue;
        }
        $out[$key] = is_array($item) ? ms_scrub($item) : $item;
    }
    return $out;
}

/** [at, ms] als Paar ganzer Zahlen, sonst null. */
function ms_mark($value): ?array
{
    if (!is_array($value) || count($value) !== 2) {
        return null;
    }
    [$at, $ms] = array_values($value);
    if (!is_int($at) || !is_int($ms) || $at < 0 || $ms < 0) {
        return null;
    }
    return [$at, $ms];
}

function ms_mark_before(array $a, array $b): bool
{
    return $a[0] < $b[0] || ($a[0] === $b[0] && $a[1] < $b[1]);
}

/** Schreibt über eine Zwischendatei: wer gleichzeitig liest, sieht alt oder neu, nie halb. */
function ms_write_atomic(string $path, string $bytes): bool
{
    $tmp = $path . '.tmp' . bin2hex(random_bytes(4));
    if (file_put_contents($tmp, $bytes) === false) {
        return false;
    }
    @chmod($tmp, 0600);
    if (!rename($tmp, $path)) {
        @unlink($tmp);
        return false;
    }
    return true;
}


// --- 1. Rahmen -----------------------------------------------------------------------

if (!is_file(MS_CONFIG)) {
    error_log('statistik.php: Konfiguration fehlt: ' . MS_CONFIG);
    ms_fail('server_error', 500);
}
require MS_CONFIG;

if (!defined('MS_SECRET_HEX') || !defined('MS_KEY_VERSION') || !defined('MS_DATA_DIR')) {
    error_log('statistik.php: Konfiguration unvollstaendig');
    ms_fail('server_error', 500);
}
$require_https = !defined('MS_REQUIRE_HTTPS') || MS_REQUIRE_HTTPS;
$stats_dir = rtrim(defined('MS_STATS_DIR') ? MS_STATS_DIR : dirname(MS_DATA_DIR) . '/ms-stats', '/');
$per_id_day = defined('MS_STATS_RATE_ID') ? MS_STATS_RATE_ID : MS_STATS_PER_ID_DAY;
$per_ip_day = defined('MS_STATS_RATE_IP') ? MS_STATS_RATE_IP : MS_STATS_PER_IP_DAY;
$max_ids = defined('MS_STATS_IDS') ? MS_STATS_IDS : MS_STATS_MAX_IDS;
$trace_month = defined('MS_STATS_TRACE_BYTES') ? MS_STATS_TRACE_BYTES : MS_STATS_TRACE_MONTH;

if ($require_https && !ms_is_https()) {
    ms_fail('bad_request', 400);
}
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    header('Allow: POST');
    ms_fail('bad_request', 405);
}
if ((int) ($_SERVER['CONTENT_LENGTH'] ?? 0) > MS_STATS_MAX_BODY) {
    ms_fail('too_large', 413);
}

$raw = file_get_contents('php://input');
if ($raw === false || strlen($raw) > MS_STATS_MAX_BODY) {
    ms_fail('too_large', 413);
}
// Gepackt erkennt man an den ersten beiden Bytes; der Header allein reicht nicht, weil
// manche Hoster den Body schon entpacken und den Header stehen lassen.
if (strncmp($raw, "\x1f\x8b", 2) === 0) {
    $unpacked = @gzdecode($raw, MS_STATS_MAX_JSON + 1);
    if ($unpacked === false) {
        // gzdecode unterscheidet „kaputt" nicht von „zu groß" — beides ist kein Spielstand.
        ms_fail('too_large', 413);
    }
    $raw = $unpacked;
}
if (strlen($raw) > MS_STATS_MAX_JSON) {
    ms_fail('too_large', 413);
}
$data = json_decode($raw, true, MS_STATS_DEPTH);
if (!is_array($data)) {
    ms_fail('bad_payload');
}

$action = (string) ($data['action'] ?? '');
if ($action !== 'snapshot' && $action !== 'trace') {
    ms_fail('bad_request');
}

// --- 2. App-Schlüssel ----------------------------------------------------------------

$claimed = (int) ($data['key_version'] ?? MS_KEY_VERSION);
if ($claimed !== MS_KEY_VERSION) {
    ms_fail('stale_key', 401);
}
$token = ms_normalize_token(ms_bearer());
if ($token === null || !ms_token_valid(MS_SECRET_HEX, MS_KEY_VERSION, $token)) {
    ms_fail('bad_token', 401);
}
$label = ms_label_of($token);
// Ein Melde-Token nennt eine Person; hier zählt nur, dass es die App ist. Ein Personen-
// Token anzunehmen hiesse, Statistik und Name doch wieder zusammenzulegen.
if (strpos($label, 'app-') !== 0) {
    ms_fail('bad_token', 401);
}
$revoked_path = rtrim(MS_DATA_DIR, '/') . '/revoked.txt';
if (is_file($revoked_path)) {
    $revoked = array_map('trim', file($revoked_path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES));
    if (in_array($label, $revoked, true)) {
        ms_fail('revoked', 403);
    }
}

// --- 3. Absender ---------------------------------------------------------------------

$stats_id = (string) ($data['stats_id'] ?? '');
if (preg_match('/^[0-9a-f]{32}$/', $stats_id) !== 1) {
    ms_fail('bad_payload');
}

$rate_dir = "$stats_dir/_rate";
if (!is_dir($rate_dir) && !@mkdir($rate_dir, 0700, true)) {
    error_log('statistik.php: Ablage nicht anlegbar: ' . $rate_dir);
    ms_fail('server_error', 500);
}
$day = gmdate('Y-m-d');
$ip_key = substr(hash_hmac('sha256', (string) ($_SERVER['REMOTE_ADDR'] ?? ''), MS_SECRET_HEX), 0, 16);
if (ms_count($rate_dir, "ip-$ip_key", $day) >= $per_ip_day
    || ms_count($rate_dir, "id-$stats_id", $day) >= $per_id_day) {
    ms_fail('rate_limited', 429);
}

$id_dir = "$stats_dir/$stats_id";
if (!is_dir($id_dir)) {
    $known = count(glob("$stats_dir/*", GLOB_ONLYDIR) ?: []) - 1;   // ohne _rate
    if ($known >= $max_ids) {
        ms_fail('quota', 507);
    }
    if (!@mkdir($id_dir, 0700, true)) {
        error_log('statistik.php: Ablage nicht anlegbar: ' . $id_dir);
        ms_fail('server_error', 500);
    }
}

// --- 4a. Snapshot --------------------------------------------------------------------

if ($action === 'snapshot') {
    if ((int) ($data['format'] ?? 0) !== MS_STATS_FORMAT) {
        ms_fail('bad_payload');
    }
    unset($data['action'], $data['key_version']);
    $data['received_at'] = gmdate('c');
    $data['app_key'] = $label;
    // Je Tag eine Datei, am selben Tag überschrieben: so entsteht die Tageshistorie, ohne
    // dass ein Spielstand zweimal liegt.
    $path = "$id_dir/snapshot-$day.json.gz";
    if (!ms_write_atomic($path, gzencode(json_encode($data, JSON_UNESCAPED_UNICODE), 6))) {
        error_log('statistik.php: Snapshot nicht schreibbar: ' . $path);
        ms_fail('server_error', 500);
    }
    ms_send(['ok' => true, 'stored' => true]);
}

// --- 4b. Spurstück -------------------------------------------------------------------

$from = ms_mark($data['from'] ?? null);
$to = ms_mark($data['to'] ?? null);
$events = $data['events'] ?? null;
if ($from === null || $to === null || ms_mark_before($to, $from) || !is_array($events)
    || $events === [] || array_keys($events) !== range(0, count($events) - 1)) {
    ms_fail('bad_payload');
}

$cursor_path = "$id_dir/trace-cursor.json";
$lock = fopen("$id_dir/trace.lock", 'c');
if ($lock === false || !flock($lock, LOCK_EX)) {
    ms_fail('server_error', 500);
}
$have = is_file($cursor_path) ? ms_mark(json_decode((string) file_get_contents($cursor_path), true)) : null;
// Ein Stück, das vor dem Stand des Servers beginnt, ist eine Wiederholung (verlorene
// Antwort) oder ein zurückgesetzter Cursor auf dem Spielerrechner. Beides beantwortet der
// Stand: die App setzt ihren Cursor darauf und schickt ab dort weiter.
if ($have !== null && ms_mark_before($from, $have)) {
    ms_send(['ok' => true, 'stored' => false, 'have' => $have]);
}

$lines = '';
foreach ($events as $event) {
    if (!is_array($event) || !is_string($event['e'] ?? null)) {
        ms_fail('bad_payload');
    }
    $lines .= json_encode(ms_scrub($event), JSON_UNESCAPED_UNICODE) . "\n";
}
$packed = gzencode($lines, 6);

$trace_path = "$id_dir/trace-" . gmdate('Y-m') . '.jsonl.gz';
clearstatcache(true, $trace_path);
if ((is_file($trace_path) ? filesize($trace_path) : 0) + strlen($packed) > $trace_month) {
    ms_fail('quota', 507);
}
// Aneinandergehängte gzip-Glieder sind wieder eine gültige gzip-Datei (RFC 1952) —
// `gunzip`, Pythons gzip und zcat lesen sie am Stück.
if (file_put_contents($trace_path, $packed, FILE_APPEND) === false
    || !ms_write_atomic($cursor_path, json_encode($to))) {
    error_log('statistik.php: Spur nicht schreibbar: ' . $trace_path);
    ms_fail('server_error', 500);
}
@chmod($trace_path, 0600);
flock($lock, LOCK_UN);
fclose($lock);

ms_send(['ok' => true, 'stored' => true, 'have' => $to]);
