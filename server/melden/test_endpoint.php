<?php
declare(strict_types=1);
/**
 * Prüfstand für melden.php — startet den PHP-eigenen Webserver gegen ein Wegwerf-Docroot
 * und spielt die Fälle durch. Kein curl, kein Netz, keine Datenbank: nur PHP.
 *
 *   tools/report/php.sh server/melden/test_endpoint.php
 *
 * Der Aufbau spiegelt die Ablage aus README.md — Konfiguration und Meldungsdatei liegen
 * ÜBER dem Docroot. Damit prüft der Lauf auch, dass die dokumentierte Struktur zum
 * `MS_CONFIG`-Pfad im Endpunkt passt.
 *
 * Was er NICHT prüft: die PHP-Fassung auf dem Zielhost, ob dort ein Verzeichnis über dem
 * Docroot beschreibbar ist, HTTPS, und die Authorization-Header-Falle von Apache
 * (CGI/FastCGI) — der eingebaute Server reicht den Header durch. Die curl-Runde gegen die
 * echte Domain aus README.md bleibt Pflicht.
 */

if (php_sapi_name() !== 'cli') {
    http_response_code(404);
    exit;
}

require __DIR__ . '/token.php';

const PORT_FIRST = 8390;
const PORT_LAST = 8420;

$GLOBALS['ms_checks'] = 0;
$GLOBALS['ms_failed'] = 0;


function check(string $label, bool $ok, string $detail = ''): void
{
    $GLOBALS['ms_checks']++;
    if (!$ok) {
        $GLOBALS['ms_failed']++;
    }
    printf("%s  %s%s\n", $ok ? 'ok  ' : 'FEHL', $label,
        $ok || $detail === '' ? '' : "\n      " . $detail);
}

/** Ein HTTP-Vorgang. Rückgabe: [status, decoded_body_or_null, raw]. */
function request(string $url, string $method, ?string $token, $body = null): array
{
    $headers = ["Content-Type: application/json"];
    if ($token !== null) {
        $headers[] = "Authorization: Bearer $token";
    }
    $options = [
        'http' => [
            'method' => $method,
            'header' => implode("\r\n", $headers),
            'ignore_errors' => true,          // 4xx soll den Body liefern, nicht false
            'timeout' => 10,
        ],
    ];
    if ($body !== null) {
        $options['http']['content'] = is_string($body) ? $body : json_encode($body);
    }
    $raw = @file_get_contents($url, false, stream_context_create($options));
    $status = 0;
    foreach ($http_response_header ?? [] as $line) {
        if (preg_match('#^HTTP/\S+\s+(\d{3})#', $line, $m)) {
            $status = (int) $m[1];
        }
    }
    $decoded = is_string($raw) ? json_decode($raw, true) : null;
    return [$status, is_array($decoded) ? $decoded : null, (string) $raw];
}

function free_port(): int
{
    for ($port = PORT_FIRST; $port <= PORT_LAST; $port++) {
        $socket = @stream_socket_server("tcp://127.0.0.1:$port", $errno, $errstr);
        if ($socket !== false) {
            fclose($socket);
            return $port;
        }
    }
    fwrite(STDERR, "Kein freier Port zwischen " . PORT_FIRST . " und " . PORT_LAST . ".\n");
    exit(2);
}

function rmtree(string $path): void
{
    if (is_file($path) || is_link($path)) {
        @unlink($path);
        return;
    }
    if (!is_dir($path)) {
        return;
    }
    foreach (array_diff(scandir($path) ?: [], ['.', '..']) as $name) {
        rmtree($path . '/' . $name);
    }
    @rmdir($path);
}

/**
 * Baut die Ablage aus README.md in einem Wegwerf-Verzeichnis, startet `php -S` davor und
 * ruft `$body` mit dem Zusammenhang auf. Räumt hinterher auf, auch wenn es knallt.
 */
