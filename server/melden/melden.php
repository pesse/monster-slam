<?php
declare(strict_types=1);
/**
 * Melde-Endpunkt (siehe docs/adr/0002-melde-rueckkanal.md).
 *
 * Nimmt Meldungen der verteilten Spiel-EXE an, prueft das Melde-Token und haengt eine
 * Zeile an eine JSON-Lines-Datei. Er legt KEINE GitHub-Issues an: eine Stoerung dort
 * duerfte keine Meldung verschlucken, und erst getrennt laesst sich buendeln.
 *
 * Zwei Aktionen:
 *   {"action":"verify","key_version":1}                         -> {"ok":true,"label":"mia"}
 *   {"action":"report","key_version":1,"target_type":"lexeme",…} -> {"ok":true,"stored":true}
 *
 * Fehler antworten mit benanntem Grund, nicht nur mit einem Status: bad_request,
 * bad_token, stale_key, revoked, too_large, rate_limited, bad_payload, server_error.
 * Die App zeigt den Grund nach einem Klick und schweigt im Hintergrund.
 *
 * Deployen: server/melden/README.md. Geheimnis und Daten liegen UEBER dem Docroot.
 */

require __DIR__ . '/token.php';

/** Konfiguration ueber dem Docroot: definiert MS_SECRET_HEX, MS_KEY_VERSION, MS_DATA_DIR. */
const MS_CONFIG = __DIR__ . '/../../ms-secret.php';

/** Ein Body ist ein Kommentar und ein paar Ids. Alles darueber ist kein Melden. */
const MS_MAX_BODY = 4096;

/** Wie weit zurueck fuer Rate-Limit und Doppelerkennung gelesen wird. */
const MS_TAIL_BYTES = 262144;

const MS_TARGET_TYPES = ['lexeme', 'sentence'];

/** Laengen, ab denen ein Feld nicht mehr plausibel ist. */
const MS_LIMITS = [
    'target_id' => 200, 'learnable_id' => 200, 'comment' => 500,
    'at' => 40, 'app_version' => 32, 'pack_id' => 64, 'pack_version' => 64,
];


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

/**
 * Der Bearer-Token aus dem Authorization-Header.
 *
 * Auf CGI/FastCGI-Hosting reicht Apache den Header nicht immer durch — daher die
 * REDIRECT_-Variante und apache_request_headers() als Rueckfall. Wenn beides leer
 * bleibt, fehlt die .htaccess-Zeile aus der README.
 */
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

/** Die letzten MS_TAIL_BYTES als Zeilen (fuer Rate-Limit und Doppelerkennung). */
function ms_tail(string $path): array
{
    if (!is_file($path)) {
        return [];
    }
    $size = filesize($path);
    $handle = fopen($path, 'r');
    if ($handle === false) {
        return [];
    }
    if ($size > MS_TAIL_BYTES) {
        fseek($handle, $size - MS_TAIL_BYTES);
        fgets($handle);                       // angeschnittene erste Zeile verwerfen
    }
    $lines = [];
    while (($line = fgets($handle)) !== false) {
        $line = trim($line);
        if ($line !== '') {
            $lines[] = $line;
        }
    }
    fclose($handle);
    return $lines;
}

function ms_field(array $data, string $name, bool $required = true): string
{
    $value = trim((string) ($data[$name] ?? ''));
    if ($value === '') {
        if ($required) {
            ms_fail('bad_payload');
        }
        return '';
    }
    if (mb_strlen($value) > MS_LIMITS[$name]) {
        ms_fail('bad_payload');
    }
    // Steuerzeichen (ausser Zeilenumbruechen im Kommentar) haben in keinem Feld etwas zu suchen.
    return preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u', '', $value) ?? '';
}


// --- 1. Rahmen pruefen, bevor irgendetwas gelesen wird -------------------------------

if (!is_file(MS_CONFIG)) {
    error_log('melden.php: Konfiguration fehlt: ' . MS_CONFIG);
    ms_fail('server_error', 500);
}
require MS_CONFIG;

if (!defined('MS_SECRET_HEX') || !defined('MS_KEY_VERSION') || !defined('MS_DATA_DIR')) {
    error_log('melden.php: Konfiguration unvollstaendig');
    ms_fail('server_error', 500);
}
$require_https = !defined('MS_REQUIRE_HTTPS') || MS_REQUIRE_HTTPS;
$rate_hour = defined('MS_RATE_HOUR') ? MS_RATE_HOUR : 30;
$rate_day = defined('MS_RATE_DAY') ? MS_RATE_DAY : 200;

