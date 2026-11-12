/// Security type of a network parsed from `ScanResult.capabilities`,
/// for example `[WPA2-PSK-CCMP][RSN-PSK-SAE-CCMP][ESS]`.
enum Security {
  open('Open', weak: true),
  owe('Enhanced Open (OWE)'),
  wep('WEP', weak: true),
  wpa('WPA', weak: true),
  wpa2('WPA2'),
  wpa2wpa3('WPA2/WPA3'),
  wpa3('WPA3'),
  wpa2Enterprise('WPA2-Enterprise'),
  wpa3Enterprise('WPA3-Enterprise');

  const Security(this.label, {this.weak = false});

  final String label;

  /// Open or broken by known attacks: worth a warning.
  final bool weak;
}

Security parseSecurity(String capabilities) {
  final c = capabilities.toUpperCase();
  final hasEap = c.contains('EAP');
  final hasSae = c.contains('SAE');
  final hasPsk = c.contains('PSK');
  if (hasEap) {
    return (c.contains('SUITE_B') || c.contains('EAP_SUITE')) ? Security.wpa3Enterprise : Security.wpa2Enterprise;
  }
  if (hasSae && hasPsk) return Security.wpa2wpa3;
  if (hasSae) return Security.wpa3;
  if (c.contains('OWE')) return Security.owe;
  if (hasPsk) {
    return (c.contains('WPA2') || c.contains('RSN')) ? Security.wpa2 : Security.wpa;
  }
  if (c.contains('WEP')) return Security.wep;
  if (c.contains('WPA2') || c.contains('RSN')) return Security.wpa2;
  if (c.contains('WPA')) return Security.wpa;
  return Security.open;
}
