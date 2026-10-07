<?php
declare(strict_types=1);
/**
 * Prüfstand für statistik.php — wie server/melden/test_endpoint.php: PHP-eigener
 * Webserver vor einem Wegwerf-Docroot mit der Ablage aus README.md.
 *
 *   tools/report/php.sh server/statistik/test_endpoint.php
 *
 * Was er NICHT prüft: Strato selbst (PHP-Fassung, HTTPS, Authorization-Header, ob ein
 * Hoster den gzip-Body schon entpackt). Die curl-Runde aus README.md bleibt Pflicht.
 */

if (php_sapi_name() !== 'cli') {
    http_response_code(404);
    exit;
}

require __DIR__ . '/../melden/token.php';

const PORT_FIRST = 8430;
const PORT_LAST = 8460;

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

/**
 * Ein HTTP-Vorgang. `$body`: Array (als JSON) oder fertige Bytes; `$gzip` packt.
 * Rückgabe: [status, decoded_body_or_null, raw].
 */
function request(string $url, string $method, ?string $token, $body = null, bool $gzip = false): array
{
    $headers = ["Content-Type: application/json"];
    if ($token !== null) {
        $headers[] = "Authorization: Bearer $token";
    }
    $options = ['http' => ['method' => $method, 'ignore_errors' => true, 'timeout' => 10]];
    if ($body !== null) {
        $bytes = is_string($body) ? $body : json_encode($body);
        if ($gzip) {
            $bytes = gzencode($bytes);
            $headers[] = 'Content-Encoding: gzip';
        }
        $options['http']['content'] = $bytes;
    }
    $options['http']['header'] = implode("\r\n", $headers);
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

function scenario(string $name, array $config, callable $body): void
{
    echo "\n--- $name\n";
    $root = sys_get_temp_dir() . '/ms-stats-endpoint-' . bin2hex(random_bytes(6));
    $docroot = "$root/www";
    mkdir("$docroot/melden", 0700, true);
    mkdir("$docroot/statistik", 0700, true);
    mkdir("$root/ms-reports", 0700, true);
    copy(__DIR__ . '/../melden/token.php', "$docroot/melden/token.php");
    copy(__DIR__ . '/statistik.php', "$docroot/statistik/statistik.php");

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
        'url' => "http://127.0.0.1:$port/statistik/statistik.php",
        'root' => $root,
        'stats' => "$root/ms-stats",
        'revoked' => "$root/ms-reports/revoked.txt",
        'secret' => $secret,
        'token' => ms_token($secret, 1, 'app-1'),
        'person' => ms_token($secret, 1, 'mia'),
    ];
    try {
        $body($context);
    } finally {
        proc_terminate($process);
        proc_close($process);
        rmtree($root);
    }
}

const ID = '0123456789abcdef0123456789abcdef';
const OTHER_ID = 'fedcba9876543210fedcba9876543210';

function snapshot_body(array $extra = []): array
{
    return array_merge([
        'action' => 'snapshot',
        'key_version' => 1,
        'stats_id' => ID,
        'format' => 1,
        'app_version' => '0.28.0',
        'wallet' => ['gold' => 120, 'total_earned' => 400],
        'level' => ['total_xp' => 3150],
        'sessions' => [['started_at' => 1791000000, 'waves_cleared' => 4]],
        'progress' => ['translate:de_en:lex.beispiel' => ['confidence' => 0.4, 'attempts' => 3]],
    ], $extra);
}

function trace_body(array $from, array $to, array $events, array $extra = []): array
{
    return array_merge([
        'action' => 'trace', 'key_version' => 1, 'stats_id' => ID,
        'from' => $from, 'to' => $to, 'events' => $events,
    ], $extra);
}

function snapshot_files(array $ctx, string $id = ID): array
{
    return glob($ctx['stats'] . "/$id/snapshot-*.json.gz") ?: [];
}

/** Liest auch aneinandergehängte gzip-Glieder (gzdecode hört nach dem ersten auf). */
function read_gz(string $path): string
{
    return implode('', gzfile($path) ?: []);
}

/** Alle Spurzeilen einer Id, über die Monatsdateien hinweg. */
function trace_lines(array $ctx, string $id = ID): array
{
    $out = [];
    foreach (glob($ctx['stats'] . "/$id/trace-*.jsonl.gz") ?: [] as $path) {
        foreach (explode("\n", trim(read_gz($path))) as $line) {
            if ($line !== '') {
                $out[] = json_decode($line, true);
            }
        }
    }
    return $out;
}