if ($require_https && !ms_is_https()) {
    // Ohne TLS reist das Token im Klartext — dann lieber abweisen als bedienen.
    ms_fail('bad_request', 400);
}
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    header('Allow: POST');
    ms_fail('bad_request', 405);
}
if ((int) ($_SERVER['CONTENT_LENGTH'] ?? 0) > MS_MAX_BODY) {
    ms_fail('too_large', 413);
}

$raw = file_get_contents('php://input');
if ($raw === false || strlen($raw) > MS_MAX_BODY) {
    ms_fail('too_large', 413);
}
$data = json_decode($raw, true, 8);
if (!is_array($data)) {
    ms_fail('bad_payload');
}

$action = (string) ($data['action'] ?? '');
if ($action !== 'verify' && $action !== 'report') {
    ms_fail('bad_request');
}

// --- 2. Token ------------------------------------------------------------------------

// Die App sendet mit, unter welcher Schluesselversion ihr Token steht. Nur so kann eine
// Rotation "bitte neu eintragen" heissen statt "ungueltig".
$claimed = (int) ($data['key_version'] ?? MS_KEY_VERSION);
if ($claimed !== MS_KEY_VERSION) {
    ms_fail('stale_key', 401);
}

$token = ms_normalize_token(ms_bearer());
if ($token === null || !ms_token_valid(MS_SECRET_HEX, MS_KEY_VERSION, $token)) {
    ms_fail('bad_token', 401);
}
$label = ms_label_of($token);

$revoked_path = rtrim(MS_DATA_DIR, '/') . '/revoked.txt';
if (is_file($revoked_path)) {
    $revoked = array_map('trim', file($revoked_path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES));
    if (in_array($label, $revoked, true)) {
        ms_fail('revoked', 403);
    }
}

if ($action === 'verify') {
    ms_send(['ok' => true, 'label' => $label, 'key_version' => MS_KEY_VERSION]);
}

// --- 3. Meldung ----------------------------------------------------------------------

$target_type = (string) ($data['target_type'] ?? '');
if (!in_array($target_type, MS_TARGET_TYPES, true)) {
    ms_fail('bad_payload');
}

$pack = is_array($data['pack'] ?? null) ? $data['pack'] : [];
$entry = [
    'ts' => time(),
    'received_at' => gmdate('c'),
    'label' => $label,
    'target_type' => $target_type,
    'target_id' => ms_field($data, 'target_id'),
    'learnable_id' => ms_field($data, 'learnable_id', false),
    'comment' => ms_field($data, 'comment'),
    'at' => ms_field($data, 'at', false),
    'app_version' => ms_field($data, 'app_version', false),
    'pack_id' => ms_field(['pack_id' => $pack['id'] ?? ''], 'pack_id', false),
    'pack_version' => ms_field(['pack_version' => $pack['version'] ?? ''], 'pack_version', false),
];
// Doppelerkennung: dieselbe Meldung nach einer verlorenen Antwort darf nicht zweimal
// in der Datei stehen. `at` ist die Uhrzeit der Meldung auf dem Spielerrechner.
$entry['key'] = $label . '|' . $entry['target_id'] . '|' . $entry['at'];

$dir = rtrim(MS_DATA_DIR, '/');
if (!is_dir($dir) && !@mkdir($dir, 0700, true)) {
    error_log('melden.php: Ablage nicht anlegbar: ' . $dir);
    ms_fail('server_error', 500);
}
$reports_path = $dir . '/reports.jsonl';

$now = time();
$seen_hour = 0;
$seen_day = 0;
foreach (ms_tail($reports_path) as $line) {
    $old = json_decode($line, true);
    if (!is_array($old) || ($old['label'] ?? '') !== $label) {
        continue;
    }
    if (($old['key'] ?? '') === $entry['key'] && $entry['at'] !== '') {
        ms_send(['ok' => true, 'stored' => false]);
    }
    $age = $now - (int) ($old['ts'] ?? 0);
    if ($age < 3600) {
        $seen_hour++;
    }
    if ($age < 86400) {
        $seen_day++;
    }
}
if ($seen_hour >= $rate_hour || $seen_day >= $rate_day) {
    ms_fail('rate_limited', 429);
}

$handle = fopen($reports_path, 'a');
if ($handle === false) {
    error_log('melden.php: Ablage nicht schreibbar: ' . $reports_path);
    ms_fail('server_error', 500);
}
// Ohne Lock zerschneiden zwei gleichzeitige Meldungen eine Zeile.
if (!flock($handle, LOCK_EX)) {
    fclose($handle);
    ms_fail('server_error', 500);
}
fwrite($handle, json_encode($entry, JSON_UNESCAPED_UNICODE) . "\n");
fflush($handle);
flock($handle, LOCK_UN);
fclose($handle);
@chmod($reports_path, 0600);

ms_send(['ok' => true, 'stored' => true]);