function scenario(string $name, array $config, callable $body): void
{
    echo "\n--- $name\n";
    $root = sys_get_temp_dir() . '/ms-endpoint-' . bin2hex(random_bytes(6));
    $docroot = "$root/www";
    mkdir("$docroot/melden", 0700, true);
    mkdir("$root/ms-reports", 0700, true);
    copy(__DIR__ . '/melden.php', "$docroot/melden/melden.php");
    copy(__DIR__ . '/token.php', "$docroot/melden/token.php");

    $secret = bin2hex(random_bytes(32));
    $settings = array_merge([
        'MS_SECRET_HEX' => $secret,
        'MS_KEY_VERSION' => 1,
        'MS_REQUIRE_HTTPS' => false,
    ], $config);
    $lines = ["<?php"];
    foreach ($settings as $key => $value) {
        $lines[] = sprintf("const %s = %s;", $key, var_export($value, true));
    }
    // Der Ablagepfad ist relativ zur Konfiguration — genau wie in README.md.
    $lines[] = "const MS_DATA_DIR = __DIR__ . '/ms-reports';";
    file_put_contents("$root/ms-secret.php", implode("\n", $lines) . "\n");

    $port = free_port();
    $log = "$root/server.log";
    $process = proc_open(
        [PHP_BINARY, '-S', "127.0.0.1:$port", '-t', $docroot],
        [1 => ['file', $log, 'a'], 2 => ['file', $log, 'a']],
        $pipes
    );
    if (!is_resource($process)) {
        fwrite(STDERR, "Server nicht startbar.\n");
        exit(2);
    }
    for ($i = 0; $i < 100; $i++) {
        $probe = @fsockopen('127.0.0.1', $port, $errno, $errstr, 0.2);
        if ($probe !== false) {
            fclose($probe);
            break;
        }
        usleep(100_000);
    }

    $context = [
        'base' => "http://127.0.0.1:$port",
        'url' => "http://127.0.0.1:$port/melden/melden.php",
        'root' => $root,
        'reports' => "$root/ms-reports/reports.jsonl",
        'revoked' => "$root/ms-reports/revoked.txt",
        'secret' => $secret,
        'key_version' => (int) $settings['MS_KEY_VERSION'],
        'token' => ms_token($secret, (int) $settings['MS_KEY_VERSION'], 'mia'),
    ];
    try {
        $body($context);
    } finally {
        proc_terminate($process);
        proc_close($process);
        rmtree($root);
    }
}

/** Zeilen der Meldungsdatei, dekodiert. */
function reports(array $ctx): array
{
    if (!is_file($ctx['reports'])) {
        return [];
    }
    $out = [];
    foreach (file($ctx['reports'], FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        $out[] = json_decode($line, true);
    }
    return $out;
}

function report_body(array $extra = []): array
{
    return array_merge([
        'action' => 'report',
        'key_version' => 1,
        'target_type' => 'lexeme',
        'target_id' => 'lex.beispiel',
        'learnable_id' => 'task.translate.de_en|lex.beispiel',
        'comment' => 'Übersetzung passt nicht',
        'at' => '2026-09-02T18:04:11',
        'app_version' => '0.3.1',
        'pack' => ['id' => 'zz-test-pack', 'version' => 'v7'],
    ], $extra);
}


// ---------------------------------------------------------------------------------------

scenario('Token prüfen', [], function (array $ctx): void {
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], ['action' => 'verify']);
    check('gültiges Token wird angenommen', $status === 200 && ($data['ok'] ?? false) === true,
        "Status $status");
    check('Antwort nennt das Label', ($data['label'] ?? '') === 'mia');
    check('Antwort nennt die Schlüsselversion', ($data['key_version'] ?? 0) === 1);

    // So tippt ein Mensch es ab: klein, mit Bindestrichen.
    $typed = strtolower(str_replace('.', '.', $ctx['token']));
    $label = ms_label_of($ctx['token']);
    $mac = substr($ctx['token'], strlen($label) + 1);
    $typed = strtoupper($label) . '.' . strtolower(implode('-', str_split($mac, 4)));
    [$status, $data] = request($ctx['url'], 'POST', $typed, ['action' => 'verify']);
    check('abgetipptes Token (Bindestriche, Kleinschreibung) gilt',
        $status === 200 && ($data['ok'] ?? false) === true, "Status $status bei '$typed'");

    $broken = substr($ctx['token'], 0, -1) . (substr($ctx['token'], -1) === 'Z' ? 'Y' : 'Z');
    [$status, $data] = request($ctx['url'], 'POST', $broken, ['action' => 'verify']);
    check('verfälschtes Token: bad_token',
        $status === 401 && ($data['error'] ?? '') === 'bad_token', "Status $status");

    [$status, $data] = request($ctx['url'], 'POST', null, ['action' => 'verify']);
    check('ohne Authorization: bad_token',
        $status === 401 && ($data['error'] ?? '') === 'bad_token', "Status $status");

    [$status, $data] = request($ctx['url'], 'POST', 'mia.KURZ', ['action' => 'verify']);
    check('Token mit falscher Gestalt: bad_token',
        $status === 401 && ($data['error'] ?? '') === 'bad_token', "Status $status");

    [$status, $data] = request($ctx['url'], 'GET', $ctx['token']);
    check('GET wird abgewiesen', $status === 405 && ($data['error'] ?? '') === 'bad_request',
        "Status $status");

    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], 'kein json');
    check('kaputter Body: bad_payload',
        $status === 400 && ($data['error'] ?? '') === 'bad_payload', "Status $status");

    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], ['action' => 'loeschen']);
    check('unbekannte Aktion: bad_request',
        $status === 400 && ($data['error'] ?? '') === 'bad_request', "Status $status");

    check('das Prüfen schreibt nichts', reports($ctx) === []);
});