// ---------------------------------------------------------------------------------------

scenario('Snapshot annehmen', [], function (array $ctx): void {
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], snapshot_body(), true);
    check('gepackter Snapshot wird gespeichert',
        $status === 200 && ($data['stored'] ?? null) === true, "Status $status");
    $files = snapshot_files($ctx);
    check('genau eine Tagesdatei', count($files) === 1, 'Dateien: ' . count($files));
    $stored = json_decode(read_gz($files[0] ?? ''), true) ?? [];
    check('Inhalt bleibt erhalten', ($stored['level']['total_xp'] ?? 0) === 3150);
    check('Lernstand je Id bleibt erhalten',
        ($stored['progress']['translate:de_en:lex.beispiel']['attempts'] ?? 0) === 3);
    check('Empfangszeit und App-Schlüssel stehen drin',
        ($stored['received_at'] ?? '') !== '' && ($stored['app_key'] ?? '') === 'app-1');
    check('Aktion und Schlüsselversion werden nicht gespeichert',
        !isset($stored['action']) && !isset($stored['key_version']));

    [$status] = request($ctx['url'], 'POST', $ctx['token'],
        snapshot_body(['level' => ['total_xp' => 3400]]));
    check('ungepackter Snapshot geht auch', $status === 200, "Status $status");
    $files = snapshot_files($ctx);
    $stored = json_decode(read_gz($files[0] ?? ''), true) ?? [];
    check('derselbe Tag überschreibt', count($files) === 1 && ($stored['level']['total_xp'] ?? 0) === 3400);

    request($ctx['url'], 'POST', $ctx['token'], snapshot_body(['stats_id' => OTHER_ID]), true);
    check('zweites Profil bekommt eigenes Verzeichnis', count(snapshot_files($ctx, OTHER_ID)) === 1);
});

scenario('Zugang', [], function (array $ctx): void {
    [$status, $data] = request($ctx['url'], 'POST', $ctx['person'], snapshot_body(), true);
    check('Personen-Token (Melde-Kanal) wird abgewiesen',
        $status === 401 && ($data['error'] ?? '') === 'bad_token', "Status $status");

    $broken = substr($ctx['token'], 0, -1) . (substr($ctx['token'], -1) === 'Z' ? 'Y' : 'Z');
    [$status, $data] = request($ctx['url'], 'POST', $broken, snapshot_body(), true);
    check('verfälschter Schlüssel: bad_token',
        $status === 401 && ($data['error'] ?? '') === 'bad_token', "Status $status");

    [$status, $data] = request($ctx['url'], 'POST', null, snapshot_body(), true);
    check('ohne Schlüssel: bad_token',
        $status === 401 && ($data['error'] ?? '') === 'bad_token', "Status $status");

    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], snapshot_body(['key_version' => 2]));
    check('andere Schlüsselversion: stale_key',
        $status === 401 && ($data['error'] ?? '') === 'stale_key', "Status $status");

    [$status, $data] = request($ctx['url'], 'GET', $ctx['token']);
    check('GET wird abgewiesen', $status === 405, "Status $status");

    file_put_contents($ctx['revoked'], "app-1\n");
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], snapshot_body(), true);
    check('gesperrter App-Schlüssel: revoked',
        $status === 403 && ($data['error'] ?? '') === 'revoked', "Status $status");
    check('nichts gespeichert', snapshot_files($ctx) === []);
});

