class_name ReleaseKey
extends RefCounted
## Öffentlicher RSA-Schlüssel, gegen den Programm-Downloads geprüft werden (`signature` in
## latest.json; privater Teil nur im Secret `RELEASE_SIGNING_KEY`). Als Konstante, damit er
## sicher in der EXE landet. Ein Schlüsselwechsel braucht eine Übergangsfassung, die beide
## Schlüssel kennt: alte Installationen prüfen nur gegen den alten.
const PEM := """-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAjgiOiubtFMoOWRevQsBD
aQEJncMuYrsfUimaRvMlhkts5nqyy+NErsSxJiime+Ev+Zz06JnrgKrGYk5IPBB3
3dnrb1d4/lS72m/vUW1DQiMZUaegpjDs/OoA+xx2ICe6I/BsEKWJ9JMSJHfK/I/B
c5bIM8IL0TZcc65qoUZizMz7IO6PYblsJltAZsVAyCNeCdNEUeH8XdIIGR4QXLjl
jkhvI3rwHFXBQ7sd2imyxx5kZc6ecz9pspfjc/Zm6uFAXJktxbLmmYi3rNhKWA6L
OFwxh6ZYyoXdw+1KfwUbLvzhBxZUReNaovy9HWIKrS1Zjvj7Ott6DSuEplKB6dvE
pJqWDJCkYUII3n9BsIja35zSgFZVuOwdAhrzYFpAIy0dqfu3sCo91V15p+7JWkiX
ZrWe3JlJsDHjprV6KgS4UjWAtCuzKhPUkT8NWANwKET085mEAQ14jmpFCnpIyw1h
UAMA8uRk6iJ/dVUI+i03aE1Fz1AcKS539EhXOgu+wyL/AgMBAAE=
-----END PUBLIC KEY-----"""


## Der Schlüssel als CryptoKey, oder null wenn unlesbar (dann wird nichts installiert).
static func load_public() -> CryptoKey:
	var key := CryptoKey.new()
	if key.load_from_string(PEM, true) != OK:
		push_error("ReleaseKey: öffentlicher Schlüssel unlesbar — Update-Prüfung unmöglich.")
		return null
	return key