scenario('Meldung annehmen', [], function (array $ctx): void {
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], report_body());
    check('Meldung wird gespeichert',
        $status === 200 && ($data['stored'] ?? null) === true, "Status $status");

    $lines = reports($ctx);
    check('genau eine Zeile', count($lines) === 1, 'Zeilen: ' . count($lines));
    $entry = $lines[0] ?? [];
    check('Label kommt aus dem Token, nicht aus dem Body', ($entry['label'] ?? '') === 'mia');
    check('Ziel-Id steht drin', ($entry['target_id'] ?? '') === 'lex.beispiel');
    check('Zieltyp steht drin', ($entry['target_type'] ?? '') === 'lexeme');
    check('Umlaute bleiben erhalten', ($entry['comment'] ?? '') === 'Übersetzung passt nicht',
        'gespeichert: ' . ($entry['comment'] ?? ''));
    check('Pack-Herkunft steht drin',
        ($entry['pack_id'] ?? '') === 'zz-test-pack' && ($entry['pack_version'] ?? '') === 'v7');
    check('App-Fassung steht drin', ($entry['app_version'] ?? '') === '0.3.1');
    check('Empfangszeit wird gesetzt', ($entry['received_at'] ?? '') !== '');

    // Verlorene Antwort, Spiel schickt erneut.
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], report_body());
    check('Wiederholung wird erkannt',
        $status === 200 && ($data['stored'] ?? null) === false, "Status $status");
    check('Wiederholung schreibt keine zweite Zeile', count(reports($ctx)) === 1);

    // Andere Meldung zum selben Wort (andere Uhrzeit) ist keine Wiederholung.
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'],
        report_body(['at' => '2026-09-02T19:00:00', 'comment' => 'noch etwas']));
    check('zweite Meldung zum selben Wort wird angenommen',
        ($data['stored'] ?? null) === true && count(reports($ctx)) === 2);

    check('Steuerzeichen werden entfernt', (function () use ($ctx) {
        request($ctx['url'], 'POST', $ctx['token'],
            report_body(['at' => '2026-09-02T20:00:00', 'comment' => "böse\x07\x00Zeichen"]));
        $lines = reports($ctx);
        $last = end($lines);
        return ($last['comment'] ?? '') === 'böseZeichen';
    })());
});