scenario('Snapshot abweisen', [], function (array $ctx): void {
    $cases = [
        ['ohne stats_id', snapshot_body(['stats_id' => '']), 400, 'bad_payload'],
        ['stats_id mit Großbuchstaben', snapshot_body(['stats_id' => strtoupper(ID)]), 400, 'bad_payload'],
        ['stats_id als Pfad', snapshot_body(['stats_id' => '../../ms-secret']), 400, 'bad_payload'],
        ['falsches Format', snapshot_body(['format' => 2]), 400, 'bad_payload'],
        ['unbekannte Aktion', snapshot_body(['action' => 'delete']), 400, 'bad_request'],
    ];
    foreach ($cases as [$name, $body, $want_status, $want_error]) {
        [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], $body, true);
        check("$name: $want_error",
            $status === $want_status && ($data['error'] ?? '') === $want_error,
            "Status $status, Grund '" . ($data['error'] ?? '') . "'");
    }
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], 'kein json');
    check('kaputter Body: bad_payload', $status === 400 && ($data['error'] ?? '') === 'bad_payload',
        "Status $status");

    // 3 MB Nullen packen sich auf wenige KB — die Grenze gilt dem Entpackten.
    $bomb = snapshot_body(['padding' => str_repeat('0', 3 * 1024 * 1024)]);
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], $bomb, true);
    check('entpackt zu groß: too_large', $status === 413 && ($data['error'] ?? '') === 'too_large',
        "Status $status, Grund '" . ($data['error'] ?? '') . "'");

    $noise = snapshot_body(['padding' => base64_encode(random_bytes(300 * 1024))]);
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], $noise, true);
    check('gepackt zu groß: too_large', $status === 413 && ($data['error'] ?? '') === 'too_large',
        "Status $status");

    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], "\x1f\x8bkaputt");
    check('kaputtes gzip wird abgewiesen', $status === 413, "Status $status");

    check('keine abgewiesene Sendung landet in der Ablage',
        glob($ctx['stats'] . '/*/snapshot-*') === []);
});

scenario('Spur in Stücken', [], function (array $ctx): void {
    $events = [
        ['at' => 100, 'ms' => 5, 'e' => 'spawn', 'id' => 'translate:de_en:lex.a', 'pick' => ['pos' => 1]],
        ['at' => 101, 'ms' => 9, 'e' => 'answer', 'hit' => false, 'dist' => 2, 'len' => 6],
    ];
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], trace_body([0, 0], [101, 9], $events), true);
    check('erstes Stück wird gespeichert', $status === 200 && ($data['stored'] ?? null) === true,
        "Status $status");
    check('Antwort nennt den neuen Stand', ($data['have'] ?? null) === [101, 9]);

    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], trace_body([0, 0], [101, 9], $events), true);
    check('Wiederholung wird erkannt', ($data['stored'] ?? null) === false && ($data['have'] ?? null) === [101, 9]);
    check('Wiederholung schreibt keine Zeilen', count(trace_lines($ctx)) === 2);

    $more = [
        ['at' => 102, 'ms' => 1, 'e' => 'answer', 'hit' => true, 'text' => 'geheim', 'canonical' => 'x',
         'nested' => ['prompt' => 'Haus', 'ok' => 1]],
        ['at' => 103, 'ms' => 2, 'e' => 'boss_explained', 'id' => 's1', 'why' => 'weil'],
        ['at' => 104, 'ms' => 2, 'e' => 'run_start', 'profile' => 'anna'],
    ];
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], trace_body([101, 9], [104, 2], $more), true);
    check('Folgestück wird angehängt', ($data['stored'] ?? null) === true && count(trace_lines($ctx)) === 5);

    $lines = trace_lines($ctx);
    $flat = json_encode($lines);
    check('Freitext, Lemmata, Erklärung und Profil kommen nicht an (zweite Linie)',
        !str_contains($flat, 'geheim') && !str_contains($flat, 'Haus') && !str_contains($flat, 'weil')
        && !str_contains($flat, 'anna'), $flat);
    check('der Rest der Zeile bleibt', ($lines[2]['hit'] ?? null) === true && ($lines[2]['nested']['ok'] ?? 0) === 1);

    // Spielerrechner hat seinen Cursor verloren und fängt vorn an.
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], trace_body([0, 0], [104, 2], $more), true);
    check('zurückgesetzter Cursor bekommt den Stand des Servers',
        ($data['stored'] ?? null) === false && ($data['have'] ?? null) === [104, 2]);

    $cases = [
        ['ohne from', trace_body([0, 0], [1, 1], $events, ['from' => null])],
        ['to vor from', trace_body([200, 0], [150, 0], $events)],
        ['leere Ereignisse', trace_body([200, 0], [201, 0], [])],
        ['Ereignisse als Objekt', trace_body([200, 0], [201, 0], ['a' => ['e' => 'x']])],
        ['Zeile ohne e', trace_body([200, 0], [201, 0], [['at' => 1]])],
        ['Marke mit Kommazahl', trace_body([200.5, 0], [201, 0], $events)],
    ];
    foreach ($cases as [$name, $body]) {
        [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], $body, true);
        check("$name: bad_payload", $status === 400 && ($data['error'] ?? '') === 'bad_payload',
            "Status $status, Grund '" . ($data['error'] ?? '') . "'");
    }
    check('abgewiesene Stücke schreiben nichts', count(trace_lines($ctx)) === 5);
});

