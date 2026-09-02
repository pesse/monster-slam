<?php
declare(strict_types=1);
/**
 * Kommandozeilen-Gegenprobe fuer das Token-Format. NICHT ueber das Web erreichbar machen.
 *
 * Das Format hat zwei Implementierungen — tools/report/mint_token.py praegt, token.php
 * prueft. Dieses Skript haelt beide aneinander: `--self-test` rechnet dieselben Vektoren
 * nach, die `mint_token.py --self-test` prueft. Stimmen beide, stimmt das Format.
 *
 *   php verify_token.php --self-test
 *   php verify_token.php <secret_hex> <key_version> <label>
 */

if (php_sapi_name() !== 'cli') {
    http_response_code(404);
    exit;
}

require __DIR__ . '/token.php';

/** Dieselben Vektoren wie in tools/report/mint_token.py. Das Geheimnis ist ein Testwert. */
const MS_VECTORS = [
    ['0000000000000000000000000000000000000000000000000000000000000000', 1, 'mia',
     'mia.6FRQ4TRQV7AY862H'],
    ['0000000000000000000000000000000000000000000000000000000000000000', 2, 'mia',
     'mia.RTJTYE45FF3327KK'],
    ['0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c4b5a69788796a5b4c3d2e1f0', 1, 'leo',
     'leo.D8E81TJPZRJE9MJ6'],
];

$argv = $_SERVER['argv'];

if (($argv[1] ?? '') === '--self-test') {
    $bad = 0;
    foreach (MS_VECTORS as [$secret, $key_version, $label, $expected]) {
        $got = ms_token($secret, $key_version, $label);
        $ok = hash_equals($expected, $got);
        $bad += $ok ? 0 : 1;
        printf("%s  v%d %-6s %s%s\n", $ok ? 'ok  ' : 'FEHL', $key_version, $label, $got,
            $ok ? '' : '   erwartet: ' . $expected);
    }
    // Was das Format zusagt.
    $mac = ms_mac(MS_VECTORS[0][0], 1, 'mia');
    assert(strlen($mac) === MS_MAC_CHARS);
    assert(strspn($mac, MS_ALPHABET) === MS_MAC_CHARS);
    assert(ms_normalize_token('MIA.6frq-4trq-v7ay-862h') === 'mia.6FRQ4TRQV7AY862H');
    assert(ms_normalize_token('mia.6FRQ4TRQV7AY862') === null);      // zu kurz
    assert(ms_normalize_token('mia 6FRQ4TRQV7AY862H') === null);     // kein Punkt
    printf("--- %d Vektoren, %d Abweichungen\n", count(MS_VECTORS), $bad);
    exit($bad === 0 ? 0 : 1);
}

if (count($argv) < 4) {
    fwrite(STDERR, "Aufruf: php verify_token.php <secret_hex> <key_version> <label>\n"
        . "        php verify_token.php --self-test\n");
    exit(2);
}

echo ms_token($argv[1], (int) $argv[2], $argv[3]), "\n";