scenario('Meldung abweisen', [], function (array $ctx): void {
    $cases = [
        ['ohne target_type', report_body(['target_type' => null]), 400, 'bad_payload'],
        ['unbekannter target_type', report_body(['target_type' => 'monster']), 400, 'bad_payload'],
        ['ohne Kommentar', report_body(['comment' => '']), 400, 'bad_payload'],
        ['ohne target_id', report_body(['target_id' => '']), 400, 'bad_payload'],
        ['zu langer Kommentar', report_body(['comment' => str_repeat('a', 600)]), 400, 'bad_payload'],
        ['zu großer Body', report_body(['comment' => str_repeat('a', 5000)]), 413, 'too_large'],
        ['alte Schlüsselversion', report_body(['key_version' => 2]), 401, 'stale_key'],
    ];
    foreach ($cases as [$name, $body, $want_status, $want_error]) {
        [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], $body);
        check("$name: $want_error",
            $status === $want_status && ($data['error'] ?? '') === $want_error,
            "Status $status, Grund '" . ($data['error'] ?? '') . "'");
    }
    check('keine abgewiesene Meldung landet in der Datei', reports($ctx) === []);
});

scenario('Gesperrtes Label', [], function (array $ctx): void {
    file_put_contents($ctx['revoked'], "leo\nmia\n");
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], ['action' => 'verify']);
    check('gesperrtes Label wird benannt',
        $status === 403 && ($data['error'] ?? '') === 'revoked', "Status $status");
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], report_body());
    check('gesperrtes Label kann nicht melden',
        $status === 403 && ($data['error'] ?? '') === 'revoked', "Status $status");
    check('nichts gespeichert', reports($ctx) === []);
});

scenario('Rate-Limit', ['MS_RATE_HOUR' => 3], function (array $ctx): void {
    for ($i = 1; $i <= 3; $i++) {
        [$status] = request($ctx['url'], 'POST', $ctx['token'],
            report_body(['at' => sprintf('2026-09-02T18:0%d:00', $i)]));
        check("Meldung $i von 3 geht durch", $status === 200, "Status $status");
    }
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'],
        report_body(['at' => '2026-09-02T18:09:00']));
    check('vierte Meldung: rate_limited',
        $status === 429 && ($data['error'] ?? '') === 'rate_limited', "Status $status");
    check('die abgewiesene steht nicht in der Datei', count(reports($ctx)) === 3);
});

scenario('Rotation des Geheimnisses', ['MS_KEY_VERSION' => 2], function (array $ctx): void {
    // Token aus der Zeit vor der Rotation.
    $old = ms_token($ctx['secret'], 1, 'mia');
    [$status, $data] = request($ctx['url'], 'POST', $old, report_body(['key_version' => 1]));
    check('altes Token beim Melden: stale_key',
        $status === 401 && ($data['error'] ?? '') === 'stale_key',
        "Status $status, Grund '" . ($data['error'] ?? '') . "'");
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], report_body(['key_version' => 2]));
    check('neu geprägtes Token gilt', $status === 200 && ($data['stored'] ?? null) === true,
        "Status $status");
});

scenario('HTTPS-Zwang', ['MS_REQUIRE_HTTPS' => true], function (array $ctx): void {
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], ['action' => 'verify']);
    check('ohne TLS wird abgewiesen, nicht bedient',
        $status === 400 && ($data['error'] ?? '') === 'bad_request', "Status $status");
});

scenario('Ablage liegt außerhalb des Docroots', [], function (array $ctx): void {
    request($ctx['url'], 'POST', $ctx['token'], report_body());
    check('Meldung ist angekommen', count(reports($ctx)) === 1);
    foreach (['/ms-reports/reports.jsonl', '/ms-secret.php', '/melden/../../ms-secret.php'] as $path) {
        [$status] = request($ctx['base'] . $path, 'GET', null);
        check("nicht abrufbar: $path", $status !== 200, "Status $status");
    }
    // Die eingebundene Formatdatei ist zwar im Docroot, gibt aber nichts aus.
    [$status, , $raw] = request($ctx['base'] . '/melden/token.php', 'GET', null);
    check('token.php verrät keinen Quelltext', !str_contains($raw, 'MS_ALPHABET'),
        'Antwort: ' . substr($raw, 0, 120));
});

printf("\n=== %d Prüfungen, %d Abweichungen\n", $GLOBALS['ms_checks'], $GLOBALS['ms_failed']);
exit($GLOBALS['ms_failed'] === 0 ? 0 : 1);