scenario('Spur-Kontingent', ['MS_STATS_TRACE_BYTES' => 200], function (array $ctx): void {
    $events = [];
    for ($i = 0; $i < 40; $i++) {
        $events[] = ['at' => 100 + $i, 'ms' => $i, 'e' => 'answer', 'rt' => random_int(100, 9999)];
    }
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], trace_body([0, 0], [139, 39], $events), true);
    check('Monatsgrenze erreicht: quota', $status === 507 && ($data['error'] ?? '') === 'quota',
        "Status $status");
    check('Cursor bleibt stehen', !is_file($ctx['stats'] . '/' . ID . '/trace-cursor.json'));
});

scenario('Grenzen je Id, je IP und Zahl der Profile',
    ['MS_STATS_RATE_ID' => 3, 'MS_STATS_RATE_IP' => 6, 'MS_STATS_IDS' => 2],
    function (array $ctx): void {
        for ($i = 1; $i <= 3; $i++) {
            [$status] = request($ctx['url'], 'POST', $ctx['token'], snapshot_body(), true);
            check("Sendung $i von 3 geht durch", $status === 200, "Status $status");
        }
        [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], snapshot_body(), true);
        check('vierte Sendung derselben Id: rate_limited',
            $status === 429 && ($data['error'] ?? '') === 'rate_limited', "Status $status");

        [$status] = request($ctx['url'], 'POST', $ctx['token'], snapshot_body(['stats_id' => OTHER_ID]), true);
        check('zweites Profil geht durch', $status === 200, "Status $status");
        [$status, $data] = request($ctx['url'], 'POST', $ctx['token'],
            snapshot_body(['stats_id' => str_repeat('a', 32)]), true);
        check('drittes Profil über der Grenze: quota',
            $status === 507 && ($data['error'] ?? '') === 'quota', "Status $status");
        check('kein Verzeichnis für das abgewiesene Profil', !is_dir($ctx['stats'] . '/' . str_repeat('a', 32)));

        // Auch abgewiesene Sendungen zählen: wer gegen die Grenze hämmert, hämmert weiter.
        [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], snapshot_body(['stats_id' => OTHER_ID]), true);
        check('siebte Sendung derselben IP: rate_limited',
            $status === 429 && ($data['error'] ?? '') === 'rate_limited', "Status $status");

        $rate_files = glob($ctx['stats'] . '/_rate/*') ?: [];
        $names = implode(' ', array_map('basename', $rate_files));
        check('Zähler speichern keine IP', !str_contains($names, '127.0.0.1'), $names);
    });

scenario('Alte Zähler werden weggeräumt', [], function (array $ctx): void {
    @mkdir($ctx['stats'] . '/_rate', 0700, true);
    $old = $ctx['stats'] . '/_rate/2020-01-01-id-' . ID;
    file_put_contents($old, '...');
    request($ctx['url'], 'POST', $ctx['token'], snapshot_body(), true);
    check('Zähler von gestern ist weg', !is_file($old));
});

scenario('HTTPS-Zwang', ['MS_REQUIRE_HTTPS' => true], function (array $ctx): void {
    [$status, $data] = request($ctx['url'], 'POST', $ctx['token'], snapshot_body(), true);
    check('ohne TLS wird abgewiesen', $status === 400 && ($data['error'] ?? '') === 'bad_request',
        "Status $status");
});

scenario('Ablage liegt außerhalb des Docroots', [], function (array $ctx): void {
    request($ctx['url'], 'POST', $ctx['token'], snapshot_body(), true);
    check('Snapshot ist angekommen', count(snapshot_files($ctx)) === 1);
    $file = basename(snapshot_files($ctx)[0] ?? 'x');
    foreach (["/ms-stats/" . ID . "/$file", '/statistik/../../ms-stats/' . ID . "/$file"] as $path) {
        [$status] = request($ctx['base'] . $path, 'GET', null);
        check("nicht abrufbar: $path", $status !== 200, "Status $status");
    }
});

printf("\n=== %d Prüfungen, %d Abweichungen\n", $GLOBALS['ms_checks'], $GLOBALS['ms_failed']);
exit($GLOBALS['ms_failed'] === 0 ? 0 : 1);
