<?php
declare(strict_types=1);
/**
 * Melde-Token: Format und Pruefung. Siehe docs/adr/0002-melde-rueckkanal.md.
 *
 *   label = kurzer Name des Melders, [a-z0-9-]
 *   mac   = Crockford-Base32( HMAC-SHA256(secret, "<key_version>:<label>")[:10] )
 *   Token = "<label>.<mac>"
 *
 * Zweitimplementierung desselben Formats ist tools/report/mint_token.py (der Praeger).
 * Eine Aenderung hier ist eine Aenderung an beiden Stellen; die Vektoren in
 * verify_token.php und mint_token.py halten beide Seiten aneinander.
 */

const MS_ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const MS_MAC_BYTES = 10;   // 80 Bit -> genau 16 Zeichen, ohne Rest
const MS_MAC_CHARS = 16;

/** Crockford-Base32, MSB zuerst. Nur fuer Laengen, die auf 5 Bit aufgehen. */
function ms_b32(string $raw): string
{
    $out = '';
    $value = 0;
    $bits = 0;
    $len = strlen($raw);
    for ($i = 0; $i < $len; $i++) {
        $value = ($value << 8) | ord($raw[$i]);
        $bits += 8;
        while ($bits >= 5) {
            $bits -= 5;
            $out .= MS_ALPHABET[($value >> $bits) & 31];
            $value &= (1 << $bits) - 1;
        }
    }
    if ($bits !== 0) {
        throw new RuntimeException('Laenge geht nicht auf 5 Bit auf');
    }
    return $out;
}

/**
 * Der MAC-Teil, den ein Token fuer dieses Label unter diesem Schluessel haben muss.
 * `$secret_hex` sind 64 Hex-Zeichen; gehasht wird ueber die *rohen* 32 Byte.
 */
function ms_mac(string $secret_hex, int $key_version, string $label): string
{
    $secret = hex2bin($secret_hex);
    if ($secret === false || strlen($secret) !== 32) {
        throw new RuntimeException('Geheimnis muss 64 Hex-Zeichen sein');
    }
    $digest = hash_hmac('sha256', $key_version . ':' . $label, $secret, true);
    return ms_b32(substr($digest, 0, MS_MAC_BYTES));
}

/** Vollstaendiges Token fuer ein Label — dieselbe Ausgabe wie mint_token.py. */
function ms_token(string $secret_hex, int $key_version, string $label): string
{
    return $label . '.' . ms_mac($secret_hex, $key_version, $label);
}

/**
 * Bringt ein abgetipptes Token auf die kanonische Form oder gibt null zurueck, wenn
 * schon die Gestalt nicht passt (falsche Laenge, fremde Zeichen, kaputtes Label).
 *
 * Toleriert, was beim Abtippen passiert: Leerzeichen, Bindestriche, Kleinschreibung
 * im MAC-Teil und die Crockford-Verwechslungen O->0, I/L->1.
 */
function ms_normalize_token(string $raw): ?string
{
    $raw = trim($raw);
    $dot = strpos($raw, '.');
    if ($dot === false) {
        return null;
    }
    $label = strtolower(substr($raw, 0, $dot));
    $mac = strtoupper(substr($raw, $dot + 1));
    $mac = str_replace(['-', ' ', "\t"], '', $mac);
    $mac = strtr($mac, ['O' => '0', 'I' => '1', 'L' => '1']);
    if (!preg_match('/^[a-z0-9][a-z0-9-]{0,23}$/', $label)) {
        return null;
    }
    if (strlen($mac) !== MS_MAC_CHARS || strspn($mac, MS_ALPHABET) !== MS_MAC_CHARS) {
        return null;
    }
    return $label . '.' . $mac;
}

/** Label aus einem kanonischen Token. */
function ms_label_of(string $token): string
{
    return substr($token, 0, (int) strpos($token, '.'));
}

/**
 * Prueft ein Token gegen das Geheimnis. Vergleich zeitunabhaengig (hash_equals),
 * damit die Antwortzeit nicht verraet, wie weit ein geratener MAC gestimmt hat.
 */
function ms_token_valid(string $secret_hex, int $key_version, string $token): bool
{
    $label = ms_label_of($token);
    $want = ms_token($secret_hex, $key_version, $label);
    return hash_equals($want, $token);
}
